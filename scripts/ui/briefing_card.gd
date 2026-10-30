class_name BriefingCard
extends CenterContainer
## A decision card styled as a page from the President's Daily Brief, read aloud by the briefing advisor.

signal chosen(index: int)

var card: Dictionary
var _body: Label
var _reveal_tween: Tween
var _last_chars := 0
var _paper: PanelContainer
var _locked := false


func setup(c: Dictionary) -> BriefingCard:
	card = c
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s := Game.state
	var speaker_id: String = card.get("speaker", "nsa")
	var adv := s.advisor(speaker_id)
	var person: String = adv.get("name", "")
	if int(adv.get("vacant_months", 0)) > 0:
		adv = s.advisor("chief")
		person = adv.get("name", "")

	_paper = PanelContainer.new()
	_paper.custom_minimum_size = Vector2(700, 0)
	_paper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := UITheme.shadow_box(UITheme.PAPER, Color(0.75, 0.7, 0.6), 4, 28)
	_paper.add_theme_stylebox_override("panel", sb)
	add_child(_paper)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_paper.add_child(v)

	var head := HBoxContainer.new()
	var masthead := _type("THE PRESIDENT'S DAILY BRIEF", 15, true)
	masthead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(masthead)
	var stamp := Label.new()
	stamp.text = "TOP SECRET"
	stamp.add_theme_font_override("font", UITheme.font_type_bold())
	stamp.add_theme_font_size_override("font_size", 16)
	stamp.add_theme_color_override("font_color", UITheme.STAMP)
	var stamp_box := StyleBoxFlat.new()
	stamp_box.bg_color = Color(0, 0, 0, 0)
	stamp_box.border_color = UITheme.STAMP
	stamp_box.set_border_width_all(3)
	stamp_box.set_corner_radius_all(3)
	stamp_box.set_content_margin_all(4)
	stamp.add_theme_stylebox_override("normal", stamp_box)
	stamp.rotation_degrees = -4.0
	head.add_child(stamp)
	v.add_child(head)
	v.add_child(_type("%s  ·  Item %d  ·  Eyes only" % [s.date_string().to_upper(), s.turn + 1], 12, false, Color(0.4, 0.37, 0.33)))
	var art_tex := UITheme.tex("res://assets/art/%s.png" % String(card.get("art", "diplomacy")))
	if art_tex:
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", UITheme.shadow_box(Color(0.99, 0.98, 0.95), Color(0.8, 0.76, 0.68), 2, 6))
		var art := TextureRect.new()
		art.texture = art_tex
		art.custom_minimum_size = Vector2(632, 168)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		frame.add_child(art)
		v.add_child(frame)
	else:
		v.add_child(_rule())

	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 14)
	var pr := UITheme.portrait_rect(person, 76)
	who.add_child(pr)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := _type(String(card["title"]), 22, true)
	UITheme.wrap(title)
	tv.add_child(title)
	tv.add_child(_type("Briefed by %s, %s" % [person, adv.get("title", "")], 13, false, Color(0.38, 0.35, 0.31)))
	who.add_child(tv)
	v.add_child(who)

	_body = _type(String(card["text"]), 16, false)
	UITheme.wrap(_body)
	_body.custom_minimum_size = Vector2(640, 0)
	_body.mouse_filter = Control.MOUSE_FILTER_STOP
	_body.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _finish_reveal())
	v.add_child(_body)
	v.add_child(_rule())
	v.add_child(_type("YOUR DECISION", 12, true, Color(0.38, 0.35, 0.31)))

	var choices: Array = card.get("choices", [])
	for i in choices.size():
		var ch: Dictionary = choices[i]
		var b := Button.new()
		b.text = "  " + String(ch["label"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", UITheme.font_type_bold())
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", UITheme.INK)
		b.add_theme_color_override("font_hover_color", Color(0, 0, 0))
		b.add_theme_color_override("font_pressed_color", Color(0, 0, 0))
		b.add_theme_stylebox_override("normal", UITheme.box(Color(0.9, 0.86, 0.77), Color(0.6, 0.55, 0.47), 4, 10))
		b.add_theme_stylebox_override("hover", UITheme.box(Color(0.98, 0.93, 0.8), UITheme.ACCENT.darkened(0.15), 4, 10))
		b.add_theme_stylebox_override("pressed", UITheme.box(Color(0.85, 0.78, 0.62), UITheme.STAMP, 4, 10))
		b.add_theme_stylebox_override("focus", UITheme.box(Color(0, 0, 0, 0), UITheme.ACCENT, 4, 10))
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_entered.connect(func(): Audio.sfx("hover", -14.0))
		b.pressed.connect(_on_choice.bind(i, b))
		v.add_child(b)
		var hint := _stance_line(s, ch)
		if hint != "":
			var hl := _type(hint, 12, false, Color(0.42, 0.39, 0.35))
			v.add_child(hl)

	var foot := HBoxContainer.new()
	if s.pending.size() > 1:
		foot.add_child(_type("%d more item%s in today's brief" % [s.pending.size() - 1, "s" if s.pending.size() > 2 else ""], 12, false, Color(0.45, 0.42, 0.38)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	if Audio.voice_available():
		var vb := Button.new()
		vb.flat = true
		vb.icon = UITheme.icon("speaker_on" if Settings.get_value("voice_enabled") else "speaker_off")
		vb.add_theme_color_override("icon_normal_color", Color(0.35, 0.32, 0.28))
		vb.tooltip_text = "Voiced briefings on/off"
		vb.focus_mode = Control.FOCUS_NONE
		vb.add_theme_constant_override("icon_max_width", 20)
		vb.pressed.connect(func():
			var on: bool = not Settings.get_value("voice_enabled")
			Settings.set_value("voice_enabled", on)
			vb.icon = UITheme.icon("speaker_on" if on else "speaker_off")
			if on:
				Audio.speak(person, "%s. %s" % [card["title"], card["text"]])
			else:
				Audio.stop_voice())
		foot.add_child(vb)
	v.add_child(foot)

	# Entrance: slide up and fade in, paper rustle, voice.
	_paper.modulate.a = 0.0
	_paper.pivot_offset = Vector2(350, 300)
	_paper.scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_paper, "modulate:a", 1.0, 0.16)
	tw.tween_property(_paper, "scale", Vector2.ONE, 0.2)
	Audio.sfx("paper")
	if speaker_id in ["nsa", "defense"] or String(card["title"]).to_lower().contains("war"):
		Audio.music("tension")
	Audio.speak(person, "%s. %s" % [card["title"], card["text"]])
	if Settings.get_value("typewriter"):
		_body.visible_ratio = 0.0
		var dur := clampf(String(card["text"]).length() * 0.006, 0.4, 1.3)
		_reveal_tween = create_tween()
		_reveal_tween.tween_property(_body, "visible_ratio", 1.0, dur)


func _process(_delta: float) -> void:
	if _body == null or _body.visible_ratio >= 1.0:
		return
	var chars := int(_body.visible_ratio * _body.text.length())
	if chars - _last_chars >= 4:
		_last_chars = chars
		Audio.sfx("key", -10.0)


func _finish_reveal() -> void:
	if _reveal_tween and _reveal_tween.is_running():
		_reveal_tween.kill()
	_body.visible_ratio = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_4:
			var idx := k - KEY_1
			if idx < card.get("choices", []).size():
				get_viewport().set_input_as_handled()
				_on_choice(idx, null)
		elif k == KEY_SPACE:
			_finish_reveal()
			get_viewport().set_input_as_handled()


func _on_choice(i: int, b: Button) -> void:
	if _locked:
		return
	_locked = true
	Audio.stop_voice()
	Audio.sfx("stamp")
	var stamp := Label.new()
	stamp.text = "DECIDED"
	stamp.add_theme_font_override("font", UITheme.font_type_bold())
	stamp.add_theme_font_size_override("font_size", 44)
	stamp.add_theme_color_override("font_color", Color(UITheme.STAMP, 0.85))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(UITheme.STAMP, 0.85)
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	stamp.add_theme_stylebox_override("normal", sb)
	stamp.top_level = true
	add_child(stamp)
	stamp.reset_size()
	var center := _paper.get_global_rect().get_center()
	stamp.position = center - stamp.size * 0.5
	stamp.pivot_offset = stamp.size * 0.5
	stamp.rotation_degrees = -12.0
	stamp.scale = Vector2(1.8, 1.8)
	stamp.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(stamp, "scale", Vector2.ONE, 0.18)
	tw.tween_property(stamp, "modulate:a", 1.0, 0.1)
	tw.chain().tween_interval(0.22)
	tw.chain().tween_callback(func(): chosen.emit(i))


func _stance_line(s: GameState, ch: Dictionary) -> String:
	var fans: Array = []
	var critics: Array = []
	var adv: Dictionary = ch.get("advisors", {})
	for id in adv:
		var t: String = String(s.advisor(id).get("title", id)).replace("Secretary of ", "").replace(" Director", "").replace(" Ambassador", "").replace("National Security Advisor", "NSA").replace(" Secretary", "")
		if float(adv[id]) > 0.0:
			fans.append(t)
		elif float(adv[id]) < 0.0:
			critics.append(t)
	var parts: Array = []
	if not fans.is_empty():
		parts.append("For: " + ", ".join(fans))
	if not critics.is_empty():
		parts.append("Against: " + ", ".join(critics))
	return "     " + "   ·   ".join(parts) if not parts.is_empty() else ""


func _type(text: String, size: int, bold: bool, color: Color = UITheme.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UITheme.font_type_bold() if bold else UITheme.font_type())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _rule() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_stylebox_override("separator", UITheme.line_box(Color(0.55, 0.5, 0.42), 2))
	return s
