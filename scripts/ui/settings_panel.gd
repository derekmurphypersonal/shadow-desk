class_name SettingsPanel
extends VBoxContainer
## Audio, voice, display and accessibility options.

signal done


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	custom_minimum_size = Vector2(520, 0)
	add_child(UITheme.heading("Settings", 30))
	_section("Sound")
	_slider("Music", "music_volume")
	_slider("Effects", "sfx_volume")
	_section("Voiced briefings")
	if Audio.voice_available():
		_toggle("Advisors read briefings aloud", "voice_enabled")
		_slider("Voice volume", "voice_volume")
		_slider("Voice speed", "voice_rate", 0.6, 1.6)
	else:
		add_child(UITheme.wrap(UITheme.label("No text-to-speech voices were found on this system. On Linux, install speech-dispatcher; macOS and Windows include voices.", 13, UITheme.MUTED)))
	_section("Display")
	_toggle("Fullscreen", "fullscreen")
	_slider("Interface scale", "ui_scale", 0.8, 1.5, 0.05)
	_toggle("Colour-blind friendly map palette", "colorblind")
	_section("Pacing")
	_toggle("Cabinet handles minor events for you", "cabinet_minor")
	_toggle("Monthly newspaper", "show_digest")
	_toggle("Newspaper only for big news", "digest_big_only")
	_toggle("Typewriter text on briefings", "typewriter")
	_toggle("Map effects (strike arcs, aid drops)", "fx")
	var row := HBoxContainer.new()
	var reset := UITheme.button("Replay tutorial")
	reset.pressed.connect(func():
		Settings.set_value("tutorial_done", false)
		reset.text = "Tutorial will play next game")
	row.add_child(reset)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var close := UITheme.button("Done", "", true)
	close.custom_minimum_size.x = 120
	close.pressed.connect(func(): done.emit())
	row.add_child(close)
	add_child(row)


func _section(text: String) -> void:
	add_child(HSeparator.new())
	add_child(UITheme.caps(text))


func _slider(text: String, key: String, lo: float = 0.0, hi: float = 1.0, step: float = 0.01) -> void:
	var h := HBoxContainer.new()
	var l := UITheme.label(text, 14)
	l.custom_minimum_size.x = 180
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_value(key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := UITheme.label("", 13, UITheme.MUTED)
	val.custom_minimum_size.x = 52
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var fmt := func(x: float) -> String:
		return ("%d%%" % int(x * 100.0)) if hi <= 1.0 else ("%.2fx" % x)
	val.text = fmt.call(s.value)
	s.drag_ended.connect(func(_changed): Settings.set_value(key, s.value))
	s.value_changed.connect(func(x):
		val.text = fmt.call(x)
		if key != "ui_scale":
			Settings.set_value(key, x))
	h.add_child(s)
	h.add_child(val)
	add_child(h)


func _toggle(text: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = bool(Settings.get_value(key))
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on):
		Audio.sfx("click")
		Settings.set_value(key, on))
	add_child(c)
