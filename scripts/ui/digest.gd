class_name Digest
extends CenterContainer
## End-of-month newspaper front page summarising the month's headlines.

signal closed

var headlines: Array = []
var _paper: PanelContainer


func setup(items: Array) -> Digest:
	headlines = items
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s := Game.state
	_paper = PanelContainer.new()
	_paper.custom_minimum_size = Vector2(760, 0)
	_paper.add_theme_stylebox_override("panel", UITheme.shadow_box(Color(0.93, 0.91, 0.86), Color(0.7, 0.66, 0.58), 2, 26))
	add_child(_paper)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_paper.add_child(v)
	var top := HBoxContainer.new()
	top.add_child(_l("VOL. %d  ·  NO. %d" % [s.year - 1850, s.turn], UITheme.font_type(), 11, Color(0.35, 0.33, 0.3)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(_l("%s  ·  25¢" % s.date_string().to_upper(), UITheme.font_type(), 11, Color(0.35, 0.33, 0.3)))
	v.add_child(top)
	var mast := _l("The Daily Dispatch", UITheme.font_head(), 54, Color(0.08, 0.08, 0.08))
	mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(mast)
	v.add_child(_rule(3))
	var u: Dictionary = s.us
	var line := _l("APPROVAL %d%%   ·   CONGRESS %d%%   ·   WORLD STANDING %d   ·   WARS RAGING: %d" % [int(u["approval"]), int(u["congress"]), int(u.get("standing", 50)), s.wars.size()], UITheme.font_type_bold(), 12, Color(0.2, 0.2, 0.2))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(line)
	v.add_child(_rule(1))
	if headlines.is_empty():
		v.add_child(_l("A quiet month in Washington.", UITheme.font_head(), 30, Color(0.1, 0.1, 0.1)))
	else:
		var lead: Dictionary = headlines[0]
		var big := _l(_headline(String(lead["text"])), UITheme.font_head(), 34, Color(0.08, 0.08, 0.08))
		UITheme.wrap(big)
		var lead_row := HBoxContainer.new()
		lead_row.add_theme_constant_override("separation", 16)
		var pic := TextureRect.new()
		pic.texture = UITheme.tex("res://assets/art/%s_news.png" % Events.art_for("", String(lead["text"])))
		pic.custom_minimum_size = Vector2(300, 100)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		big.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		big.custom_minimum_size.x = 400
		lead_row.add_child(big)
		lead_row.add_child(pic)
		v.add_child(lead_row)
		var cols := GridContainer.new()
		cols.columns = 2
		cols.add_theme_constant_override("h_separation", 26)
		cols.add_theme_constant_override("v_separation", 10)
		for i in range(1, mini(headlines.size(), 7)):
			var item := _l(String(headlines[i]["text"]), UITheme.font_type(), 14, Color(0.15, 0.15, 0.15))
			UITheme.wrap(item)
			item.custom_minimum_size = Vector2(340, 0)
			cols.add_child(item)
		if cols.get_child_count() > 0:
			v.add_child(_rule(1))
			v.add_child(cols)
	v.add_child(_rule(1))
	var hint := _l("Click or press Enter to continue", UITheme.font_type(), 11, Color(0.45, 0.42, 0.38))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	_paper.modulate.a = 0.0
	_paper.pivot_offset = Vector2(380, 250)
	_paper.rotation_degrees = -3.0
	_paper.scale = Vector2(0.85, 0.85)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_paper, "modulate:a", 1.0, 0.18)
	tw.tween_property(_paper, "rotation_degrees", 0.0, 0.28)
	tw.tween_property(_paper, "scale", Vector2.ONE, 0.28)
	Audio.sfx("teletype")
	mouse_filter = Control.MOUSE_FILTER_STOP


func _headline(text: String) -> String:
	var t := text.trim_prefix("WAR: ").trim_prefix("ELECTION: ").trim_prefix("MIDTERMS: ")
	var dot := t.find(". ")
	if dot > 0 and dot < 90:
		t = t.substr(0, dot)
	return t.trim_suffix(".")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if is_queued_for_deletion():
		return
	Audio.sfx("paper", -6.0)
	closed.emit()


func _l(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _rule(th: int) -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_stylebox_override("separator", UITheme.line_box(Color(0.15, 0.15, 0.15), th))
	return s
