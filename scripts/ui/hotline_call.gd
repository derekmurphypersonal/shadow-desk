class_name HotlineCall
extends CenterContainer
## A hotline call with a foreign leader: a crackling line, a translator's transcript, and two
## exchanges in which what you say moves their mood. The rules live in Hotline (scripts/sim).
## The leader is an office and a temperament; never a name, a face or a voice.

signal closed(result: String)

var iso := ""
var call: Dictionary
var _before: Dictionary
var _result := ""
var _log: VBoxContainer
var _opts: VBoxContainer
var _mood: ProgressBar
var _mood_word: Label
var _scroll: ScrollContainer
var _t := 0.0
var _static: Control


func setup(country: String) -> HotlineCall:
	iso = country
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s := Game.state
	_before = Report.snapshot(s, iso)
	call = Hotline.begin(s, iso)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	panel.add_theme_stylebox_override("panel", UITheme.shadow_box(Color(0.045, 0.06, 0.09), Color(UITheme.BAD, 0.55), 10, 22))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_static = Control.new()
	_static.custom_minimum_size = Vector2(64, 64)
	_static.draw.connect(_draw_static)
	head.add_child(_static)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 2)
	hv.add_child(UITheme.caps("Hotline · secure line · interpreter present", UITheme.BAD, 10))
	hv.add_child(UITheme.heading("The leader of %s" % call["name"], 28))
	var chips: Array = []
	for t in call["temper"]:
		chips.append({"text": String(t).capitalize(), "tone": "warn"})
	var d := s.c(iso)
	chips.append({"text": "Relations %+d" % int(d["relation"]), "tone": "good" if float(d["relation"]) >= 0.0 else "bad"})
	hv.add_child(UITheme.chip_row(chips, false, 11))
	head.add_child(hv)
	v.add_child(head)

	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 8)
	mrow.add_child(UITheme.label("Their mood", 12, UITheme.MUTED))
	_mood = UITheme.bar(float(call["mood"]), 100.0, UITheme.WARN, 10)
	mrow.add_child(_mood)
	_mood_word = UITheme.bold("", 12)
	_mood_word.custom_minimum_size.x = 70
	_mood_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mrow.add_child(_mood_word)
	v.add_child(mrow)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 230)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var lp := PanelContainer.new()
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.add_theme_stylebox_override("panel", UITheme.box(Color(0.02, 0.03, 0.05), UITheme.LINE, 6, 12))
	_log = VBoxContainer.new()
	_log.add_theme_constant_override("separation", 8)
	lp.add_child(_log)
	_scroll.add_child(lp)
	v.add_child(_scroll)

	_opts = VBoxContainer.new()
	_opts.add_theme_constant_override("separation", 6)
	v.add_child(_opts)
	Audio.sfx("teletype", -8.0)
	Audio.music("tension")
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	_static.queue_redraw()


## A line-level meter instead of a face: the leader is heard through an interpreter, not seen.
func _draw_static() -> void:
	var r := Rect2(Vector2.ZERO, _static.size)
	_static.draw_style_box(UITheme.box(Color(0.02, 0.03, 0.05), Color(UITheme.BAD, 0.6), 6, 0), r)
	for i in 9:
		var x := 8.0 + 6.0 * float(i)
		var h := 6.0 + 18.0 * absf(sin(_t * (3.0 + float(i) * 0.7) + float(i) * 1.3)) * (0.4 + 0.6 * absf(sin(_t * 0.9)))
		_static.draw_line(Vector2(x, 32.0 - h * 0.5), Vector2(x, 32.0 + h * 0.5), Color(UITheme.BAD, 0.85), 3.0)
	_static.draw_circle(Vector2(54, 10), 3.0, Color(UITheme.BAD, 0.5 + 0.5 * absf(sin(_t * 3.0))))


func _refresh() -> void:
	UITheme.clear(_log)
	for l in call["lines"]:
		var you: bool = l[0] == "you"
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.add_child(UITheme.caps("You" if you else "The leader of %s, through the interpreter" % call["name"], UITheme.ACCENT if you else UITheme.MUTED, 9))
		var t := UITheme.wrap(UITheme.label(String(l[1]), 15, UITheme.TEXT if you else Color(0.86, 0.9, 0.96)))
		t.add_theme_font_override("font", UITheme.font_type())
		row.add_child(t)
		_log.add_child(row)
	_mood.value = float(call["mood"])
	var m := float(call["mood"])
	_mood_word.text = "Cold" if m < 30.0 else ("Wary" if m < 50.0 else ("Open" if m < 72.0 else "Warm"))
	var mc: Color = UITheme.BAD if m < 30.0 else (UITheme.WARN if m < 50.0 else UITheme.GOOD)
	_mood_word.add_theme_color_override("font_color", mc)
	UITheme.clear(_opts)
	if int(call["round"]) < 2:
		_opts.add_child(UITheme.caps("How do you open?" if int(call["round"]) == 0 else "What do you put on the table?"))
		for o in Hotline.options(call):
			var b := UITheme.button("%s" % o["label"])
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size.y = 40
			b.tooltip_text = String(o["hint"])
			var id := String(o["id"])
			b.pressed.connect(func():
				Audio.sfx("click")
				_say(id))
			var row := HBoxContainer.new()
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b)
			var hint := UITheme.label(String(o["hint"]), 11, UITheme.MUTED)
			hint.custom_minimum_size.x = 250
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(hint)
			_opts.add_child(row)
	else:
		var s := Game.state
		_opts.add_child(UITheme.wrap(UITheme.bold(_result, 14, UITheme.ACCENT)))
		var chips := Report.diff(s, _before, Report.snapshot(s, iso), 5)
		if not chips.is_empty():
			_opts.add_child(UITheme.chip_row(chips, false, 12))
		var hang := UITheme.button("Hang up  ⏎", "", true)
		hang.custom_minimum_size = Vector2(170, 40)
		hang.size_flags_horizontal = Control.SIZE_SHRINK_END
		hang.pressed.connect(func(): closed.emit(_result))
		_opts.add_child(hang)
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _say(id: String) -> void:
	var s := Game.state
	Hotline.choose(s, call, id)
	Audio.sfx("key", -6.0)
	if int(call["round"]) >= 2:
		_result = Hotline.finish(s, call)
		Audio.sfx("stamp", -4.0)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if int(call["round"]) >= 2 and (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE):
			get_viewport().set_input_as_handled()
			closed.emit(_result)
		elif int(call["round"]) < 2 and k >= KEY_1 and k <= KEY_4:
			var opts := Hotline.options(call)
			if k - KEY_1 < opts.size():
				get_viewport().set_input_as_handled()
				_say(String(opts[k - KEY_1]["id"]))


## Dev smoke test: play the call through.
func smoke() -> void:
	if int(call["round"]) < 2:
		_say(String(Hotline.options(call)[0]["id"]))
	else:
		closed.emit(_result)
