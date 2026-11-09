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
	if s.us.get("third_term", false):
		term = "Third term, without elections"
	tv.add_child(UITheme.label("%s · %s · %s" % [term, String(GameState.DIFFICULTY[s.difficulty]["label"]), s.scenario.get("name", "")], 12, UITheme.MUTED))
	tv.add_child(UITheme.bold(Personas.name_of(s), 12, UITheme.ACCENT))
	h.add_child(tv)
	_box.add_child(h)
	_box.add_child(NextSteps.new().setup(5, false))

	var agenda := PanelContainer.new()
	agenda.add_theme_stylebox_override("panel", UITheme.box(UITheme.PANEL_2, UITheme.LINE, 8, 12))
	var av := VBoxContainer.new()
	av.add_child(UITheme.caps("Your agenda"))
	av.add_child(UITheme.wrap(UITheme.bold(Main.AGENDA_TEXT.get(s.agenda, s.agenda), 14)))
	av.add_child(UITheme.heading("Score %d" % int(s.agenda_score()), 26, UITheme.ACCENT))
	agenda.add_child(av)
	_box.add_child(agenda)

	# ---- This term's mandate
	var done := 0
	for m in s.mandates:
		if m["status"] == "done":
			done += 1
	var mh := HBoxContainer.new()
	mh.add_child(UITheme.caps("This term's mandate"))
	var msp := Control.new()
	msp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mh.add_child(msp)
	var dl := int(s.mandates[0]["deadline"]) - s.turn if not s.mandates.is_empty() else 0
	mh.add_child(UITheme.label("%d of %d met · %d months left" % [done, s.mandates.size(), maxi(dl, 0)], 11, UITheme.MUTED))
	_box.add_child(mh)
	for m in s.mandates:
		_box.add_child(_mandate_card(s, m))

	# ---- Why approval is moving
	var target := Simulation.approval_target(s)
	var ap := PanelContainer.new()
	ap.add_theme_stylebox_override("panel", UITheme.box(UITheme.PANEL_2, UITheme.LINE, 8, 10))
	var apv := VBoxContainer.new()
	apv.add_theme_constant_override("separation", 2)
	var aph := HBoxContainer.new()
	aph.add_child(UITheme.caps("Approval is heading toward"))
	var asp := Control.new()
	asp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aph.add_child(asp)
	aph.add_child(UITheme.heading("%d%%" % int(target), 20, UITheme.GOOD if target >= 50.0 else UITheme.BAD))
	apv.add_child(aph)
	for f in Simulation.approval_factors(s):
		if f[0] != "Baseline" and absf(float(f[1])) < 0.5:
			continue
		var r := HBoxContainer.new()
		var l := UITheme.label(String(f[0]), 12, UITheme.MUTED)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var v := float(f[1])
		var txt := "%d" % int(round(v)) if f[0] == "Baseline" else "%+d" % int(round(v))
		r.add_child(UITheme.bold(txt, 12, UITheme.TEXT if f[0] == "Baseline" else (UITheme.GOOD if v > 0.0 else UITheme.BAD)))
		apv.add_child(r)
	ap.add_child(apv)
	_box.add_child(ap)
	_box.add_child(_power_section(s))

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
			["Troop deployments", str(s.us["troops"].size())], ["Friendly share of world GDP", "%d%%" % int(s.friendly_gdp_share())],
			["Defence pacts", str(_pacts(s))], ["Credibility of US guarantees", str(int(s.us.get("credibility", 70)))]]:
		facts.add_child(UITheme.label(pair[0], 13, UITheme.MUTED))
		facts.add_child(UITheme.bold(pair[1], 13))
	_box.add_child(facts)


## Executive power: the tyranny meter and the moves that raise or lower it.
func _power_section(s: GameState) -> Control:
	var t := Power.tyranny(s)
	var col := UITheme.GOOD.lerp(UITheme.BAD, clampf(t / 70.0, 0.0, 1.0))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(Color(0.12, 0.04, 0.05, 0.55) if t >= 30.0 else UITheme.PANEL_2, Color(col, 0.5), 8, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var h := HBoxContainer.new()
	h.add_child(UITheme.caps("Executive power"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(UITheme.bold("TYRANNY %d" % int(t), 12, col))
	v.add_child(h)
	v.add_child(UITheme.bar(t, 100.0, col, 6))
	var status: Array = []
	if Power.emergency(s):
		status.append("Emergency rule: %d months left" % (int(s.us["emergency_until"]) - s.turn))
	if s.us.get("press_muzzled", false):
		status.append("Press muzzled")
	if s.us.get("courts_packed", false):
		status.append("Courts packed")
	if int(s.us.get("protests", 0)) > 0:
		status.append("Protests in the streets")
	if s.us.get("rigged", false):
		status.append("Election rigged")
	var loyal := s.advisors.filter(func(a): return a.get("loyalist", false)).size()
	if loyal > 0:
		status.append("%d loyalist%s in the cabinet" % [loyal, "s" if loyal > 1 else ""])
	var note := "The constitution holds. Every move below raises tyranny: it drags approval and world standing, cools democracies, and invites protests, impeachment, coups and assassins." if status.is_empty() else " · ".join(status)
	v.add_child(UITheme.wrap(UITheme.label(note, 11, UITheme.MUTED if status.is_empty() else Color(0.96, 0.6, 0.52))))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for id in Power.ORDER:
		var check := Power.available(s, id)
		# Only show moves that could ever apply now: hide election moves far from an election, etc.
		if not check["ok"] and id in ["crackdown", "rig", "postpone", "third_term"] and not _near(s, id):
			continue
		var b := Button.new()
		b.text = "%s  ·  %d PC" % [Power.DEFS[id]["label"], Power.pc_cost(s, id)]
		b.tooltip_text = String(Power.DEFS[id]["desc"]) + ("" if check["ok"] else "\n\n⛔ " + String(check["reason"]))
		b.disabled = not check["ok"]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 12)
		var bc := UITheme.GOOD if id == "liberalise" else UITheme.BAD
		b.add_theme_stylebox_override("normal", UITheme.box(Color(bc, 0.08), Color(bc, 0.4), 6, 7))
		b.add_theme_stylebox_override("hover", UITheme.box(Color(bc, 0.2), bc, 6, 7))
		b.add_theme_stylebox_override("disabled", UITheme.box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.06), 6, 7))
		b.pressed.connect(func():
			Audio.sfx("stamp")
			Game.power_move(id))
		grid.add_child(b)
	v.add_child(grid)
	p.add_child(v)
	return p


func _near(s: GameState, id: String) -> bool:
	match id:
		"crackdown":
			return int(s.us.get("protests", 0)) > 0
		"rig", "postpone":
			return s.elections_enabled and not s.us.get("third_term", false) and Power.months_to_election(s) <= 9
		"third_term":
			return s.elections_won >= 1 and s.end_turn - s.turn <= 18 and not s.us.get("third_term", false)
	return true


func _pacts(s: GameState) -> int:
	var n := 0
	for iso in s.active_isos():
		if s.countries[iso].get("pact", false):
			n += 1
	return n


func _mandate_card(s: GameState, m: Dictionary) -> Control:
	var st: String = m["status"]
	var col := UITheme.GOOD if st == "done" else (UITheme.BAD if st == "failed" else UITheme.ACCENT)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(Color(col, 0.08), Color(col, 0.45), 8, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var h := HBoxContainer.new()
	h.add_child(UITheme.icon_rect("score" if st != "failed" else "war", 14, col))
	var tl := UITheme.bold(String(m["title"]), 14, UITheme.TEXT)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tl)
	var hold := String(m["kind"]) in ["protect", "deficit"]
	var badge: String = {"done": "MET", "failed": "MISSED"}.get(st, ("ON TRACK" if Mandates.progress(s, m) >= 1.0 else "AT RISK") if hold else "%d%%" % int(Mandates.progress(s, m) * 100.0))
	h.add_child(UITheme.bold(badge, 11, col))
	v.add_child(h)
	v.add_child(UITheme.wrap(UITheme.label(String(m["desc"]), 12, UITheme.MUTED)))
	if st == "active" and not hold:
		v.add_child(UITheme.bar(Mandates.progress(s, m) * 100.0, 100.0, col, 6))
	if m.has("iso"):
		var go := UITheme.button("Show %s" % s.c(m["iso"]).get("name", ""))
		go.pressed.connect(Game.select.bind(String(m["iso"])))
		v.add_child(go)
	p.add_child(v)
	return p

