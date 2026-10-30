class_name HomePanel
extends ScrollContainer
## "Oval Office": the state of your presidency at a glance, with trend charts.

var _box: VBoxContainer
var _approval: LineChart
var _world: LineChart
var _score: LineChart


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)
	Game.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	UITheme.clear(_box)
	if not Game.has_game():
		return
	var s := Game.state
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var em := TextureRect.new()
	em.texture = UITheme.tex("res://assets/ui/emblem.png")
	em.custom_minimum_size = Vector2(56, 56)
	em.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	em.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(em)
	var tv := VBoxContainer.new()
	tv.add_child(UITheme.heading("The Oval Office", 22))
	var term := "First term" if s.elections_won == 0 else "Second term"
	tv.add_child(UITheme.label("%s · %s · %s" % [term, String(GameState.DIFFICULTY[s.difficulty]["label"]), s.scenario.get("name", "")], 12, UITheme.MUTED))
	h.add_child(tv)
	_box.add_child(h)

	var agenda := PanelContainer.new()
	agenda.add_theme_stylebox_override("panel", UITheme.box(UITheme.PANEL_2, UITheme.LINE, 8, 12))
	var av := VBoxContainer.new()
	av.add_child(UITheme.caps("Your agenda"))
	av.add_child(UITheme.wrap(UITheme.bold(Main.AGENDA_TEXT.get(s.agenda, s.agenda), 14)))
	av.add_child(UITheme.heading("Score %d" % int(s.agenda_score()), 26, UITheme.ACCENT))
	agenda.add_child(av)
	_box.add_child(agenda)

	var ops: Array = s.us.get("ops", [])
	_box.add_child(UITheme.caps("Operations in progress (%d)" % ops.size()))
	if ops.is_empty():
		_box.add_child(UITheme.label("None. Ongoing options are marked ONGOING in a country's dossier.", 12, UITheme.MUTED))
	for op in ops:
		var b := UITheme.button("%s · %s · month %d" % [Actions.OP_NAMES[op["type"]], s.c(op["iso"]).get("name", op["iso"]), int(op["months"])], CountryPanel.OP_ICONS.get(op["type"], "score"))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(Game.select.bind(String(op["iso"])))
		_box.add_child(b)

	var vals_a: Array = []
	var vals_s: Array = []
	var vals_sc: Array = []
	var vals_h: Array = []
	var vals_f: Array = []
	for snap in s.history:
		vals_a.append(snap["approval"])
		vals_s.append(snap.get("standing", 50.0))
		vals_sc.append(snap["score"])
		vals_h.append(snap["hunger"])
		vals_f.append(snap["freedom"])
	var first: String = s.history[0]["date"] if not s.history.is_empty() else ""
	var last: String = s.history[s.history.size() - 1]["date"] if not s.history.is_empty() else ""
	_box.add_child(UITheme.caps("Approval and world standing"))
	_approval = LineChart.new()
	_approval.custom_minimum_size = Vector2(0, 150)
	_approval.reference = 50.0
	_approval.reference_label = "re-election line"
	_approval.x_labels = [first, last]
	_approval.set_series([{"values": vals_a, "color": UITheme.ACCENT, "name": "Approval"}, {"values": vals_s, "color": Color(0.45, 0.65, 0.95), "name": "Standing"}])
	_box.add_child(_approval)
	_box.add_child(UITheme.caps("The world (population-weighted)"))
	_world = LineChart.new()
	_world.custom_minimum_size = Vector2(0, 140)
	_world.x_labels = [first, last]
	_world.set_series([{"values": vals_h, "color": UITheme.BAD, "name": "Hunger"}, {"values": vals_f, "color": UITheme.GOOD, "name": "Freedom"}])
	_box.add_child(_world)
	var lo := 0.0
	var hi := 10.0
	for v in vals_sc:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	_box.add_child(UITheme.caps("Agenda score"))
	_score = LineChart.new()
	_score.custom_minimum_size = Vector2(0, 120)
	_score.x_labels = [first, last]
	_score.set_series([{"values": vals_sc, "color": UITheme.ACCENT, "name": "Score"}], floorf(lo / 10.0) * 10.0, ceilf(hi / 10.0) * 10.0)
	_box.add_child(_score)

	var facts := GridContainer.new()
	facts.columns = 2
	facts.add_theme_constant_override("h_separation", 20)
	var allies := 0
	var rivals := 0
	for iso in s.active_isos():
		if float(s.countries[iso]["relation"]) >= 50.0:
			allies += 1
		elif float(s.countries[iso]["relation"]) <= -40.0:
			rivals += 1
	for pair in [["Treaties signed", str(int(s.us["treaties"]))], ["Months at peace", str(int(s.us["peace_months"]))],
			["Close allies", str(allies)], ["Hostile states", str(rivals)],
			["Troop deployments", str(s.us["troops"].size())], ["Friendly share of world GDP", "%d%%" % int(s.friendly_gdp_share())]]:
		facts.add_child(UITheme.label(pair[0], 13, UITheme.MUTED))
		facts.add_child(UITheme.bold(pair[1], 13))
	_box.add_child(facts)
