extends Node
## Music (crossfaded loops), sound effects and voiced briefings via the OS text-to-speech engine.

const MUSIC := {
	"theme": "res://assets/audio/music_theme.ogg",
	"situation": "res://assets/audio/music_situation.ogg",
	"tension": "res://assets/audio/music_tension.ogg",
}
const FEMALE := ["Margaret Holloway", "Evelyn Strand", "Ruth Abernathy", "Grace Whitfield", "Hannah Cole",
	"Ingrid Sato", "Lena Kowalski", "Priya Raman", "June Halvorsen"]
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

func voice_available() -> bool:
	return not _voices.is_empty()


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


func speak(person: String, text: String) -> void:
	if not Settings.get_value("voice_enabled") or not voice_available():
		return
	var v := _pick_voice(person)
	if String(v["id"]) == "":
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, v["id"], int(float(Settings.get_value("voice_volume")) * 100.0), float(v["pitch"]), float(Settings.get_value("voice_rate")))


func stop_voice() -> void:
	if voice_available():
		DisplayServer.tts_stop()
