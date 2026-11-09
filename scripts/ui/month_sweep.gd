class_name MonthSweep
extends Control
## "The month plays out": a few seconds in which the date counts through the month and the things
## that happened appear on a timeline on their days. Click or press a key to skip.
## entries: [{day, text, tone, iso, kind}] sorted by day.

signal entry_shown(entry: Dictionary)
signal finished

const DAYS := 30.0

var entries: Array = []
var month_name := ""
var year := 0
var right_inset := 440.0
var _t := 0.0
var _dur := 3.0
var _next := 0
var _strip: PanelContainer
var _track: Control
var _date: Label
var _ending := false


func setup(items: Array, month: String, yr: int) -> MonthSweep:
	entries = items
	month_name = month
	year = yr
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if entries.is_empty():
		entries = [{"day": 15, "text": "A quiet month", "tone": "neutral", "iso": "", "kind": "info"}]
	_dur = clampf(1.4 + 0.45 * float(entries.size()), 2.2, 5.5)
	_strip = PanelContainer.new()
	_strip.add_theme_stylebox_override("panel", UITheme.shadow_box(Color(0.03, 0.045, 0.08, 0.95), Color(UITheme.ACCENT, 0.5), 8, 12))
	add_child(_strip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_strip.add_child(v)
	var head := HBoxContainer.new()
	_date = UITheme.heading("", 22, UITheme.ACCENT)
	_date.custom_minimum_size.x = 170
	head.add_child(_date)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UITheme.label("The month plays out · click to skip", 11, UITheme.MUTED))
	v.add_child(head)
	_track = Control.new()
	_track.custom_minimum_size = Vector2(0, 96)
	_track.draw.connect(_draw_track)
	v.add_child(_track)
	resized.connect(_layout)
	_layout()
	Audio.sfx("teletype", -10.0)


func _layout() -> void:
	var w := maxf(480.0, size.x - right_inset - 28.0)
	_strip.custom_minimum_size = Vector2(w, 0)
	_strip.reset_size()
	_strip.position = Vector2(14, size.y - _strip.size.y - 42.0)


func _x(day: float) -> float:
	return 8.0 + (_track.size.x - 16.0) * clampf((day - 1.0) / (DAYS - 1.0), 0.0, 1.0)


func _process(delta: float) -> void:
	if _ending:
		return
	_t += delta
	var day := 1.0 + (DAYS - 1.0) * clampf(_t / _dur, 0.0, 1.0)
	_date.text = "%d %s %d" % [int(day), month_name.to_upper(), year]
	while _next < entries.size() and float(entries[_next]["day"]) <= day:
		_reveal(_next)
		_next += 1
	_track.queue_redraw()
	if _t >= _dur:
		_finish(0.7)


func _reveal(i: int) -> void:
	var e: Dictionary = entries[i]
	var col: Color = UITheme.tone(String(e.get("tone", "neutral")))
	if String(e.get("tone", "")) == "neutral":
		col = UITheme.TEXT
	var chip := UITheme.chip(String(e["text"]), col, 11)
	chip.add_theme_stylebox_override("normal", UITheme.box(Color(0.05, 0.07, 0.12, 0.98), Color(col, 0.6), 6, 4))
	_track.add_child(chip)
	chip.reset_size()
	var x := clampf(_x(float(e["day"])) - chip.size.x * 0.5, 0.0, maxf(0.0, _track.size.x - chip.size.x))
	chip.position = Vector2(x, 2.0 + 25.0 * float(i % 3))
	chip.modulate.a = 0.0
	chip.create_tween().tween_property(chip, "modulate:a", 1.0, 0.18)
	e["_x"] = _x(float(e["day"]))
	e["_y"] = chip.position.y + chip.size.y
	e["_col"] = col
	entry_shown.emit(e)


func _draw_track() -> void:
	var base := _track.size.y - 14.0
	_track.draw_line(Vector2(8, base), Vector2(_track.size.x - 8, base), UITheme.LINE, 2.0)
	var font := UITheme.font_body()
	for d in [1, 8, 15, 22, 30]:
		var x := _x(float(d))
		_track.draw_line(Vector2(x, base - 4), Vector2(x, base + 4), UITheme.LINE, 1.0)
		_track.draw_string(font, Vector2(x - 6, base + 14), str(d), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.MUTED)
	for i in mini(_next, entries.size()):
		var e: Dictionary = entries[i]
		if e.has("_x"):
			_track.draw_line(Vector2(e["_x"], e["_y"]), Vector2(e["_x"], base), Color(e["_col"], 0.55), 1.2)
			_track.draw_circle(Vector2(e["_x"], base), 3.0, e["_col"])
	var nx := _x(1.0 + (DAYS - 1.0) * clampf(_t / _dur, 0.0, 1.0))
	_track.draw_line(Vector2(nx, 0), Vector2(nx, base + 4), UITheme.ACCENT, 2.0)


func _finish(hold: float) -> void:
	if _ending:
		return
	_ending = true
	while _next < entries.size():
		_reveal(_next)
		_next += 1
	_date.text = "%d %s %d" % [int(DAYS), month_name.to_upper(), year]
	_track.queue_redraw()
	var tw := create_tween()
	tw.tween_interval(hold)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func(): finished.emit())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_finish(0.35)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		_finish(0.35)
