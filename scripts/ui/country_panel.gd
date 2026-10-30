class_name CountryPanel
extends ScrollContainer
## Selected-country dossier: stats (through the intel fog), status, actions, advisor advice.

const STATS := [
	["stability", "Stability", false],
	["freedom", "Freedom", false],
	["hunger", "Hunger", true],
	["military", "Military", false],
	["ambition", "Ambition", true],
	["terror", "Terror ties", true],
]

var _box: VBoxContainer


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)
	Game.selection_changed.connect(func(_iso): refresh())
	Game.state_changed.connect(refresh)
	refresh()


static func fog(s: GameState, iso: String, stat: String) -> float:
	## Display noise from imperfect intelligence. Deterministic per turn so it doesn't flicker.
	var d := s.c(iso)
	var acc := Advisors.intel_accuracy(s)
	var amp := (100.0 - acc) * 0.15
	if float(d.get("relation", 0.0)) > 50.0:
		amp *= 0.4
	var h := hash("%s|%s|%d|%d" % [iso, stat, s.turn, s.rng_seed])
	var unit := float(absi(h) % 2001) / 1000.0 - 1.0
	return amp * unit


static func fog_amp(s: GameState, iso: String) -> int:
	var amp := (100.0 - Advisors.intel_accuracy(s)) * 0.15
	if float(s.c(iso).get("relation", 0.0)) > 50.0:
		amp *= 0.4
	return int(round(amp))


const CAT_ICONS := {"Diplomacy": "diplomacy", "Economic": "economic", "Military": "military", "Covert": "covert"}
const CAT_COLORS := {"Diplomacy": Color(0.45, 0.68, 0.95), "Economic": Color(0.42, 0.78, 0.52), "Military": Color(0.92, 0.5, 0.36), "Covert": Color(0.68, 0.55, 0.92)}
const OP_ICONS := {"influence": "diplomacy", "aid": "economic", "support": "military", "air": "war", "invade": "war", "covert": "covert"}


## Draws one country's outline, scaled to fit. Used as the dossier's header art.
class Silhouette extends Control:
	var iso := ""
	var color := Color.WHITE

	func _draw() -> void:
		var polys: Array = []
		var rect := Rect2()
		var first := true
		for map_iso in Game.map_data["countries"]:
			if Game.state.map_owner.get(map_iso, "") != iso:
				continue
			for ring in Game.map_data["countries"][map_iso]["rings"]:
				var pts := PackedVector2Array()
				for i in range(0, ring.size(), 2):
					pts.append(Vector2(float(ring[i]), float(ring[i + 1])))
				polys.append(pts)
				var r := Rect2(pts[0], Vector2.ZERO)
				for p in pts:
					r = r.expand(p)
				rect = r if first else rect.merge(r)
				first = false
		if polys.is_empty() or rect.size.x <= 0.0:
			return
		# Keep the main landmass and nearby islands (drops Alaska, Chukotka, overseas bits).
		var biggest: PackedVector2Array = polys[0]
		var big_area := 0.0
		for pts in polys:
			var r := Rect2(pts[0], Vector2.ZERO)
			for p in pts:
				r = r.expand(p)
			if r.get_area() > big_area:
				big_area = r.get_area()
				biggest = pts
		var core := Rect2(biggest[0], Vector2.ZERO)
		for p in biggest:
			core = core.expand(p)
		var zone := core.grow(maxf(core.size.x, core.size.y) * 0.35)
		var kept: Array = []
		rect = core
		for pts in polys:
			var r := Rect2(pts[0], Vector2.ZERO)
			for p in pts:
				r = r.expand(p)
			if zone.intersects(r):
				kept.append(pts)
				rect = rect.merge(r)
		polys = kept
		# Very spread-out countries (Russia, USA with Alaska) keep their largest piece in view.
		var sc := minf((size.x - 12.0) / maxf(rect.size.x, 1.0), (size.y - 12.0) / maxf(rect.size.y, 1.0))
		var off := (size - rect.size * sc) * 0.5 - rect.position * sc
		for pts in polys:
			var tp := PackedVector2Array()
			for p in pts:
				tp.append(p * sc + off)
			var idx := Geometry2D.triangulate_polygon(tp)
			if idx.size() >= 3:
				var cols := PackedColorArray()
				cols.resize(tp.size())
				cols.fill(Color(color, 0.85))
				RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, tp, cols)
			var closed := tp.duplicate()
			closed.append(tp[0])
			draw_polyline(closed, Color(color.lightened(0.4), 0.9), 1.2, true)


func refresh() -> void:
	var scroll_before := scroll_vertical
	UITheme.clear(_box)
	if not Game.has_game():
		return
	var s := Game.state
	var iso := Game.selected
	if iso == "" or s.c(iso).is_empty():
		_empty_state(s)
		return
	var d := s.c(iso)
	var active: bool = s.is_active(iso) and not d.get("player", false)
	var bc: Color = WorldMap.BLOC_COLORS.get(d["bloc"], Color.GRAY)
	if d.get("player", false):
		bc = UITheme.ACCENT

	# ---- Header card: silhouette, name, bloc, flags
	var hdr := PanelContainer.new()
	var hsb := UITheme.box(bc.darkened(0.72), Color(bc, 0.55), 10, 12)
	hdr.add_theme_stylebox_override("panel", hsb)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 12)
	var sil := Silhouette.new()
	sil.iso = iso
	sil.color = bc
	sil.custom_minimum_size = Vector2(110, 84)
	hh.add_child(sil)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 2)
	var name_l := UITheme.heading(String(d["name"]), 28)
	UITheme.wrap(name_l)
	hv.add_child(name_l)
	var sub := String(d.get("region", ""))
	if active:
		sub += "  ·  " + String(s.scenario["blocs"].get(d["bloc"], {}).get("name", d["bloc"]))
	hv.add_child(UITheme.label(sub, 12, Color(1, 1, 1, 0.65)))
	var tags: Array = []
	if d.get("nuclear", false):
		tags.append(["Nuclear power", UITheme.WARN])
	if d.get("sanctioned", false):
		tags.append(["Under US sanctions", UITheme.BAD])
	if d.get("trade_deal", false):
		tags.append(["US trade deal", UITheme.GOOD])
	if s.us["troops"].has(iso):
		tags.append(["US troops present", UITheme.ACCENT])
	if d.get("civil_war", false):
		tags.append(["Civil war", UITheme.BAD])
	if float(d.get("rival_pull", 0.0)) >= 10.0:
		var rb: String = String(s.scenario["blocs"].get(d.get("rival_bloc", ""), {}).get("name", "rival"))
		tags.append(["Courted by %s (%d/40)" % [rb, int(d["rival_pull"])], UITheme.WARN])
	if not tags.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 5)
		flow.add_theme_constant_override("v_separation", 5)
		for tg in tags:
			var l := UITheme.bold(tg[0], 10, tg[1])
			l.add_theme_stylebox_override("normal", UITheme.box(Color(tg[1], 0.14), Color(tg[1], 0.5), 9, 4))
			flow.add_child(l)
		hv.add_child(flow)
	hh.add_child(hv)
	hdr.add_child(hh)
	_box.add_child(hdr)

	if d.get("player", false):
		_box.add_child(UITheme.wrap(UITheme.label("This is you. Run the home front from the Oval Office, Budget and Cabinet tabs.", 13, UITheme.MUTED)))
		return
	if not s.is_active(iso):
		_box.add_child(UITheme.wrap(UITheme.label("Not an independent state in this period.", 13, UITheme.MUTED)))
		return

	# ---- War banner
	if s.at_war(iso):
		var w := s.war_for(iso)
		var other := s.enemy_of(iso)
		var role := "Invading" if w["a"] == iso else "Defending against"
		var prog := float(w["progress"]) if w["a"] == iso else -float(w["progress"])
		var wp := PanelContainer.new()
		wp.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.BAD, 0.12), Color(UITheme.BAD, 0.6), 8, 10))
		var wv := VBoxContainer.new()
		var wh := HBoxContainer.new()
		wh.add_child(UITheme.icon_rect("war", 16, UITheme.BAD))
		wh.add_child(UITheme.bold("AT WAR · %s %s · month %d" % [role, s.c(other)["name"], int(w["months"])], 13, UITheme.BAD))
		wv.add_child(wh)
		var hb := HBoxContainer.new()
		hb.add_child(UITheme.label("Losing", 11, UITheme.MUTED))
		hb.add_child(UITheme.bar(prog + 100.0, 200.0, UITheme.GOOD if prog >= 0.0 else UITheme.BAD, 10))
		hb.add_child(UITheme.label("Winning", 11, UITheme.MUTED))
		wv.add_child(hb)
		wp.add_child(wv)
		_box.add_child(wp)

	# ---- Operations in progress
	var ops := Actions.ops_for(s, iso)
	if not ops.is_empty():
		_box.add_child(UITheme.caps("Operations in progress"))
		for op in ops:
			_box.add_child(_op_row(s, iso, op))

	# ---- Stats
	var rel := float(d["relation"])
	_box.add_child(_stat_row("Relations with US", rel + 100.0, 200.0, "%+d" % int(rel), UITheme.GOOD if rel >= 0.0 else UITheme.BAD))
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 6)
	var gdppc := float(d["gdp"]) * 1000.0 / maxf(float(d["pop"]), 0.01)
	for pair in [["Population", "%sm" % _fmt(float(d["pop"]))], ["GDP", "$%sbn" % _fmt(float(d["gdp"]))],
			["Per head", "$%s" % _fmt(gdppc)], ["Growth", "%+.1f%%" % float(d["growth"])]]:
		var tp := PanelContainer.new()
		tp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tp.add_theme_stylebox_override("panel", UITheme.box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.06), 6, 6))
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		tv.add_child(UITheme.caps(pair[0], UITheme.MUTED, 9))
		tv.add_child(UITheme.bold(pair[1], 13))
		tp.add_child(tv)
		tiles.add_child(tp)
	_box.add_child(tiles)
	var amp := fog_amp(s, iso)
	for st in STATS:
		var key: String = st[0]
		var v := clampf(float(d[key]) + fog(s, iso, key), 0.0, 100.0)
		var good_high: bool = not st[2]
		var t := v / 100.0 if good_high else 1.0 - v / 100.0
		_box.add_child(_stat_row(st[1], v, 100.0, "%d%s" % [int(v), (" ±%d" % amp) if amp >= 2 else ""], UITheme.BAD.lerp(UITheme.GOOD, t)))

	# ---- Actions
	var head := HBoxContainer.new()
	head.add_child(UITheme.caps("Your options"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UITheme.label("%d PC available" % int(s.us["political_capital"]), 11, UITheme.MUTED))
	_box.add_child(HSeparator.new())
	_box.add_child(head)
	var shown_cat := ""
	for id in Actions.ORDER:
		var def: Dictionary = Actions.DEFS[id]
		if def.has("system") and not s.has_system(def["system"]):
			continue
		if _hidden(s, iso, id):
			continue
		if def["cat"] != shown_cat:
			shown_cat = def["cat"]
			var ch := HBoxContainer.new()
			ch.add_child(UITheme.icon_rect(CAT_ICONS.get(def["cat"], "score"), 13, CAT_COLORS[def["cat"]]))
			ch.add_child(UITheme.bold(def["cat"].to_upper(), 10, CAT_COLORS[def["cat"]]))
			_box.add_child(ch)
		_box.add_child(_action_row(s, iso, id))

	# ---- Advice
	_box.add_child(HSeparator.new())
	_box.add_child(UITheme.caps("Cabinet advice"))
	for a in Advisors.advise(s, iso, Game.map_data):
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UITheme.box(UITheme.PANEL_2, UITheme.LINE, 8, 8))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var pr := UITheme.portrait_rect(String(a["name"]), 44)
		pr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(pr)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 1)
		v.add_child(UITheme.label("%s · %s" % [a["title"], a["name"]], 11, UITheme.MUTED))
		v.add_child(UITheme.wrap(UITheme.label(String(a["text"]), 13)))
		if a["action"] != "" and Actions.DEFS.has(a["action"]):
			v.add_child(UITheme.bold("Recommends: " + String(Actions.DEFS[a["action"]]["label"]), 11, UITheme.ACCENT))
		row.add_child(v)
		pc.add_child(row)
		_box.add_child(pc)
	await get_tree().process_frame
	scroll_vertical = scroll_before


## Options that make no sense right now are hidden rather than greyed out.
func _hidden(s: GameState, iso: String, id: String) -> bool:
	var d := s.c(iso)
	match id:
		"lift_sanction":
			return not d.get("sanctioned", false)
		"sanction":
			return d.get("sanctioned", false)
		"withdraw":
			return not s.us["troops"].has(iso)
		"deploy":
			return s.us["troops"].has(iso)
		"peace":
			return not s.at_war(iso) and not d.get("civil_war", false)
		"op_support":
			return not s.at_war(iso)
		"trade":
			return d.get("trade_deal", false)
	if Actions.DEFS[id].has("op") and not Actions.op_for(s, iso, Actions.DEFS[id]["op"]).is_empty():
		return true
	return false


func _action_row(s: GameState, iso: String, id: String) -> Control:
	var def: Dictionary = Actions.DEFS[id]
	var check := Actions.available(s, iso, id)
	var ok: bool = check["ok"]
	var col: Color = CAT_COLORS[def["cat"]]
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := UITheme.box(UITheme.PANEL_2, Color(col, 0.3), 7, 9)
	var hover := UITheme.box(UITheme.PANEL_2.lerp(col, 0.14), col, 7, 9)
	var off := UITheme.box(Color(0.06, 0.08, 0.12), Color(1, 1, 1, 0.05), 7, 9)
	card.add_theme_stylebox_override("panel", normal if ok else off)
	card.tooltip_text = String(def["desc"])
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if ok else Control.CURSOR_FORBIDDEN
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UITheme.bold(String(def["label"]), 13, UITheme.TEXT if ok else UITheme.MUTED)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(t)
	if def.has("op"):
		var ong := UITheme.bold("ONGOING", 8, col)
		ong.add_theme_stylebox_override("normal", UITheme.box(Color(col, 0.15), Color(col, 0.5), 6, 3))
		ong.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ong.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_row.add_child(ong)
	v.add_child(title_row)
	var sub := String(def["desc"]) if ok else ("⛔ " + String(check["reason"]))
	var sl := UITheme.label(sub, 11, UITheme.MUTED if ok else Color(0.96, 0.6, 0.52))
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.custom_minimum_size.x = 280
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sl)
	row.add_child(v)
	var chips := VBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override("separation", 3)
	chips.custom_minimum_size.x = 68
	if int(def["pc"]) > 0:
		chips.add_child(_chip("%d PC" % int(def["pc"]), UITheme.ACCENT))
	if def["pool"] != "":
		chips.add_child(_chip("$%.1fbn" % Actions.cost_of(s, id), UITheme.GOOD))
	if float(check["chance"]) >= 0.0:
		var c := float(check["chance"])
		var lbl := "%d%%" % int(c)
		if id in ["strike", "deploy", "op_air", "op_invade"]:
			lbl = "Vote %d%%" % int(c)
		chips.add_child(_chip(lbl, UITheme.GOOD if c >= 60.0 else (UITheme.WARN if c >= 35.0 else UITheme.BAD)))
	row.add_child(chips)
	card.add_child(row)
	if ok:
		card.mouse_entered.connect(func():
			card.add_theme_stylebox_override("panel", hover)
			Audio.sfx("hover", -16.0))
		card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", normal))
		card.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				Audio.sfx("click")
				Game.do_action(id))
	return card


func _chip(text: String, color: Color) -> Label:
	var l := UITheme.bold(text, 10, color)
	l.add_theme_stylebox_override("normal", UITheme.box(Color(color, 0.12), Color(color, 0.45), 6, 4))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _op_row(s: GameState, iso: String, op: Dictionary) -> Control:
	var type: String = op["type"]
	var p := PanelContainer.new()
	var col := UITheme.BAD if type in ["air", "invade"] else (UITheme.GOOD if type in ["aid", "influence", "support"] else Color(0.68, 0.55, 0.92))
	p.add_theme_stylebox_override("panel", UITheme.box(Color(col, 0.1), Color(col, 0.55), 8, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(UITheme.icon_rect(OP_ICONS.get(type, "score"), 18, col))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	v.add_child(UITheme.bold("%s · month %d" % [Actions.OP_NAMES[type], int(op["months"])], 13, col))
	var up: Array = Actions.OP_UPKEEP[type]
	var cost_bits: Array = []
	if float(up[0]) > 0.0:
		cost_bits.append("%d PC" % int(up[0]))
	if up[1] != "":
		cost_bits.append("$%.1fbn %s" % [float(up[2]) * s.cost_scale(), up[1]])
	v.add_child(UITheme.label("Upkeep per month: " + ", ".join(cost_bits), 11, UITheme.MUTED))
	if type == "invade":
		var pb := HBoxContainer.new()
		pb.add_child(UITheme.label("Capital", 10, UITheme.MUTED))
		pb.add_child(UITheme.bar(float(op["progress"]), 100.0, UITheme.ACCENT, 8))
		pb.add_child(UITheme.bold("%d%%" % int(op["progress"]), 10))
		v.add_child(pb)
	h.add_child(v)
	var stop := UITheme.button("Withdraw" if type == "invade" else "Stop")
	stop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stop.pressed.connect(Game.stop_op.bind(iso, type))
	h.add_child(stop)
	p.add_child(h)
	return p


func _stat_row(label: String, value: float, max_value: float, text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UITheme.label(label, 13)
	l.custom_minimum_size.x = 132
	row.add_child(l)
	row.add_child(UITheme.bar(value, max_value, color, 9))
	var vl := UITheme.bold(text, 13)
	vl.custom_minimum_size.x = 56
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(vl)
	return row


func _empty_state(s: GameState) -> void:
	_box.add_child(UITheme.heading("The world awaits", 26))
	_box.add_child(UITheme.wrap(UITheme.label("Click any country to open its dossier: stats, your options, and what your cabinet thinks.", 14, UITheme.MUTED)))
	_box.add_child(HSeparator.new())
	_box.add_child(UITheme.caps("Hot spots"))
	var hot: Array = []
	for w in s.wars:
		hot.append([w["b"], "War: %s vs %s" % [s.c(w["a"])["name"], s.c(w["b"])["name"]], UITheme.BAD])
	for iso in s.active_isos():
		var d: Dictionary = s.countries[iso]
		if d.get("civil_war", false):
			hot.append([iso, "Civil war in %s" % d["name"], UITheme.BAD])
		elif float(d.get("rival_pull", 0.0)) >= 20.0:
			hot.append([iso, "%s is being courted by a rival" % d["name"], UITheme.WARN])
		elif float(d["hunger"]) > 65.0:
			hot.append([iso, "Hunger crisis in %s" % d["name"], UITheme.WARN])
	if hot.is_empty():
		_box.add_child(UITheme.label("All quiet. For now.", 13, UITheme.MUTED))
	for i in mini(hot.size(), 12):
		var b := UITheme.button(hot[i][1])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", hot[i][2])
		b.pressed.connect(Game.select.bind(String(hot[i][0])))
		_box.add_child(b)


static func _fmt(v: float) -> String:
	if v >= 1000.0:
		return "%s,%03d" % [int(v / 1000.0), int(v) % 1000]
	if v >= 100.0:
		return "%d" % int(v)
	if v >= 10.0:
		return "%.1f" % v
	return "%.2f" % v
