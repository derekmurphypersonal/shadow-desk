class_name Guidance
extends RefCounted
## "What should I do next?" A ranked list of concrete next steps, rebuilt every time the state
## changes. Each item: {pri, icon, title, text, iso (optional), tab (optional: "budget", "oval", "cabinet"),
## action (optional action id to highlight)}. Higher pri first.


static func suggest(s: GameState, map_data: Dictionary, limit: int = 5) -> Array:
	var out: Array = []
	if s == null or s.game_over:
		return out
	var u := s.us
	var appr := float(u["approval"])
	var pc := float(u["political_capital"])
	var to_election := s.next_election_turn - s.turn

	# ---- Live crises come first ----
	for c in Crises.list(s):
		var help := Crises.best_help(s, c)
		var left := Crises.months_left(c)
		out.append(_i(88, "war", "Crisis: %s" % c["title"], "%d month%s left; your hand is %s. %s" % [left, "" if left == 1 else "s", Crises.hand_word(c), Crises.helps_text(s, c)],
			String(help[0]) if not help.is_empty() else String(c["iso"]), "", String(help[1]) if not help.is_empty() else ""))

	# ---- Home front and budget ----
	var deficit := Simulation.budget_deficit_pct(s)
	if deficit > 5.5:
		out.append(_i(70, "deficit", "Trim the budget", "The deficit is %.1f%% of GDP and costs you %d approval. Cut defense or domestic spending a little." % [deficit, int(maxf(0.0, deficit - 4.0) * 2.5)], "", "budget"))
	var b: Dictionary = u["budget"]
	var base: Dictionary = u["budget_baseline"]
	if appr < 47.0 and float(b["domestic"]) <= float(base["domestic"]) * 1.02 and deficit < 5.5:
		out.append(_i(75, "approval", "Spend at home", "Approval is %d%%. Raising domestic spending is the surest way to win voters back." % int(appr), "", "budget"))
	var acc := Advisors.intel_accuracy(s)
	if acc < 55.0:
		out.append(_i(45, "covert", "Fix your intelligence", "Your intel is only %d%% accurate, so the numbers you see are fuzzy. Raise the intelligence budget." % int(acc), "", "budget"))
	var f: Dictionary = u["funds"]
	if float(f["aid"]) < 1.0 * s.cost_scale() and _needs_aid(s):
		out.append(_i(50, "economic", "Top up foreign aid", "Aid funds are down to $%.1fbn and countries need help. Raise the foreign aid budget." % float(f["aid"]), "", "budget"))
	if to_election > 0 and to_election <= 8 and s.elections_enabled and appr < 52.0:
		out.append(_i(90, "election", "The election is %d months away" % to_election, "Approval is %d%%; you need 50%% on the day. Spend at home, end wars, avoid scandal." % int(appr), "", "oval"))

	# ---- The mandate ----
	for m in s.mandates:
		if m.get("status", "") != "active":
			continue
		var step := _mandate_step(s, m, map_data)
		if not step.is_empty():
			out.append(step)

	# ---- Threats and opportunities ----
	for w in s.wars:
		var victim: String = w["b"]
		var vd := s.c(victim)
		if vd.is_empty() or float(vd["relation"]) < 45.0:
			continue
		if Actions.op_for(s, victim, "support").is_empty() and not u["troops"].has(victim):
			out.append(_i(80, "war", "Help %s" % vd["name"], "A friend is being invaded by %s. Back their war effort or send troops." % s.c(w["a"]).get("name", "?"), victim, "", "op_support"))
	var courted := ""
	var courted_rel := -999.0
	for iso in s.active_isos():
		var d := s.c(iso)
		if float(d.get("rival_pull", 0.0)) >= 20.0 and float(d["relation"]) > 0.0 and float(d["relation"]) > courted_rel:
			courted = iso
			courted_rel = float(d["relation"])
	if courted != "":
		var cd := s.c(courted)
		var rival := String(s.scenario["blocs"].get(cd.get("rival_bloc", ""), {}).get("leader", ""))
		out.append(_i(55, "diplomacy", "Keep %s on side" % cd["name"], "%s is courting them with loans and arms. A charm offensive or an envoy cancels it out." % s.c(rival).get("name", "A rival"), courted, "", "op_influence"))
	for iso in s.active_isos():
		var d := s.c(iso)
		if float(d["relation"]) >= 40.0 and float(d["hunger"]) > 60.0 and Actions.op_for(s, iso, "aid").is_empty():
			out.append(_i(40, "economic", "Famine in %s" % d["name"], "A friendly country is going hungry (hunger %d). An aid programme saves lives and wins hearts." % int(d["hunger"]), iso, "", "op_aid"))
			break
	for a in s.advisors:
		if float(a["trust"]) < 32.0 and int(a.get("vacant_months", 0)) == 0:
			out.append(_i(65, "congress", "%s may resign" % a["name"], "Trust is %d. Follow the %s's advice for a while. Four resignations in a year ends your presidency." % [int(a["trust"]), a["title"]], "", "cabinet"))
			break
	if float(u["scandal"]) > 60.0:
		out.append(_i(70, "scandal", "Lie low", "Scandal is %d; at 100 you face impeachment. Avoid covert operations and unprovoked strikes for a few months." % int(u["scandal"])))

	# ---- The dark path ----
	var t := Power.tyranny(s)
	if t >= 40.0 and s.agenda != "strongman":
		out.append(_i(60, "scandal", "The republic is straining", "Tyranny is %d. It drags approval and standing, and invites protests, impeachment and coups. Restoring civil liberties lowers it." % int(t), "", "oval"))
	if s.agenda == "strongman":
		var next := _next_power_move(s)
		if next != "":
			out.append(_i(58, "scandal", Power.DEFS[next]["label"], String(Power.DEFS[next]["desc"]), "", "oval"))
	if int(u.get("protests", 0)) > 0:
		out.append(_i(62, "scandal", "Protests in the streets", "They cost approval every month. Give ground or crack down from the Oval Office.", "", "oval"))

	# ---- Unused capital: concrete things worth buying with it ----
	if pc >= 45.0:
		var trade := ""
		var pact := ""
		var near := ""
		var near_gap := 999.0
		for iso in s.active_isos():
			var d := s.c(iso)
			var r := float(d["relation"])
			if r >= 20.0 and not d.get("trade_deal", false) and not d.get("sanctioned", false) and (trade == "" or float(d["gdp"]) > float(s.c(trade)["gdp"])):
				trade = iso
			if r >= 55.0 and not d.get("pact", false) and not d.get("nuclear", false) and float(d["military"]) < 45.0 and (pact == "" or float(d["gdp"]) > float(s.c(pact)["gdp"])):
				pact = iso
			for th in [20.0, 55.0]:
				if r < th and th - r <= 12.0 and th - r < near_gap and float(d["gdp"]) > 20.0:
					near_gap = th - r
					near = iso
		if trade != "" and pc >= 50.0:
			out.append(_i(36, "economic", "Trade deal with %s" % s.c(trade)["name"], "You have %d political capital. A deal lifts both economies and locks out rivals; Congress votes on it." % int(pc), trade, "", "trade"))
		if pact != "" and pc >= 60.0 and float(u.get("credibility", 70.0)) >= 30.0:
			out.append(_i(34, "military", "Defence pact with %s" % s.c(pact)["name"], "A close friend with a weak army. A pact deters attack and stops rival courtship.", pact, "", "pact"))
		if near != "":
			out.append(_i(32, "diplomacy", "Envoy to %s" % s.c(near)["name"], "Relations are %d: %d short of %s." % [int(s.c(near)["relation"]), int(ceil(near_gap)), "a trade deal" if float(s.c(near)["relation"]) < 20.0 else "a defence pact"], near, "", "envoy"))

	out.sort_custom(func(a, b): return int(a["pri"]) > int(b["pri"]))
	var seen := {}
	var final: Array = []
	for it in out:
		var k := "%s|%s" % [it["iso"], it["action"]] if it["iso"] != "" else String(it["title"])
		if seen.has(k):
			continue
		seen[k] = true
		final.append(it)
	return final.slice(0, limit)


## The same advice as map pins: only items tied to a country, one per country, most urgent first.
## Each pin: {iso, text, icon, action, tone}. Running operations are pinned too, so the map shows your work.
static func pins(s: GameState, map_data: Dictionary, limit: int = 6) -> Array:
	var out: Array = []
	var seen := {}
	for it in suggest(s, map_data, 12):
		var iso := String(it["iso"])
		if iso == "" or seen.has(iso):
			continue
		seen[iso] = true
		var title := String(it["title"])
		var tone := "accent" if title.begins_with("Mandate") else ("bad" if it["icon"] == "war" else "warn")
		out.append({"iso": iso, "text": title.replace("Mandate: ", "★ "), "icon": it["icon"], "action": it["action"], "tone": tone, "tip": it["text"]})
	return out.slice(0, limit)


static func _i(pri: int, icon: String, title: String, text: String, iso: String = "", tab: String = "", action: String = "") -> Dictionary:
	return {"pri": pri, "icon": icon, "title": title, "text": text, "iso": iso, "tab": tab, "action": action}


static func _needs_aid(s: GameState) -> bool:
	for op in s.us.get("ops", []):
		if op["type"] == "aid":
			return true
	for m in s.mandates:
		if m.get("status", "") == "active" and m["kind"] in ["hunger", "standing"]:
			return true
	return false


static func _mandate_step(s: GameState, m: Dictionary, map_data: Dictionary) -> Dictionary:
	var kind := String(m["kind"])
	var iso := String(m.get("iso", ""))
	var nm := String(s.c(iso).get("name", "")) if iso != "" else ""
	var tag := "Mandate: "
	match kind:
		"end_war":
			if s.at_war(iso):
				return _i(85, "diplomacy", tag + "broker peace in " + nm, "Peace talks have a %d%% chance right now. They improve as the war drags on and your standing rises." % int(Actions.peace_chance(s, iso)), iso, "", "peace")
		"hunger":
			if Actions.op_for(s, iso, "aid").is_empty():
				return _i(80, "economic", tag + "feed " + nm, "Start an aid programme in %s; hunger is %d and must reach %d." % [nm, int(s.c(iso)["hunger"]), int(m["target"])], iso, "", "op_aid")
		"flip":
			if Actions.op_for(s, iso, "influence").is_empty():
				return _i(78, "diplomacy", tag + "win over " + nm, "Relations are %d and need to reach 40. A charm offensive adds 3 a month; envoys add more at once." % int(s.c(iso)["relation"]), iso, "", "op_influence")
		"allies":
			var best := ""
			var best_rel := -999.0
			for c in s.active_isos():
				var r := float(s.c(c)["relation"])
				if r < 60.0 and r > best_rel:
					best = c
					best_rel = r
			if best != "":
				return _i(72, "diplomacy", tag + "envoy to " + String(s.c(best)["name"]), "They're at %d; 60 counts as a close friend. You need %d more friends." % [int(best_rel), maxi(0, int(m["target"]) - Mandates._count(s, func(d): return float(d["relation"]) >= 60.0))], best, "", "envoy")
		"approval":
			return _i(74, "approval", tag + "raise approval to %d%%" % int(m["target"]), "Domestic spending, peace deals and met mandates all lift approval; scandal and long wars sink it.", "", "budget")
		"standing":
			return _i(66, "standing", tag + "restore standing to %d" % int(m["target"]), "Aid, peace deals and UN votes raise standing; exposed covert ops and unprovoked strikes lower it.", "", "")
		"treaties":
			var target := ""
			var best_c := 0.0
			for w in s.wars:
				var c := Actions.peace_chance(s, w["b"])
				if c > best_c:
					best_c = c
					target = w["b"]
			if target != "":
				return _i(76, "diplomacy", tag + "broker peace in " + String(s.c(target)["name"]), "Best odds of any war right now: %d%%. Each deal counts as a treaty." % int(best_c), target, "", "peace")
			return _i(50, "diplomacy", tag + "sign defence pacts", "No wars to settle. Defence pacts with close friends (relations 55+) also count as treaties of a kind and deter attacks.", "", "")
		"freedom":
			return _i(64, "standing", tag + "open up " + nm, "Freedom is %d and must reach %d. Aid and trade build a middle class; covert funding of the opposition is faster but risky." % [int(s.c(iso)["freedom"]), int(m["target"])], iso, "", "op_aid")
		"terror":
			return _i(68, "war", tag + "shut down the havens in " + nm, "Terror ties are %d. Air strikes cut them fast; a covert campaign is quieter." % int(s.c(iso)["terror"]), iso, "", "strike")
		"protect":
			if not s.us["troops"].has(iso) and not s.c(iso).get("pact", false):
				return _i(70, "military", tag + "keep %s safe" % nm, "A stronger neighbour has designs on them. US troops or a defence pact are the best deterrent.", iso, "", "deploy")
		"deficit":
			if Simulation.budget_deficit_pct(s) > float(m["target"]):
				return _i(73, "deficit", tag + "balance the books", "Get the deficit to %.1f%% by the deadline (now %.1f%%)." % [float(m["target"]), Simulation.budget_deficit_pct(s)], "", "budget")
	return {}


static func _next_power_move(s: GameState) -> String:
	for id in ["press", "emergency", "courts", "purge", "rig", "third_term"]:
		if Power.available(s, id)["ok"]:
			return id
	return ""
