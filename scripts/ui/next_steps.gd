class_name NextSteps
extends PanelContainer
## "What now?" Concrete next steps from the cabinet, each one click away from doing it.

var limit := 3
var compact := true
var _list: VBoxContainer
var _head: Button
var _collapsed := false


func setup(max_items: int, is_compact: bool) -> NextSteps:
	limit = max_items
	compact = is_compact
	return self


func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.05, 0.09, 0.9) if compact else UITheme.PANEL_2, Color(UITheme.ACCENT, 0.35), 8, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	add_child(v)
	_head = Button.new()
	_head.flat = true
	_head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_head.focus_mode = Control.FOCUS_NONE
	_head.add_theme_font_override("font", UITheme.font_bold())
	_head.add_theme_font_size_override("font_size", 11)
	_head.add_theme_color_override("font_color", UITheme.ACCENT)
	_head.add_theme_color_override("font_hover_color", UITheme.ACCENT.lightened(0.2))
	_head.pressed.connect(func():
		_collapsed = not _collapsed
		refresh())
	_head.disabled = not compact
	_head.add_theme_color_override("font_disabled_color", UITheme.ACCENT)
	v.add_child(_head)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	v.add_child(_list)
	Game.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _list == null or not Game.has_game():
		return
	UITheme.clear(_list)
	var items := Guidance.suggest(Game.state, Game.map_data, limit)
	_head.text = ("NEXT STEPS  %s" % ("▸" if _collapsed else "▾")) if compact else "NEXT STEPS: WHAT YOUR CABINET SUGGESTS"
	_list.visible = not _collapsed
	if items.is_empty():
		_list.add_child(UITheme.label("Nothing urgent. Pick a country and build on your mandate.", 12, UITheme.MUTED))
		return
	for it in items:
		_list.add_child(_row(it))


func _row(it: Dictionary) -> Control:
	var card := PanelContainer.new()
	var normal := UITheme.box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.06), 6, 6)
	var hover := UITheme.box(Color(UITheme.ACCENT, 0.12), Color(UITheme.ACCENT, 0.6), 6, 6)
	card.add_theme_stylebox_override("panel", normal)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel", hover))
	card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", normal))
	card.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("click")
			Game.guidance_go.emit(it))
	card.tooltip_text = String(it["text"])
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UITheme.icon_rect(String(it["icon"]), 16, UITheme.ACCENT)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UITheme.bold(String(it["title"]), 12 if compact else 13)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.wrap(t)
	v.add_child(t)
	var d := UITheme.label(String(it["text"]), 11, UITheme.MUTED)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.wrap(d)
	if compact:
		d.max_lines_visible = 2
	v.add_child(d)
	h.add_child(v)
	var go := UITheme.label("›", 18, UITheme.ACCENT)
	go.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(go)
	card.add_child(h)
	return card
