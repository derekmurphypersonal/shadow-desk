extends Node
## Player preferences, persisted to user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"music_volume": 0.6, "sfx_volume": 0.8, "voice_enabled": true, "voice_volume": 0.9, "voice_rate": 1.0,
	"fullscreen": false, "ui_scale": 1.0, "colorblind": false, "show_digest": true, "typewriter": true,
	"tutorial_done": false, "edge_pan": false, "cabinet_minor": true, "digest_big_only": true, "fx": true,
}

var values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in DEFAULTS:
			values[k] = cfg.get_value("settings", k, DEFAULTS[k])
	apply()


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	values[key] = value
	save()
	apply()
	changed.emit()


func save() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("settings", k, values[k])
	cfg.save(PATH)


func apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want_full: bool = values["fullscreen"]
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if want_full != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_full else DisplayServer.WINDOW_MODE_WINDOWED)
	get_tree().root.content_scale_factor = float(values["ui_scale"])
