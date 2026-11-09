class_name DeskPanel
extends ScrollContainer
## "The Desk": what there is to do this month. The President's diary (dated engagements that cost
## time, not political capital), what needs attention around the world, and operations in progress.

var _box: VBoxContainer


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 7)
	add_child(_box)
	Game.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var keep := scroll_vertical
	UITheme.clear(_box)
	if not Game.has_game():
		return
	var s := Game.state
	_diary(s)
	_extra(s)
	_attention(s)
	_operations(s)
	await get_tree().process_frame
	scroll_vertical = keep


## Live crises: the clock, your hand, and what would strengthen it.
func _extra(s: GameState) -> void:
	var live := Crises.list(s)
	if live.is_empty():
		return
	_box.add_child(HSeparator.new())
	_box.add_child(UITheme.caps("Crises", UITheme.BAD))
	for c in live:
		_box.add_child(crisis_card(s, c, true))


static func crisis_card(s: GameState, c: Dictionary, detail: bool) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.BAD, 0.09), Color(UITheme.BAD, 0.6), 8, 8))
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("click")
			Game.show_country(String(c["iso"])))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var t := UITheme.bold(String(c["title"]), 13)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 4)
	steps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(0, 5)
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.add_theme_stylebox_override("panel", UITheme.box(UITheme.BAD if i < Crises.stage(c) else UITheme.LINE, Color(0, 0, 0, 0), 3, 0))
		steps.add_child(pip)
	v.add_child(steps)
	var left := Crises.months_left(c)
	var hw := Crises.hand_word(c)
	var hc: Color = UITheme.BAD if hw == "weak" else (UITheme.WARN if hw == "even" else UITheme.GOOD)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UITheme.label("Stage %d of 3 · %d month%s left" % [Crises.stage(c), left, "" if left == 1 else "s"], 11, UITheme.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	row.add_child(UITheme.bold("Your hand: %s (%d%%)" % [hw, int(c["hand"])], 11, hc))
	v.add_child(row)
	if detail:
		var h := UITheme.wrap(UITheme.label(Crises.helps_text(s, c), 11, UITheme.MUTED))
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(h)
	return p


func _diary(s: GameState) -> void:
	var head := HBoxContainer.new()
	head.add_child(UITheme.caps("The diary · %s" % s.date_string()))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var left := Diary.slots_left(s)
	head.add_child(UITheme.label("Time left", 11, UITheme.MUTED))
	for i in Diary.SLOTS:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(13, 13)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.add_theme_stylebox_override("panel", UITheme.box(UITheme.ACCENT if i < left else Color(0, 0, 0, 0), UITheme.ACCENT if i < left else UITheme.LINE, 3, 0))
		head.add_child(pip)
	_box.add_child(head)
	var items := Diary.items(s)
	if items.is_empty():
		_box.add_child(UITheme.label("Nothing in the diary.", 12, UITheme.MUTED))
	for i in items.size():
		_box.add_child(_diary_row(s, i, items[i]))
	if left == 0:
		_box.add_child(UITheme.wrap(UITheme.label("Your month is full. Act on a country, or end the month.", 11, UITheme.MUTED)))
	else:
		_box.add_child(UITheme.wrap(UITheme.label("Engagements cost time, not political capital. Time you leave unused becomes a little political capital.", 11, UITheme.MUTED)))


func _diary_row(s: GameState, index: int, it: Dictionary) -> Control:
	var done: bool = it.get("done", false)
	var check := Diary.available(s, index)
	var ok: bool = check["ok"]
	var card := PanelContainer.new()
	var border := Color(UITheme.GOOD, 0.5) if done else (UITheme.LINE if ok else Color(1, 1, 1, 0.05))
	card.add_theme_stylebox_override("panel", UITheme.box(UITheme.PANEL_2 if (ok or done) else Color(0.06, 0.08, 0.12), border, 7, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	var dv := VBoxContainer.new()
	dv.custom_minimum_size.x = 34
	dv.add_theme_constant_override("separation", -4)
	var dn := UITheme.heading(str(int(it["day"])), 20, UITheme.TEXT if (ok or done) else UITheme.MUTED)
	dn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(dn)
	var wd := UITheme.caps(String(it.get("wd", "")), UITheme.MUTED, 9)
	wd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(wd)
	h.add_child(dv)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	var title := UITheme.wrap(UITheme.bold(String(it["title"]), 13, UITheme.GOOD if done else (UITheme.TEXT if ok else UITheme.MUTED)))
	v.add_child(title)
	var sub := String(it["result"]) if done else String(it["text"])
	v.add_child(UITheme.wrap(UITheme.label(sub, 11, UITheme.MUTED)))
	h.add_child(v)
	if done:
		var tick := UITheme.chip("Done", UITheme.GOOD)
		tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(tick)
	else:
		var b := UITheme.button("%s%s" % [_verb(String(it["kind"])), "  ●●" if int(it["slots"]) == 2 else ""], "", ok)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = not ok
		b.tooltip_text = String(check["reason"]) if not ok else ("Takes %d of your time slots." % int(it["slots"]) if int(it["slots"]) > 1 else "Takes one time slot.")
		b.pressed.connect(func():
			Audio.sfx("click")
			_attend(index, it))
		h.add_child(b)
	if String(it["iso"]) != "":
		var show := Button.new()
		show.flat = true
		show.icon = UITheme.icon("standing")
		show.add_theme_constant_override("icon_max_width", 14)
		show.tooltip_text = "Show %s on the map" % String(s.c(it["iso"]).get("name", ""))
		show.focus_mode = Control.FOCUS_NONE
		show.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		show.pressed.connect(Game.show_country.bind(String(it["iso"])))
		h.add_child(show)
	return card


func _attend(index: int, _it: Dictionary) -> void:
	Game.attend(index)


static func _verb(kind: String) -> String:
	return {"call": "Call", "dinner": "Host", "intel": "Attend", "hill": "Go", "townhall": "Go", "press": "Hold",
		"troops": "Visit", "advisor": "Meet", "review": "Review", "purse": "Go", "un": "Speak", "rest": "Rest",
		"crisis": "Work it", "hotline": "Pick up"}.get(kind, "Attend")


func _attention(s: GameState) -> void:
	var items := Guidance.suggest(s, Game.map_data, 5)
	_box.add_child(HSeparator.new())
	_box.add_child(UITheme.caps("Needs your attention"))
	if items.is_empty():
		_box.add_child(UITheme.label("Nothing pressing. Build on your mandate.", 12, UITheme.MUTED))
	for it in items:
		_box.add_child(NextSteps.row(it, false))


func _operations(s: GameState) -> void:
	var ops: Array = s.us.get("ops", [])
	var troops: Dictionary = s.us["troops"]
	if ops.is_empty() and troops.is_empty():
		return
	_box.add_child(HSeparator.new())
	_box.add_child(UITheme.caps("Your operations (%d) and deployments (%d)" % [ops.size(), troops.size()]))
	for op in ops:
		var b := UITheme.button("%s · %s · month %d" % [Actions.OP_NAMES[op["type"]], s.c(op["iso"]).get("name", op["iso"]), int(op["months"])], CountryPanel.OP_ICONS.get(op["type"], "score"))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(Game.show_country.bind(String(op["iso"])))
		_box.add_child(b)
	for iso in troops:
		var b := UITheme.button("US troops · %s" % s.c(iso).get("name", iso), "military")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(Game.show_country.bind(String(iso)))
		_box.add_child(b)
