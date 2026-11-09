class_name Tutorial
extends PanelContainer
## The first month, played rather than read: a short checklist that ticks itself off as the new
## President answers a briefing, keeps a diary engagement, acts on a country and ends the month.
## One line of help per step. The longer explanation stays under Menu > How to play.

signal finished

const STEPS := [
	["Answer your first briefing", "Crises and choices arrive as briefing cards. Each option shows what it costs and what it is likely to change."],
	["Keep one diary engagement", "The Desk tab on the right lists this month's diary. Engagements cost time, not political capital. Pick one."],
	["Act on a country", "Click a pinned country on the map (or any country), then pick an option from the ring or from its dossier. Options cost political capital."],
	["End the month", "Press End month (Enter). The month plays out on the map, then the next briefing arrives."],
]

var _rows: Array = []
var _hint: Label
var _start_actions := 0
var _start_turn := 0
var _done := false


func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.shadow_box(Color(0.03, 0.05, 0.09, 0.96), UITheme.ACCENT, 8, 12))
	custom_minimum_size = Vector2(340, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	add_child(v)
	var head := HBoxContainer.new()
	var t := UITheme.caps("Your first month")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var skip := Button.new()
	skip.flat = true
	skip.text = "Skip"
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_size_override("font_size", 11)
	skip.add_theme_color_override("font_color", UITheme.MUTED)
	skip.pressed.connect(_finish)
	head.add_child(skip)
	v.add_child(head)
	for st in STEPS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var box := UITheme.bold("○", 14, UITheme.MUTED)
		box.custom_minimum_size.x = 16
		row.add_child(box)
		var l := UITheme.bold(st[0], 13, UITheme.MUTED)
		row.add_child(l)
		v.add_child(row)
		_rows.append([box, l])
	_hint = UITheme.wrap(UITheme.label("", 12, UITheme.TEXT))
	_hint.custom_minimum_size.x = 316
	v.add_child(_hint)
	if Game.has_game():
		_start_actions = int(Game.state.stats.get("actions", 0))
		_start_turn = Game.state.turn
	Game.state_changed.connect(refresh)
	refresh()


func step() -> int:
	if not Game.has_game():
		return 0
	var s := Game.state
	if s.turn > _start_turn:
		return 4
	if not s.pending.is_empty():
		return 0
	if Diary.slots_used(s) == 0 and Diary.slots_left(s) > 0:
		return 1
	if int(s.stats.get("actions", 0)) <= _start_actions and float(s.us["political_capital"]) >= 5.0:
		return 2
	return 3


func refresh() -> void:
	if _done:
		return
	var cur := step()
	for i in _rows.size():
		var box: Label = _rows[i][0]
		var l: Label = _rows[i][1]
		var state := "done" if i < cur else ("now" if i == cur else "later")
		box.text = "✓" if state == "done" else ("▸" if state == "now" else "○")
		var col: Color = UITheme.GOOD if state == "done" else (UITheme.ACCENT if state == "now" else UITheme.MUTED)
		box.add_theme_color_override("font_color", col)
		l.add_theme_color_override("font_color", UITheme.TEXT if state == "now" else col)
	if cur >= STEPS.size():
		_finish()
	else:
		_hint.text = STEPS[cur][1]


func _finish() -> void:
	if _done:
		return
	_done = true
	Settings.set_value("tutorial_done", true)
	finished.emit()
