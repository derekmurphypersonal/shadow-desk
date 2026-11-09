extends Node
## Music (crossfaded loops), sound effects and voiced briefings.
## Briefings play pre-recorded neural voices (assets/voice/<seat>/<md5>.voice, Ogg Vorbis, built by
## tools/build_voices.py), stitched around country names. Lines without a recording fall back
## to the OS text-to-speech engine.

signal voice_started
signal voice_finished

const VOICE_DIR := "res://assets/voice/%s/%s.voice"
const NAME_GAP := 0.05
const TITLE_GAP := 0.45

const MUSIC := {
	"theme": "res://assets/audio/music_theme.ogg",
	"situation": "res://assets/audio/music_situation.ogg",
	"tension": "res://assets/audio/music_tension.ogg",
}
const FEMALE := Advisors.FEMALE
## Preferred OS voices, best first. macOS, Windows and common Linux voices.
const FEMALE_VOICES := ["Samantha", "Karen", "Moira", "Tessa", "Serena", "Ava", "Allison", "Susan", "Victoria", "Zira", "Hazel", "Fiona", "female"]
const MALE_VOICES := ["Daniel", "Alex", "Tom", "Oliver", "Rishi", "Aaron", "Fred", "Evan", "Nathan", "David", "Mark", "George", "male"]

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current := ""
var _sfx_pool: Array = []
var _sfx_cache: Dictionary = {}
var _voices: Array = []
var _voice_for: Dictionary = {}
var _vplayer: AudioStreamPlayer
var _vqueue: Array = []
var _vtoken := 0
var _vspeaking := false
var _tts_speaking := false
var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _shift: AudioEffectPitchShift
var _voice_bus := 0
var _token_re := RegEx.create_from_string("\\$[A-Z]+")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	add_child(_music_a)
	add_child(_music_b)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "Voice")
	AudioServer.set_bus_send(bus, "Master")
	var comp := AudioEffectCompressor.new()
	comp.threshold = -16.0
	comp.ratio = 3.0
	AudioServer.add_bus_effect(bus, comp)
	AudioServer.add_bus_effect(bus, AudioEffectSpectrumAnalyzer.new())
	_spectrum = AudioServer.get_bus_effect_instance(bus, 1)
	_shift = AudioEffectPitchShift.new()
	AudioServer.add_bus_effect(bus, _shift)
	_voice_bus = bus
	_vplayer = AudioStreamPlayer.new()
	_vplayer.bus = "Voice"
	_vplayer.finished.connect(_play_next)
	add_child(_vplayer)
	if DisplayServer.get_name() != "headless" and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		_voices = DisplayServer.tts_get_voices()
	Settings.changed.connect(_apply_volume)


static func _db(linear: float) -> float:
	return linear_to_db(maxf(linear, 0.0001))


func _apply_volume() -> void:
	var v := float(Settings.get_value("music_volume"))
	for p in [_music_a, _music_b]:
		if p.playing and p.has_meta("full"):
			p.volume_db = _db(v)


func music(name: String, fade: float = 1.5) -> void:
	if name == _current or not MUSIC.has(name):
		return
	_current = name
	var stream: AudioStream = load(MUSIC[name])
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var incoming := _music_b if _music_a.playing else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.set_meta("full", true)
	outgoing.remove_meta("full")
	incoming.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(incoming, "volume_db", _db(float(Settings.get_value("music_volume"))), fade)
	if outgoing.playing:
		tw.tween_property(outgoing, "volume_db", -60.0, fade)
		tw.chain().tween_callback(outgoing.stop)


func stop_music(fade: float = 1.0) -> void:
	_current = ""
	for p in [_music_a, _music_b]:
		if p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -60.0, fade)
			tw.tween_callback(p.stop)


func sfx(name: String, gain_db: float = 0.0) -> void:
	var path := "res://assets/audio/sfx_%s.ogg" % name
	if name.begins_with("sting_"):
		path = "res://assets/audio/%s.ogg" % name
	if not _sfx_cache.has(path):
		_sfx_cache[path] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _sfx_cache[path]
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = _db(float(Settings.get_value("sfx_volume"))) + gain_db
			p.play()
			return


# ---- Voiced briefings ----

func _pick_voice(person: String) -> Dictionary:
	if _voice_for.has(person):
		return _voice_for[person]
	var english: Array = []
	for v in _voices:
		if String(v.get("language", "")).begins_with("en"):
			english.append(v)
	if english.is_empty():
		english = _voices
	var prefs: Array = FEMALE_VOICES if person in FEMALE else MALE_VOICES
	var chosen: Dictionary = {}
	var used: Array = []
	for other in _voice_for.values():
		used.append(other.get("id", ""))
	for pref in prefs:
		for v in english:
			if String(v["name"]).to_lower().contains(String(pref).to_lower()) and not used.has(v["id"]):
				chosen = v
				break
		if not chosen.is_empty():
			break
	if chosen.is_empty() and not english.is_empty():
		chosen = english[hash(person) % english.size()]
	# Vary pitch so advisors sharing an OS voice still sound different.
	var pitch := 1.0 + (float(absi(hash(person)) % 21) - 10.0) / 100.0
	var result := {"id": chosen.get("id", ""), "pitch": pitch}
	_voice_for[person] = result
	return result


func voice_available() -> bool:
	return _recorded_available() or not _voices.is_empty()


func _recorded_available() -> bool:
	return FileAccess.file_exists("res://assets/voice/index.json")


## Speak a briefing card with the voice of the seat briefing it (chief, state, ...).
func speak_card(card: Dictionary, seat: String, person: String) -> void:
	stop_voice()
	if not Settings.get_value("voice_enabled"):
		return
	var clips := _clips_for(card, seat)
	if clips.is_empty():
		_tts(person, "%s. %s" % [card.get("title", ""), card.get("text", "")])
		return
	_vqueue = clips
	_vspeaking = true
	voice_started.emit()
	_play_next()


func _clips_for(card: Dictionary, seat: String) -> Array:
	var voice: Dictionary = card.get("voice", {})
	var parts := [String(voice.get("title", card.get("title", ""))), String(voice.get("text", card.get("text", "")))]
	var vars: Dictionary = voice.get("vars", {})
	var out: Array = []
	for p in parts.size():
		var tpl: String = parts[p]
		var pos := 0
		var pieces: Array = []
		for m in _token_re.search_all(tpl):
			pieces.append(tpl.substr(pos, m.get_start() - pos))
			pieces.append(String(vars.get(m.get_string(), "")))
			pos = m.get_end()
		pieces.append(tpl.substr(pos))
		for piece in pieces:
			var t := normalize(piece)
			if t == "":
				continue
			var st := _clip(seat, t)
			if st == null:
				return []
			if not out.is_empty() and not (out[-1] is float):
				out.append(NAME_GAP)
			out.append(st)
		if p == 0:
			out.append(TITLE_GAP)
	return out


## Must match normalize() in tools/build_voices.py.
static func normalize(text: String) -> String:
	var t := text.strip_edges()
	while t != "" and ",;:".contains(t[0]):
		t = t.substr(1).strip_edges()
	var has_letter := false
	for ch in t:
		if ch.to_lower() != ch.to_upper():
			has_letter = true
			break
	return t if has_letter else ""


func _clip(seat: String, text: String) -> AudioStream:
	var path := VOICE_DIR % [seat, text.md5_text().left(16)]
	if not FileAccess.file_exists(path):
		return null
	return AudioStreamOggVorbis.load_from_file(path)


func _play_next() -> void:
	if _vqueue.is_empty():
		if _vspeaking:
			_vspeaking = false
			voice_finished.emit()
		return
	var item = _vqueue.pop_front()
	if item is float:
		var token := _vtoken
		get_tree().create_timer(float(item)).timeout.connect(func():
			if token == _vtoken:
				_play_next())
		return
	_vplayer.stream = item
	_vplayer.volume_db = _db(float(Settings.get_value("voice_volume")))
	# Voice speed: play faster/slower and shift the pitch back so the advisor still sounds like themselves.
	var rate := clampf(float(Settings.get_value("voice_rate")), 0.6, 1.6)
	_vplayer.pitch_scale = rate
	_shift.pitch_scale = 1.0 / rate
	AudioServer.set_bus_effect_enabled(_voice_bus, 2, absf(rate - 1.0) > 0.02)
	_vplayer.play()


func is_speaking() -> bool:
	if _tts_speaking and voice_available() and not _voices.is_empty():
		_tts_speaking = DisplayServer.tts_is_speaking()
	return _vspeaking or _tts_speaking


## 0..1 loudness of the voice right now, for waveforms and lip-sync glow.
func voice_level() -> float:
	if _vspeaking and _spectrum:
		var m := _spectrum.get_magnitude_for_frequency_range(90.0, 3500.0)
		return clampf((linear_to_db(maxf((m.x + m.y) * 0.5, 0.00001)) + 62.0) / 52.0, 0.0, 1.0)
	if is_speaking():
		return 0.35 + 0.35 * absf(sin(Time.get_ticks_msec() * 0.013)) * absf(sin(Time.get_ticks_msec() * 0.0071))
	return 0.0


func speak(person: String, text: String) -> void:
	_tts(person, text)


func _tts(person: String, text: String) -> void:
	if not Settings.get_value("voice_enabled") or not voice_available():
		return
	var v := _pick_voice(person)
	if String(v["id"]) == "":
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, v["id"], int(float(Settings.get_value("voice_volume")) * 100.0), float(v["pitch"]), float(Settings.get_value("voice_rate")))
	_tts_speaking = true


func stop_voice() -> void:
	_vtoken += 1
	_vqueue.clear()
	if _vplayer and _vplayer.playing:
		_vplayer.stop()
	if _vspeaking:
		_vspeaking = false
		voice_finished.emit()
	if not _voices.is_empty():
		DisplayServer.tts_stop()
	_tts_speaking = false
