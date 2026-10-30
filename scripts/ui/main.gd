class_name Main
extends Control
## Root screen. Owns the map, the in-game HUD, the main menu, and the modal flow
## (newspaper digest -> election night -> decision cards -> game over).

const AGENDA_TEXT := {
	"peacemaker": "Peacemaker: months without interstate war, plus treaties signed.",
	"humanitarian": "Humanitarian: cut world hunger (population-weighted).",
	"democratiser": "Democratiser: raise world freedom (population-weighted).",
	"hegemon": "Hegemon: grow the share of world GDP friendly to the US.",
}
const AGENDA_ICONS := {"peacemaker": "diplomacy", "humanitarian": "economic", "democratiser": "standing", "hegemon": "military"}
const ENDING_TITLES := {
	"retired": "Your presidency is over", "defeated": "Defeated at the polls", "impeached": "Impeached and removed",
	"cabinet": "Forced out by your own party", "assassinated": "Assassinated", "nuclear": "Nuclear war",
}
const TOP_STATS := [
	["date", "date", "Date"], ["approval", "approval", "Approval"], ["pc", "pc", "Political capital"],
	["congress", "congress", "Congress"], ["standing", "standing", "World standing"], ["scandal", "scandal", "Scandal"],
	["deficit", "deficit", "Deficit"], ["election", "election", "Next election"], ["agenda", "score", "Agenda score"],
]
const TOP_TIPS := {
	"approval": "Public approval. Below 50% on election day and you lose. Driven by domestic spending, deficits, scandal, wars and events.",
	"pc": "Political capital: the currency of action. Regenerates monthly with approval and Congress support.",
	"congress": "Support in Congress. Decides trade deals and votes to authorise force. Below 40% plus a scandal of 100 means impeachment.",
	"standing": "World standing. Raises peace-deal odds and approval; hurt by exposed covert ops and unprovoked strikes.",
	"scandal": "Scandal. Fades by 1 a month. At 100 you face impeachment.",
	"deficit": "Budget deficit as a share of GDP. Above 4% it drags on approval.",
	"election": "Months until the next presidential election.",
	"agenda": "Your agenda score: what history will judge you on.",
}

var map: WorldMap
var hud: Control
var tabs: TabContainer
var top_labels: Dictionary = {}
var top_deltas: Dictionary = {}
var end_button: Button
var ticker: Label
var mode_select: OptionButton
var overlay: Control
var toast: PanelContainer
var toast_label: Label
var menu_layer: Control
var _toast_time := 0.0
var _digest_items: Array = []
var _show_election := false
var _busy := false
var _shot_spec := ""


func _ready() -> void:
	theme = UITheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	hud = VBoxContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_theme_constant_override("separation", 0)
	add_child(hud)
	hud.add_child(_build_top_bar())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	hud.add_child(body)
	var map_holder := Control.new()
	map_holder.name = "MapHolder"
	map_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(map_holder)
	map = WorldMap.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_holder.add_child(map)
	map.country_clicked.connect(Game.select)
	map_holder.add_child(_build_map_controls())

	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(440, 0)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tab_changed.connect(func(_i): Audio.sfx("click", -6.0))
	body.add_child(tabs)
	for spec in [["Country", CountryPanel.new()], ["Oval Office", HomePanel.new()], ["Briefings", BriefingsPanel.new()],
			["Cabinet", CabinetPanel.new()], ["Budget", BudgetPanel.new()]]:
		var c: Control = spec[1]
		c.name = spec[0]
		tabs.add_child(c)

	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", UITheme.box(Color(0.035, 0.05, 0.085), UITheme.LINE, 0, 7))
	var fh := HBoxContainer.new()
	var wire := UITheme.caps("Wire", UITheme.BAD, 10)
	fh.add_child(wire)
	ticker = UITheme.label("", 13, UITheme.MUTED)
	ticker.clip_text = true
	ticker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fh.add_child(ticker)
	foot.add_child(fh)
	hud.add_child(foot)

	menu_layer = Control.new()
	menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_layer)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	toast = PanelContainer.new()
	toast.add_theme_stylebox_override("panel", UITheme.shadow_box(Color(0.03, 0.045, 0.08, 0.96), UITheme.ACCENT, 8, 12))
	toast_label = UITheme.bold("", 14)
	toast.add_child(toast_label)
	toast.visible = false
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)

	Game.state_changed.connect(_refresh)
	Game.selection_changed.connect(_on_select)
	Game.message.connect(show_toast)
	Game.game_ended.connect(_advance_flow)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_shot_spec = arg.trim_prefix("--screenshot=")
	if _shot_spec != "":
		_dev_screenshot(_shot_spec)
	else:
		_show_menu()


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			var tw := create_tween()
			tw.tween_property(toast, "modulate:a", 0.0, 0.25)
			tw.tween_callback(func(): toast.visible = false)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var k := event as InputEventKey
	var cmd := k.is_command_or_control_pressed()
	var in_game := Game.has_game() and menu_layer.get_child_count() == 0
	if cmd and k.keycode == KEY_S and in_game:
		Game.save_game()
	elif cmd and k.keycode == KEY_L and in_game:
		_load()
	elif (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER) and k.shift_pressed and in_game and overlay.get_child_count() == 0:
		_fast_forward()
	elif (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER) and not cmd and in_game and overlay.get_child_count() == 0:
		_end_month()
	elif k.keycode >= KEY_1 and k.keycode <= KEY_6 and not cmd and in_game and overlay.get_child_count() == 0:
		mode_select.select(k.keycode - KEY_1)
		_on_mode(k.keycode - KEY_1)
	elif k.keycode == KEY_ESCAPE and in_game:
		if overlay.get_child_count() > 0 and overlay.has_meta("pause"):
			_close_modal()
		elif overlay.get_child_count() == 0:
			if Game.selected != "":
				Game.select("")
			else:
				_show_pause()
	elif k.keycode == KEY_F11 or (cmd and k.keycode == KEY_F):
		Settings.set_value("fullscreen", not Settings.get_value("fullscreen"))


# ---- Top bar ----

func _build_top_bar() -> Control:
	var pc := PanelContainer.new()
	var bar_sb := UITheme.box(Color(0.03, 0.045, 0.078), Color(0, 0, 0, 0), 0, 8)
	bar_sb.border_width_bottom = 2
	bar_sb.border_color = Color(UITheme.ACCENT, 0.45)
	bar_sb.shadow_color = Color(0, 0, 0, 0.5)
	bar_sb.shadow_size = 10
	pc.add_theme_stylebox_override("panel", bar_sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	pc.add_child(hb)
	var em := TextureRect.new()
	em.texture = UITheme.tex("res://assets/ui/emblem.png")
	em.custom_minimum_size = Vector2(34, 34)
	em.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	em.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(em)
	var title := UITheme.heading("SHADOW DESK", 20, UITheme.ACCENT)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(title)
	for spec in TOP_STATS:
		var key: String = spec[0]
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.tooltip_text = TOP_TIPS.get(key, "")
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.add_child(UITheme.icon_rect(spec[1], 18, UITheme.MUTED))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -3)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cap := UITheme.caps(spec[2], UITheme.MUTED, 9)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(cap)
		var vh := HBoxContainer.new()
		vh.add_theme_constant_override("separation", 4)
		var val := UITheme.heading("-", 18)
		val.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vh.add_child(val)
		var delta := UITheme.bold("", 10, UITheme.MUTED)
		delta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vh.add_child(delta)
		v.add_child(vh)
		cell.add_child(v)
		hb.add_child(cell)
		top_labels[key] = val
		top_deltas[key] = delta
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	var menu_b := UITheme.button("", "settings")
	menu_b.tooltip_text = "Menu (Esc)"
	menu_b.pressed.connect(_show_pause)
	hb.add_child(menu_b)
	var ff := UITheme.button("Skip ahead ⏩")
	ff.custom_minimum_size = Vector2(0, 40)
	ff.tooltip_text = "End months until something needs you: a briefing, an election or big news (Shift+Enter). Up to 6 months."
	ff.pressed.connect(_fast_forward)
	hb.add_child(ff)
	end_button = UITheme.button("End month  ⏎", "", true)
	end_button.custom_minimum_size = Vector2(150, 40)
	end_button.pressed.connect(_end_month)
	hb.add_child(end_button)
	return pc


func _build_map_controls() -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.05, 0.09, 0.88), UITheme.LINE, 8, 8))
	pc.position = Vector2(14, 14)
	var v := HBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	mode_select = OptionButton.new()
	for i in WorldMap.MODES.size():
		mode_select.add_item("%d  %s" % [i + 1, WorldMap.MODE_LABELS[WorldMap.MODES[i]]], i)
	mode_select.item_selected.connect(_on_mode)
	mode_select.focus_mode = Control.FOCUS_NONE
	v.add_child(mode_select)
	var reset := UITheme.button("Reset view")
	reset.pressed.connect(func(): map.reset_view())
	v.add_child(reset)
	return pc


func _on_mode(i: int) -> void:
	map.mode = WorldMap.MODES[i]
	map.queue_redraw()


func _on_select(iso: String) -> void:
	if iso != "":
		tabs.current_tab = 0


func _refresh() -> void:
	if not Game.has_game():
		return
	var s := Game.state
	var u: Dictionary = s.us
	var prev: Dictionary = s.history[s.history.size() - 2] if s.history.size() >= 2 else {}
	(top_labels["date"] as Label).text = s.date_string()
	_set_top("approval", "%d%%" % int(u["approval"]), float(u["approval"]) >= 50.0, float(u["approval"]) < 42.0, float(u["approval"]) - float(prev.get("approval", u["approval"])))
	_set_top("pc", "%d" % int(u["political_capital"]), float(u["political_capital"]) >= 40.0, float(u["political_capital"]) < 15.0, 0.0)
	_set_top("congress", "%d%%" % int(u["congress"]), float(u["congress"]) >= 50.0, float(u["congress"]) < 40.0, 0.0)
	_set_top("standing", "%d" % int(u.get("standing", 50)), float(u.get("standing", 50)) >= 60.0, float(u.get("standing", 50)) < 40.0, float(u.get("standing", 50)) - float(prev.get("standing", u.get("standing", 50))))
	_set_top("scandal", "%d" % int(u["scandal"]), float(u["scandal"]) < 20.0, float(u["scandal"]) >= 60.0, 0.0)
	var deficit := Simulation.budget_deficit_pct(s)
	_set_top("deficit", "%.1f%%" % deficit, deficit < 3.0, deficit > 6.0, 0.0)
	var etxt := ("%d mo" % (s.next_election_turn - s.turn)) if s.elections_enabled else "off"
	if s.next_election_turn >= s.end_turn:
		etxt = "Term ends %d mo" % (s.end_turn - s.turn)
	_set_top("election", etxt, false, s.elections_enabled and s.next_election_turn - s.turn <= 3, 0.0)
	_set_top("agenda", "%d" % int(s.agenda_score()), s.agenda_score() > 0.0, s.agenda_score() < 0.0, 0.0)
	end_button.disabled = s.game_over
	if not s.messages.is_empty():
		var m: Dictionary = s.messages[s.messages.size() - 1]
		ticker.text = "%s   %s" % [m["date"], m["text"]]


func _set_top(key: String, text: String, good: bool, bad: bool, delta: float) -> void:
	var l: Label = top_labels[key]
	l.text = text
	l.add_theme_color_override("font_color", UITheme.GOOD if good else (UITheme.BAD if bad else UITheme.TEXT))
	var d: Label = top_deltas[key]
	if absf(delta) >= 0.5:
		d.text = ("▲%d" if delta > 0 else "▼%d") % int(round(absf(delta)))
		d.add_theme_color_override("font_color", UITheme.GOOD if delta > 0 else UITheme.BAD)
	else:
		d.text = ""


func show_toast(text: String) -> void:
	if text == "":
		return
	toast_label.text = text
	toast.visible = true
	toast.modulate.a = 1.0
	toast.reset_size()
	toast.position = Vector2((size.x - toast.size.x) * 0.5, size.y - toast.size.y - 56)
	_toast_time = 3.2
	if text.begins_with("EXPOSED") or text.contains("exposed") or text.contains("refuses") or text.contains("failed") or text.contains("blocked"):
		Audio.sfx("alert", -6.0)
	elif text.contains("aid"):
		Audio.sfx("coin", -4.0)
	elif text.contains("strike") or text.contains("Air strikes"):
		Audio.sfx("boom", -4.0)


# ---- Turn flow ----

func _end_month() -> void:
	if not Game.has_game() or Game.state.game_over or _busy:
		return
	if not Game.state.pending.is_empty():
		_advance_flow()
		return
	Game.end_month()
	var s := Game.state
	_digest_items = _digest_for(s.turn, s.turn)
	_show_election = not s.last_election.is_empty() and int(s.last_election.get("turn", -1)) == s.turn
	_advance_flow()


func _digest_for(last: int, first: int) -> Array:
	if not Settings.get_value("show_digest"):
		return []
	var items := Game.state.turn_headlines(last, first)
	if Settings.get_value("digest_big_only"):
		var big: Array = []
		for m in items:
			if GameState.is_big_news(m):
				big.append(m)
		items = big
	return items.slice(0, 7)


func _fast_forward() -> void:
	if not Game.has_game() or Game.state.game_over or _busy:
		return
	if not Game.state.pending.is_empty():
		_advance_flow()
		return
	Audio.sfx("teletype", -8.0)
	var first := Game.fast_forward(6)
	if first < 0:
		return
	var s := Game.state
	_digest_items = _digest_for(s.turn, first)
	_show_election = not s.last_election.is_empty() and int(s.last_election.get("turn", -1)) >= first
	show_toast("Skipped to %s." % s.date_string())
	_advance_flow()


func _advance_flow() -> void:
	if not Game.has_game():
		return
	var s := Game.state
	if overlay.get_child_count() > 0 and not overlay.has_meta("pause"):
		return
	if not _digest_items.is_empty():
		var items := _digest_items
		_digest_items = []
		var dg := Digest.new().setup(items)
		_open_modal(dg, 0.55)
		dg.closed.connect(func():
			_close_modal()
			_advance_flow())
		return
	if _show_election:
		_show_election = false
		var en := ElectionNight.new().setup(s.last_election)
		_open_modal(en, 0.7)
		en.closed.connect(func():
			_close_modal()
			_advance_flow())
		return
	if s.game_over:
		_show_game_over()
		return
	if not s.pending.is_empty():
		var card: Dictionary = s.pending[0]
		if String(card.get("ctx", "")) != "":
			Game.select(card["ctx"])
			map.focus(card["ctx"])
		var bc := BriefingCard.new().setup(card)
		_open_modal(bc, 0.6)
		bc.chosen.connect(func(i):
			_close_modal()
			Game.choose(i)
			_advance_flow())
		return
	Audio.music("situation")


func _open_modal(content: Control, dim_alpha: float = 0.6) -> void:
	UITheme.clear(overlay)
	overlay.remove_meta("pause")
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.03, dim_alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.modulate.a = 0.0
	overlay.add_child(dim)
	create_tween().tween_property(dim, "modulate:a", 1.0, 0.2)
	overlay.add_child(content)


func _close_modal() -> void:
	UITheme.clear(overlay)
	overlay.remove_meta("pause")
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _panel_modal(width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(width, 0)
	pc.add_theme_stylebox_override("panel", UITheme.shadow_box(UITheme.PANEL, UITheme.ACCENT.darkened(0.2), 12, 26))
	center.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pc.add_child(v)
	_open_modal(center, 0.65)
	return v


func _show_pause() -> void:
	if not Game.has_game() or menu_layer.get_child_count() > 0:
		return
	var v := _panel_modal(360)
	overlay.set_meta("pause", true)
	v.add_child(UITheme.heading("Paused", 30))
	_pause_button(v, "Resume", _close_modal, true)
	_pause_button(v, "Save game", _pause_save)
	_pause_button(v, "Load game", _pause_load)
	_pause_button(v, "Settings", _show_settings_in_game)
	_pause_button(v, "How to play", _show_help)
	_pause_button(v, "Quit to main menu", _pause_menu)
	_pause_button(v, "Quit to desktop", get_tree().quit)


func _pause_button(v: VBoxContainer, text: String, cb: Callable, primary: bool = false) -> void:
	var b := UITheme.button(text, "", primary)
	b.custom_minimum_size.y = 40
	b.pressed.connect(cb)
	v.add_child(b)


func _pause_save() -> void:
	Game.save_game()
	_close_modal()


func _pause_load() -> void:
	_close_modal()
	_load()


func _pause_menu() -> void:
	_close_modal()
	_show_menu()


func _show_settings_in_game() -> void:
	var v := _panel_modal(560)
	overlay.set_meta("pause", true)
	var sp := SettingsPanel.new()
	sp.done.connect(_close_modal)
	v.add_child(sp)


func _show_help() -> void:
	var v := _panel_modal(640)
	overlay.set_meta("pause", true)
	v.add_child(UITheme.heading("How to play", 30))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(580, 0)
	rt.text = """[b]Each month[/b] you read your briefings, act on the world, then press [b]End month[/b] (Enter).

[b]Actions[/b] cost political capital (PC) and money from your budget funds. Hover any action to see its cost, odds and risks. Covert actions can be exposed, raising scandal and hurting world standing.

[b]Your cabinet[/b] advises on every country. Ignore them too often and they resign; four resignations in a year ends your presidency.

[b]Rivals[/b] court countries with loans and arms. Envoys, aid and trade deals pull them back.

[b]You lose[/b] if approval sinks below 50% on election day, if scandal hits 100 while Congress turns on you, or worse.

[b]Keys[/b]: Enter end month · 1-6 map modes · 1-4 pick a briefing option · Space finish briefing text · Esc deselect/menu · Cmd/Ctrl+S save · F11 fullscreen."""
	v.add_child(rt)
	var b := UITheme.button("Got it", "", true)
	b.pressed.connect(_close_modal)
	v.add_child(b)


func _load() -> void:
	if Game.load_game():
		_enter_game(false)


# ---- Menu ----

func _show_menu() -> void:
	_close_modal()
	hud.visible = false
	UITheme.clear(menu_layer)
	menu_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	if not Game.has_game():
		Game.new_game("modern_2026", "peacemaker", true, 7)
	var backdrop := WorldMap.new()
	backdrop.attract = true
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mode = "bloc"
	menu_layer.add_child(backdrop)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.06, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var em := TextureRect.new()
	em.texture = UITheme.tex("res://assets/ui/emblem.png")
	em.custom_minimum_size = Vector2(150, 150)
	em.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	em.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(em)
	var t := UITheme.heading("SHADOW DESK", 84, UITheme.TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 10)
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	v.add_child(t)
	var tag := UITheme.label("The world is on your desk.", 18, UITheme.ACCENT)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size.y = 20
	v.add_child(gap)
	var buttons: Array = []
	if Game.has_save():
		buttons.append(["Continue", func(): _load(), true])
	buttons.append(["New presidency", _show_new_game, not Game.has_save()])
	buttons.append(["Settings", _show_settings_menu, false])
	buttons.append(["Credits", _show_credits, false])
	buttons.append(["Quit", func(): get_tree().quit(), false])
	for spec in buttons:
		var b := UITheme.button(spec[0], "", spec[2])
		b.custom_minimum_size = Vector2(300, 46)
		b.add_theme_font_override("font", UITheme.font_head())
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(spec[1])
		var c := CenterContainer.new()
		c.add_child(b)
		v.add_child(c)
	var ver := UITheme.label("v%s" % ProjectSettings.get_setting("application/config/version", "1.0"), 11, UITheme.MUTED)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -70
	ver.offset_top = -30
	menu_layer.add_child(ver)
	v.modulate.a = 0.0
	create_tween().tween_property(v, "modulate:a", 1.0, 0.8)
	Audio.music("theme", 2.0)


func _menu_panel(width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(width, 0)
	pc.add_theme_stylebox_override("panel", UITheme.shadow_box(UITheme.PANEL, UITheme.ACCENT.darkened(0.2), 12, 28))
	center.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pc.add_child(v)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	menu_layer.add_child(dim)
	menu_layer.add_child(center)
	var close := func():
		dim.queue_free()
		center.queue_free()
	v.set_meta("close", close)
	return v


func _show_settings_menu() -> void:
	var v := _menu_panel(560)
	var sp := SettingsPanel.new()
	sp.done.connect(v.get_meta("close"))
	v.add_child(sp)


func _show_credits() -> void:
	var v := _menu_panel(600)
	v.add_child(UITheme.heading("Credits", 30))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(540, 0)
	rt.text = """[b]Shadow Desk[/b] v%s
A spiritual successor to the presidential world-power simulations of the early 1990s.

[b]Design, code, art and music[/b]: made with Claude for Derek Murphy. Portraits, icons, music and sound effects are generated procedurally from code; no third-party art or audio.

[b]Data[/b]: World Bank Open Data (CC BY 4.0). Military expenditure series from SIPRI via the World Bank. Country shapes from Natural Earth (public domain).

[b]Fonts[/b]: Oswald, Inter and Courier Prime, under the SIL Open Font License.

[b]Engine[/b]: Godot Engine (MIT licence), godotengine.org.

All advisors and events are fictional. Countries are real; their leaders are never named. Figures are game values, not statistics.""" % ProjectSettings.get_setting("application/config/version", "1.0")
	v.add_child(rt)
	var b := UITheme.button("Close", "", true)
	b.pressed.connect(v.get_meta("close"))
	v.add_child(b)


func _show_new_game() -> void:
	var v := _menu_panel(900)
	v.add_child(UITheme.heading("New presidency", 34))
	var metas := ScenarioLoader.list_scenarios()
	var picked := {"scenario": 0, "agenda": "peacemaker", "difficulty": "normal"}
	v.add_child(UITheme.caps("Choose your moment"))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	var card_buttons: Array = []
	for i in metas.size():
		var m: Dictionary = metas[i]
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(420, 170)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", UITheme.box(UITheme.PANEL_2, UITheme.LINE, 10, 16))
		b.add_theme_stylebox_override("hover", UITheme.box(UITheme.PANEL_2.lightened(0.06), UITheme.ACCENT.darkened(0.3), 10, 16))
		b.add_theme_stylebox_override("pressed", UITheme.box(UITheme.PANEL_2.lerp(UITheme.ACCENT, 0.14), UITheme.ACCENT, 10, 16))
		b.add_theme_stylebox_override("hover_pressed", UITheme.box(UITheme.PANEL_2.lerp(UITheme.ACCENT, 0.18), UITheme.ACCENT, 10, 16))
		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 16
		inner.offset_top = 12
		inner.offset_right = -16
		inner.offset_bottom = -12
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var yr := UITheme.heading(str(int(m["start"]["year"])), 42, UITheme.ACCENT)
		yr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(yr)
		var nm := UITheme.bold(String(m["name"]), 16)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(nm)
		var ds := UITheme.wrap(UITheme.label(String(m["description"]).split(" Figures are")[0], 12, UITheme.MUTED))
		ds.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(ds)
		b.add_child(inner)
		b.button_pressed = i == 0
		b.pressed.connect(func():
			Audio.sfx("click")
			picked["scenario"] = i
			for j in card_buttons.size():
				card_buttons[j].button_pressed = j == i)
		card_buttons.append(b)
		cards.add_child(b)
	v.add_child(cards)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var ag := VBoxContainer.new()
	ag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ag.add_child(UITheme.caps("Your agenda: what history will judge"))
	var agroup := ButtonGroup.new()
	for key in AGENDA_TEXT:
		var cb := CheckBox.new()
		cb.button_group = agroup
		cb.text = AGENDA_TEXT[key]
		cb.icon = UITheme.icon(AGENDA_ICONS[key])
		cb.add_theme_constant_override("icon_max_width", 16)
		cb.button_pressed = key == "peacemaker"
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on):
			if on:
				picked["agenda"] = key)
		ag.add_child(cb)
	row.add_child(ag)
	var dg := VBoxContainer.new()
	dg.add_child(UITheme.caps("Difficulty"))
	var dgroup := ButtonGroup.new()
	for key in GameState.DIFFICULTY:
		var cb := CheckBox.new()
		cb.button_group = dgroup
		cb.text = GameState.DIFFICULTY[key]["label"]
		cb.button_pressed = key == "normal"
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on):
			if on:
				picked["difficulty"] = key)
		dg.add_child(cb)
	var el := CheckButton.new()
	el.text = "Elections"
	el.button_pressed = true
	el.focus_mode = Control.FOCUS_NONE
	dg.add_child(el)
	row.add_child(dg)
	v.add_child(row)
	var br := HBoxContainer.new()
	var back := UITheme.button("Back")
	back.custom_minimum_size = Vector2(120, 44)
	back.pressed.connect(v.get_meta("close"))
	br.add_child(back)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(sp)
	var go := UITheme.button("Take the oath", "", true)
	go.custom_minimum_size = Vector2(220, 48)
	go.add_theme_font_override("font", UITheme.font_head())
	go.add_theme_font_size_override("font_size", 20)
	go.pressed.connect(func():
		var id: String = metas[picked["scenario"]]["id"]
		_start_game(id, picked["agenda"], el.button_pressed, picked["difficulty"]))
	br.add_child(go)
	v.add_child(br)


func _start_game(id: String, agenda: String, elections: bool, difficulty: String) -> void:
	Game.new_game(id, agenda, elections, -1, difficulty)
	# Oath transition.
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.modulate.a = 0.0
	add_child(fade)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.add_child(c)
	var vb := VBoxContainer.new()
	c.add_child(vb)
	var l1 := UITheme.heading(Game.state.date_string().to_upper(), 20, UITheme.ACCENT)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l1)
	var l2 := UITheme.label("\"I do solemnly swear that I will faithfully execute the office...\"", 24, UITheme.TEXT)
	l2.add_theme_font_override("font", UITheme.font_type())
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l2)
	Audio.stop_music(1.5)
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.8)
	tw.tween_callback(func():
		_enter_game(true)
		Audio.sfx("sting_win", -6.0))
	tw.tween_interval(2.4)
	tw.tween_property(fade, "modulate:a", 0.0, 0.9)
	tw.tween_callback(func():
		fade.queue_free()
		if not Settings.get_value("tutorial_done"):
			_run_tutorial()
		else:
			_advance_flow())


func _enter_game(_fresh: bool) -> void:
	UITheme.clear(menu_layer)
	menu_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = true
	map.reset_view()
	tabs.current_tab = 1
	_refresh()
	Audio.music("situation")
	if not _fresh:
		_advance_flow()


func _run_tutorial() -> void:
	var steps := [
		{"target": null, "title": "Welcome, Mr. or Madam President", "text": "You run US foreign policy one month at a time. This short briefing shows you the desk. You can replay it from Settings."},
		{"target": map, "title": "The world", "text": "Every country is simulated: economy, stability, hunger, freedom, military, and its feelings about you. Click a country to open its dossier. Scroll or pinch to zoom, drag to pan. Keys 1-6 change the map view."},
		{"target": tabs, "title": "The dossier", "text": "The Country tab shows what we know (fuzzy if intelligence is weak), what you can do, and what each advisor recommends. Hover an action for its cost and odds."},
		{"target": top_labels["approval"].get_parent().get_parent().get_parent(), "title": "Your standing", "text": "Approval decides elections. Political capital pays for actions. Congress votes on trade deals and the use of force. Scandal at 100 means impeachment hearings."},
		{"target": end_button, "title": "End the month", "text": "When you are done, end the month (Enter). The world moves, crises arrive as briefing cards, and a newspaper tells you what happened."},
		{"target": null, "title": "One last thing", "text": "Rival powers court countries with loans and arms. Wars break out. Advisors resign if ignored. Pick your battles. Good luck."},
	]
	var tut := Tutorial.new().setup(steps)
	add_child(tut)
	tut.finished.connect(func():
		tut.queue_free()
		_advance_flow())


func _show_game_over() -> void:
	var s := Game.state
	var v := _panel_modal(720)
	var grade := _grade(s)
	Audio.music("theme")
	var head := HBoxContainer.new()
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UITheme.caps("%s · %d months in office" % [s.date_string(), s.turn]))
	hv.add_child(UITheme.heading(ENDING_TITLES.get(s.ending, "The end"), 36))
	hv.add_child(UITheme.wrap(UITheme.label(s.ending_text, 15)))
	head.add_child(hv)
	var gbox := PanelContainer.new()
	gbox.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.ACCENT, 0.12), UITheme.ACCENT, 10, 14))
	var gv := VBoxContainer.new()
	gv.add_child(UITheme.caps("History's verdict", UITheme.MUTED, 10))
	var gl := UITheme.heading(grade, 64, UITheme.ACCENT)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(gl)
	gbox.add_child(gv)
	head.add_child(gbox)
	v.add_child(head)
	var chart := LineChart.new()
	chart.custom_minimum_size = Vector2(0, 170)
	var vals: Array = []
	var stand: Array = []
	for snap in s.history:
		vals.append(snap["approval"])
		stand.append(snap.get("standing", 50.0))
	chart.reference = 50.0
	chart.reference_label = "re-election line"
	if not s.history.is_empty():
		chart.x_labels = [s.history[0]["date"], s.history[s.history.size() - 1]["date"]]
	chart.set_series([{"values": vals, "color": UITheme.ACCENT, "name": "Approval"}, {"values": stand, "color": Color(0.45, 0.65, 0.95), "name": "Standing"}])
	v.add_child(chart)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 26)
	for pair in [["Agenda", s.agenda.capitalize()], ["Score", str(int(s.agenda_score()))], ["Treaties", str(int(s.us["treaties"]))],
			["Elections won", str(s.elections_won)], ["Final approval", "%d%%" % int(s.us["approval"])], ["World standing", str(int(s.us.get("standing", 50)))],
			["Difficulty", String(GameState.DIFFICULTY[s.difficulty]["label"])], ["Scenario", String(s.scenario.get("name", ""))]]:
		g.add_child(UITheme.label(pair[0], 12, UITheme.MUTED))
		g.add_child(UITheme.bold(pair[1], 13))
	v.add_child(g)
	var br := HBoxContainer.new()
	var menu_b := UITheme.button("Main menu")
	menu_b.custom_minimum_size = Vector2(160, 44)
	menu_b.pressed.connect(func():
		_close_modal()
		_show_menu())
	br.add_child(menu_b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(sp)
	var again := UITheme.button("New presidency", "", true)
	again.custom_minimum_size = Vector2(200, 44)
	again.pressed.connect(func():
		_close_modal()
		_show_menu()
		_show_new_game())
	br.add_child(again)
	v.add_child(br)


static func _grade(s: GameState) -> String:
	return s.grade()


## Dev hook: godot --path . -- --screenshot=out.png[,scenario,iso,months,mode,view]
## view: card | digest | menu | newgame | over | tutorial | election | tab:<n>
func _dev_screenshot(spec: String) -> void:
	var parts := spec.split(",")
	var scenario := parts[1] if parts.size() > 1 else "classic_1990"
	var iso := parts[2] if parts.size() > 2 else "IRQ"
	var months := int(parts[3]) if parts.size() > 3 else 0
	var view := parts[5] if parts.size() > 5 else ""
	Settings.values["tutorial_done"] = true
	Settings.values["voice_enabled"] = false
	Game.new_game(scenario, "peacemaker", true, 1990)
	for i in months:
		while not Game.state.pending.is_empty():
			Game.choose(0)
		Game.end_month()
	_enter_game(true)
	if parts.size() > 4 and parts[4] != "":
		var m := int(parts[4])
		mode_select.select(m)
		_on_mode(m)
	Game.select(iso)
	if view.begins_with("tab:"):
		tabs.current_tab = int(view.trim_prefix("tab:"))
	match view:
		"card":
			_advance_flow()
		"digest":
			_digest_items = Game.state.turn_headlines()
			if _digest_items.is_empty():
				_digest_items = [{"text": "A quiet month"}]
			_advance_flow()
		"menu":
			_show_menu()
		"newgame":
			_show_menu()
			_show_new_game()
		"over":
			Simulation.trigger_ending(Game.state, "retired", "Your second term is over. You leave office with 54% approval.")
			_show_game_over()
		"election":
			Game.state.last_election = {"vote": 52.4, "won": true, "turn": Game.state.turn}
			_show_election = true
			_advance_flow()
		"tutorial":
			_run_tutorial()
		"settings":
			_show_settings_in_game()
		"ops", "fx":
			var s := Game.state
			s.us["political_capital"] = 100.0
			for k in s.us["funds"]:
				s.us["funds"][k] = 50.0
			for job in [[iso, "op_air"], ["SOM", "op_aid"], ["KWT", "op_support"], ["CUB", "op_invade"], ["LBY", "strike"], ["ETH", "aid"], ["SUN", "envoy"]]:
				s.c(job[0])["relation"] = minf(float(s.c(job[0])["relation"]), 0.0) if job[1] in ["op_invade", "op_air", "strike"] else float(s.c(job[0])["relation"])
				if Actions.available(s, job[0], job[1])["ok"]:
					s.us["congress"] = 100.0
					Actions.perform(s, job[0], job[1], Game.map_data)
			Game.state_changed.emit()
			Game.select(iso)
	var wait := 40 if view != "election" else 400
	if view == "fx":
		wait = 6
	for i in wait:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(parts[0])
	get_tree().quit()
