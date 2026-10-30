class_name Tutorial
extends Control
## First-game walkthrough: dims the screen, spotlights one region at a time, explains it.

signal finished

var steps: Array = []   # [{target: Control or null, title, text}]
var _i := 0
var _panel: PanelContainer
var _title: Label
var _text: Label
var _count: Label
var _hole := Rect2()


func setup(s: Array) -> Tutorial:
	steps = s
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UITheme.shadow_box(UITheme.PANEL, UITheme.ACCENT, 10, 18))
	_panel.custom_minimum_size = Vector2(380, 0)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	_count = UITheme.caps("")
	v.add_child(_count)
	_title = UITheme.heading("", 22)
	v.add_child(_title)
	_text = UITheme.wrap(UITheme.label("", 14))
	_text.custom_minimum_size.x = 340
	v.add_child(_text)
	var row := HBoxContainer.new()
	var skip := UITheme.button("Skip tutorial")
	skip.pressed.connect(_finish)
	row.add_child(skip)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var nxt := UITheme.button("Next", "", true)
	nxt.custom_minimum_size.x = 100
	nxt.pressed.connect(_next)
	row.add_child(nxt)
	v.add_child(row)
	resized.connect(_layout)
	_show()


func _show() -> void:
	var st: Dictionary = steps[_i]
	_count.text = "Briefing %d of %d" % [_i + 1, steps.size()]
	_title.text = st["title"]
	_text.text = st["text"]
	_layout()
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.2)


func _layout() -> void:
	if steps.is_empty():
		return
	var target: Control = steps[_i].get("target")
	_hole = Rect2()
	if target and is_instance_valid(target):
		_hole = target.get_global_rect().grow(6)
		_hole.position -= global_position
	_panel.reset_size()
	var ps := _panel.get_combined_minimum_size()
	var pos := size * 0.5 - ps * 0.5
	if _hole.size != Vector2.ZERO:
		# Place the panel beside the spotlight, wherever there is room.
		if _hole.end.x + ps.x + 20 < size.x:
			pos = Vector2(_hole.end.x + 16, clampf(_hole.position.y, 16, size.y - ps.y - 16))
		elif _hole.position.x - ps.x - 20 > 0:
			pos = Vector2(_hole.position.x - ps.x - 16, clampf(_hole.position.y, 16, size.y - ps.y - 16))
		elif _hole.end.y + ps.y + 20 < size.y:
			pos = Vector2(clampf(_hole.position.x, 16, size.x - ps.x - 16), _hole.end.y + 16)
		else:
			pos = Vector2(clampf(_hole.position.x, 16, size.x - ps.x - 16), maxf(16, _hole.position.y - ps.y - 16))
	_panel.position = pos
	queue_redraw()


func _draw() -> void:
	var dim := Color(0, 0, 0, 0.62)
	if _hole.size == Vector2.ZERO:
		draw_rect(Rect2(Vector2.ZERO, size), dim)
		return
	draw_rect(Rect2(0, 0, size.x, _hole.position.y), dim)
	draw_rect(Rect2(0, _hole.end.y, size.x, size.y - _hole.end.y), dim)
	draw_rect(Rect2(0, _hole.position.y, _hole.position.x, _hole.size.y), dim)
	draw_rect(Rect2(_hole.end.x, _hole.position.y, size.x - _hole.end.x, _hole.size.y), dim)
	draw_rect(_hole, UITheme.ACCENT, false, 2.0)


func _next() -> void:
	_i += 1
	if _i >= steps.size():
		_finish()
	else:
		_show()


func _finish() -> void:
	Settings.set_value("tutorial_done", true)
	finished.emit()
