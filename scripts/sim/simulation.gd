class_name Simulation
extends RefCounted
## The monthly tick. Fixed order, seeded RNG: same seed + same inputs = same game.

const WAR_DETERRENCE := 40.0   # strength US troops add to a side


static func clamp100(v: float) -> float:
	return clampf(v, 0.0, 100.0)


static func tick(s: GameState, map_data: Dictionary, events: Array) -> void:
	if s.game_over:
		return
	_us_funds(s)
	_ops(s)
	for iso in s.active_isos():
		_country(s, iso)
	_wars(s, map_data)
	_new_wars(s, map_data)
	_rivals(s, map_data)
	_us_politics(s)
	Advisors.monthly(s)
	_endings(s)
	if s.game_over:
		return
	# Advance the calendar.
	s.turn += 1
	s.month += 1
	if s.month > 12:
		s.month = 1
		s.year += 1
	_elections(s)
	if s.game_over:
		return
	Events.check(s, events, map_data)
	s.score = s.agenda_score()
	s.record_history()


static func _us_funds(s: GameState) -> void:
	var b: Dictionary = s.us["budget"]
	var f: Dictionary = s.us["funds"]
	f["aid"] = float(f["aid"]) + float(b["aid"]) / 12.0 * 0.6
	f["covert"] = float(f["covert"]) + float(b["intel"]) / 12.0 * 0.25
	f["defense"] = float(f["defense"]) + float(b["defense"]) / 12.0 * 0.02
	f["domestic"] = float(f["domestic"]) + float(b["domestic"]) / 12.0 * 0.01
	# Troop upkeep.
	var upkeep := 0.25 * s.cost_scale() * float(s.us["troops"].size())
	f["defense"] = float(f["defense"]) - upkeep
	for k in f:
		f[k] = minf(float(f[k]), 60.0 * s.cost_scale())


static func _country(s: GameState, iso: String) -> void:
	var d: Dictionary = s.countries[iso]
	var war := s.at_war(iso)
	var cw: bool = d.get("civil_war", false)
	var troops: bool = s.us["troops"].has(iso)
	var growth := float(d["growth"]) + (float(d["stability"]) - 50.0) * 0.04
	if d["sanctioned"]:
		growth -= 3.0
	if war:
		growth -= 4.0
	if cw:
		growth -= 3.0
	if d["trade_deal"]:
		growth += 0.8
	growth += float(d["aid_boost"]) * 0.1
	d["gdp"] = maxf(0.05, float(d["gdp"]) * (1.0 + growth / 1200.0))
	# Base growth reverts toward trend: poorer economies can catch up faster.
	var gdppc := float(d["gdp"]) * 1000.0 / maxf(float(d["pop"]), 0.01)
	var trend := 2.0 + (1.5 if gdppc < 5000.0 else 0.0)
	d["growth"] = float(d["growth"]) + (trend - float(d["growth"])) * 0.02
	var pop_growth := 0.6 + float(d["hunger"]) * 0.02 - (0.5 if war else 0.0)
	d["pop"] = float(d["pop"]) * (1.0 + pop_growth / 1200.0)

	var pc := maxf(float(d["gdp"]) * 1000.0 / maxf(float(d["pop"]), 0.01), 50.0)
	var hunger_target := clampf(130.0 - 30.0 * log(pc) / log(10.0), 0.0, 95.0)
	if war:
		hunger_target += 12.0
	if cw:
		hunger_target += 15.0
	hunger_target -= float(d["aid_boost"])
	d["hunger"] = clamp100(float(d["hunger"]) + (hunger_target - float(d["hunger"])) * 0.04)

	var stab := float(d["stability"])
	var delta := (50.0 - float(d["hunger"])) * 0.03 + growth * 0.15 + (60.0 - stab) * 0.01
	delta += float(d["aid_boost"]) * 0.05 - float(d["covert_pressure"]) * 0.05
	if war:
		delta -= 1.5
	if cw:
		delta -= 2.0
	if troops:
		delta += 0.3
	delta += s.rng.randf_range(-1.2, 1.2)
	d["stability"] = clamp100(stab + delta)
	d["covert_pressure"] = float(d["covert_pressure"]) * 0.9
	d["rival_pull"] = float(d.get("rival_pull", 0.0)) * 0.97
	d["aid_boost"] = float(d["aid_boost"]) * 0.85

	var mil := float(d["military"]) + (float(d["ambition"]) - 40.0) * 0.01
	if d["sanctioned"]:
		mil -= 0.1
	if war:
		mil -= 0.4
	d["military"] = clamp100(mil)

	var amb_target := 15.0 if float(d["freedom"]) > 70.0 else 40.0
	d["ambition"] = clamp100(float(d["ambition"]) + (amb_target - float(d["ambition"])) * 0.01 + s.rng.randf_range(-0.5, 0.5))
	if float(d["stability"]) > 60.0 and float(d["freedom"]) > 50.0:
		d["freedom"] = clamp100(float(d["freedom"]) + 0.05)

	var bloc: Dictionary = s.scenario["blocs"].get(d["bloc"], {})
	var base_rel := float(bloc.get("baseline", 0.0))
	var rel := float(d["relation"]) + (base_rel - float(d["relation"])) * 0.015
	if d["sanctioned"]:
		rel -= 0.5
	if d["trade_deal"]:
		rel += 0.3
	if troops:
		rel += 0.2
	d["relation"] = clampf(rel, -100.0, 100.0)
	_bloc_shift(s, iso)

	if not cw and float(d["stability"]) < 12.0 and s.rng.randf() < 0.1:
		d["civil_war"] = true
		s.add_log("Civil war breaks out in %s." % d["name"], "headline")
	elif cw and float(d["stability"]) > 45.0:
		d["civil_war"] = false
		s.add_log("The civil war in %s winds down." % d["name"], "headline")
	if float(d["stability"]) < 15.0 and s.rng.randf() < (0.02 if cw else 0.06):
		regime_change(s, iso, false)


static func _is_bloc_leader(s: GameState, iso: String) -> bool:
	for b in s.scenario["blocs"].values():
		if b.get("leader", "") == iso:
			return true
	return false


static func _bloc_shift(s: GameState, iso: String) -> void:
	var d: Dictionary = s.countries[iso]
	if _is_bloc_leader(s, iso):
		return
	if float(d["relation"]) > 65.0 and d["bloc"] != "west":
		d["bloc"] = "west"
		s.add_log("%s moves into the Western camp." % d["name"], "headline")
	elif float(d["relation"]) < -45.0 and d["bloc"] == "west":
		d["bloc"] = "nonaligned"
		s.add_log("%s breaks with the West." % d["name"], "headline")


static func regime_change(s: GameState, iso: String, us_backed: bool) -> void:
	var d: Dictionary = s.countries[iso]
	d["covert_pressure"] = 0.0
	var was_cw: bool = d.get("civil_war", false)
	if us_backed:
		d["civil_war"] = false
	d["ambition"] = s.rng.randf_range(20.0, 70.0)
	if us_backed:
		d["stability"] = 35.0
		d["relation"] = 55.0
		d["freedom"] = clamp100(float(d["freedom"]) + s.rng.randf_range(-15.0, 10.0))
		if not _is_bloc_leader(s, iso):
			d["bloc"] = "west"
		d["us_backed"] = true
		s.add_log("New US-friendly government in %s." % d["name"], "headline")
	else:
		d["stability"] = 30.0
		d["relation"] = s.rng.randf_range(-40.0, 20.0)
		d["freedom"] = clamp100(float(d["freedom"]) + s.rng.randf_range(-20.0, 15.0))
		d["us_backed"] = false
		if was_cw:
			s.add_log("A rival faction seizes the capital of %s." % d["name"], "headline")
		else:
			s.add_log("Coup in %s: the military seizes power." % d["name"], "headline")


static func _strength(s: GameState, iso: String) -> float:
	var d := s.c(iso)
	var st := float(d["military"]) * (0.5 + float(d["stability"]) / 100.0)
	if s.us["troops"].has(iso):
		st += WAR_DETERRENCE
	if not Actions.op_for(s, iso, "support").is_empty():
		st += 22.0
	return st


static func _wars(s: GameState, map_data: Dictionary) -> void:
	for w in s.wars.duplicate():
		if not s.is_active(w["a"]) or not s.is_active(w["b"]):
			s.wars.erase(w)
			continue
		var a_str := _strength(s, w["a"])
		var b_str := _strength(s, w["b"]) * 1.15
		w["progress"] = float(w["progress"]) + (a_str - b_str) * 0.25 + s.rng.randf_range(-6.0, 6.0)
		w["months"] = int(w["months"]) + 1
		for side in [w["a"], w["b"]]:
			if s.us["troops"].has(side):
				s.us["mood"] = float(s.us["mood"]) - 0.4
		var a := s.c(w["a"])
		var b := s.c(w["b"])
		if float(w["progress"]) >= 100.0:
			var b_ally := float(b["relation"]) > 50.0
			var had_troops: bool = s.us["troops"].has(w["b"])
			end_war(s, w, "%s defeats %s and installs a client government." % [a["name"], b["name"]])
			b["bloc"] = a["bloc"]
			b["relation"] = float(a["relation"]) * 0.5
			b["stability"] = 25.0
			b["freedom"] = clamp100(float(b["freedom"]) - 20.0)
			a["ambition"] = clamp100(float(a["ambition"]) + 5.0)
			if had_troops:
				s.us["troops"].erase(w["b"])
				s.us["approval"] = float(s.us["approval"]) - 8.0
			elif b_ally:
				s.us["approval"] = float(s.us["approval"]) - 4.0
		elif float(w["progress"]) <= -100.0:
			var helped: bool = s.us["troops"].has(w["b"])
			end_war(s, w, "%s repels the invasion by %s." % [b["name"], a["name"]])
			a["stability"] = clamp100(float(a["stability"]) - 20.0)
			a["ambition"] = clamp100(float(a["ambition"]) - 25.0)
			if helped:
				s.us["approval"] = float(s.us["approval"]) + 6.0
		elif int(w["months"]) > 48 and s.rng.randf() < 0.15:
			end_war(s, w, "Exhausted, %s and %s agree to a ceasefire." % [a["name"], b["name"]])


static func _new_wars(s: GameState, map_data: Dictionary) -> void:
	for iso in s.active_isos():
		var d: Dictionary = s.countries[iso]
		if float(d["ambition"]) < 62.0 or float(d["stability"]) < 30.0 or d["nuclear"] or d["civil_war"] or s.at_war(iso):
			continue
		if s.rng.randf() >= (float(d["ambition"]) - 60.0) * 0.0004:
			continue
		var best := ""
		var best_mil := 1e9
		for n in s.neighbors_of(iso, map_data):
			if not s.is_active(n) or s.at_war(n):
				continue
			var nd := s.c(n)
			if nd["bloc"] == d["bloc"] or nd["nuclear"]:
				continue
			if s.us["troops"].has(n) and float(d["ambition"]) < 90.0:
				continue
			if float(nd["military"]) < float(d["military"]) * 0.9 and float(nd["military"]) < best_mil:
				best = n
				best_mil = float(nd["military"])
		if best != "":
			start_war(s, iso, best, 0.0)


## Ongoing operations: pay upkeep, apply monthly effects, finish or halt.
static func _ops(s: GameState) -> void:
	if not s.us.has("ops"):
		s.us["ops"] = []
	for op in s.us["ops"].duplicate():
		var iso: String = op["iso"]
		var type: String = op["type"]
		var nm := String(Actions.OP_NAMES.get(type, type))
		if not s.is_active(iso):
			s.us["ops"].erase(op)
			continue
		var d := s.c(iso)
		var up: Array = Actions.OP_UPKEEP[type]
		var pc := float(up[0])
		var pool: String = up[1]
		var cost := float(up[2]) * s.cost_scale()
		if float(s.us["political_capital"]) < pc or (pool != "" and float(s.us["funds"][pool]) < cost):
			s.us["ops"].erase(op)
			var why := "political capital" if float(s.us["political_capital"]) < pc else "%s funds" % pool
			s.add_log("%s in %s halted: out of %s." % [nm, d["name"], why], "cabinet")
			s.fx.append({"iso": iso, "kind": "halt", "text": "%s halted" % nm})
			if type == "invade":
				s.us["approval"] = float(s.us["approval"]) - 4.0
			continue
		s.us["political_capital"] = float(s.us["political_capital"]) - pc
		if pool != "":
			s.us["funds"][pool] = float(s.us["funds"][pool]) - cost
		op["months"] = int(op["months"]) + 1
		match type:
			"influence":
				d["relation"] = clampf(float(d["relation"]) + 3.0 * (1.0 - float(d["ambition"]) / 200.0), -100.0, 100.0)
				d["rival_pull"] = maxf(0.0, float(d.get("rival_pull", 0.0)) - 6.0)
			"aid":
				var impact := cost / maxf(float(d["gdp"]), 0.1) * 100.0
				var eff := 0.5 if float(d["freedom"]) < 30.0 else 1.0
				d["hunger"] = clamp100(float(d["hunger"]) - minf(8.0, impact * 3.0) * eff)
				d["aid_boost"] = float(d["aid_boost"]) + minf(5.0, impact * 1.5) * eff
				d["relation"] = clampf(float(d["relation"]) + 1.5 + minf(3.0, impact * 0.5), -100.0, 100.0)
				s.us["standing"] = clamp100(float(s.us.get("standing", 50.0)) + 0.3)
			"support":
				if not s.at_war(iso):
					s.us["ops"].erase(op)
					s.add_log("The war in %s is over; US support winds down." % d["name"], "action")
					continue
				d["relation"] = clampf(float(d["relation"]) + 1.5, -100.0, 100.0)
				d["military"] = clamp100(float(d["military"]) + 0.8)
			"air":
				var provoked := Actions.strike_provoked(s, iso)
				d["military"] = clamp100(float(d["military"]) - 4.0)
				d["stability"] = clamp100(float(d["stability"]) - 3.0)
				d["terror"] = clamp100(float(d["terror"]) - 4.0)
				d["relation"] = clampf(float(d["relation"]) - 4.0, -100.0, 100.0)
				var w := s.war_for(iso)
				if not w.is_empty():
					w["progress"] = float(w["progress"]) + (-6.0 if w["a"] == iso else 6.0)
				if not provoked:
					s.us["scandal"] = float(s.us["scandal"]) + 4.0
					s.us["standing"] = clamp100(float(s.us.get("standing", 50.0)) - 2.0)
				s.us["mood"] = float(s.us["mood"]) - 0.2
				s.fx.append({"iso": iso, "kind": "strike", "text": ""})
				if d.get("nuclear", false) and s.rng.randf() < 0.01:
					trigger_ending(s, "nuclear", "%s answered the air campaign with a nuclear weapon." % d["name"])
					return
			"invade":
				var defence := Actions.invasion_defence(s, iso)
				op["progress"] = float(op["progress"]) + maxf(2.0, (110.0 - defence) * 0.18) + s.rng.randf_range(-3.0, 3.0)
				d["military"] = clamp100(float(d["military"]) - 3.0)
				d["stability"] = clamp100(float(d["stability"]) - 4.0)
				s.us["mood"] = float(s.us["mood"]) - (0.6 if int(op["months"]) <= 12 else 1.2)
				s.fx.append({"iso": iso, "kind": "strike", "text": ""})
				if float(op["progress"]) >= 100.0:
					s.us["ops"].erase(op)
					var w2 := s.war_for(iso)
					if not w2.is_empty():
						end_war(s, w2, "The war involving %s ends with the US invasion." % d["name"])
					regime_change(s, iso, true)
					d["stability"] = 25.0
					s.us["approval"] = float(s.us["approval"]) + (6.0 if int(op["months"]) <= 8 else 2.0)
					s.add_log("VICTORY: US forces take the capital of %s after %d months." % [d["name"], int(op["months"])], "headline")
					s.fx.append({"iso": iso, "kind": "victory", "text": "Victory"})
			"covert":
				d["stability"] = clamp100(float(d["stability"]) - 3.0)
				d["covert_pressure"] = float(d["covert_pressure"]) + 6.0
				if Actions._expose(s, iso, 6.0, 10.0, "covert campaign"):
					s.us["ops"].erase(op)


## Rival bloc leaders (China, Russia, the USSR) court countries with loans, arms and aid.
static func _rivals(s: GameState, map_data: Dictionary) -> void:
	for bloc_id in s.scenario["blocs"]:
		if bloc_id == "west" or bloc_id == "nonaligned":
			continue
		var leader: String = s.scenario["blocs"][bloc_id].get("leader", "")
		if leader == "" or not s.is_active(leader):
			continue
		var ld := s.c(leader)
		var aggr := s.diff("rival") * clampf(float(ld["ambition"]) / 70.0, 0.4, 1.4)
		var bloc: Dictionary = s.scenario["blocs"][bloc_id]
		var target: String = bloc.get("focus", "")
		if target == "" or not _courtable(s, target, bloc_id):
			target = ""
			var pool: Array = s.neighbors_of(leader, map_data) if s.rng.randf() < 0.5 else []
			if pool.is_empty():
				pool = s.active_isos()
			var candidates: Array = []
			for iso in pool:
				if _courtable(s, iso, bloc_id):
					candidates.append(iso)
			if candidates.is_empty():
				continue
			target = candidates[s.rng.randi_range(0, candidates.size() - 1)]
			bloc["focus"] = target
		if s.rng.randf() > 0.7:
			continue
		var td := s.c(target)
		if td.get("rival_bloc", "") != bloc_id:
			td["rival_bloc"] = bloc_id
			td["rival_pull"] = 0.0
		var before := float(td["rival_pull"])
		td["rival_pull"] = before + 6.0 * aggr
		td["relation"] = clampf(float(td["relation"]) - 1.5 * aggr, -100.0, 100.0)
		if float(td["hunger"]) > 40.0:
			td["hunger"] = clamp100(float(td["hunger"]) - 2.0)
		if before < 20.0 and float(td["rival_pull"]) >= 20.0:
			s.add_log("%s is courting %s with loans and arms." % [ld["name"], td["name"]], "headline")
		if float(td["rival_pull"]) >= 40.0 and float(td["relation"]) < 10.0:
			td["bloc"] = bloc_id
			td["rival_pull"] = 0.0
			bloc["focus"] = ""
			td["relation"] = clampf(float(td["relation"]) - 10.0, -100.0, 100.0)
			s.add_log("%s signs a strategic partnership with %s." % [td["name"], ld["name"]], "headline")


static func _courtable(s: GameState, iso: String, bloc_id: String) -> bool:
	if not s.is_active(iso) or _is_bloc_leader(s, iso) or s.us["troops"].has(iso):
		return false
	var d := s.c(iso)
	if d["bloc"] == "west" and float(d["freedom"]) >= 70.0:
		return false
	return d["bloc"] != bloc_id and float(d["relation"]) <= 45.0


static func start_war(s: GameState, a: String, b: String, progress: float) -> void:
	if not s.is_active(a) or not s.is_active(b) or s.at_war(a) or s.at_war(b):
		return
	s.wars.append({"a": a, "b": b, "progress": progress, "months": 0})
	s.add_log("WAR: %s invades %s." % [s.c(a)["name"], s.c(b)["name"]], "war")


static func end_war(s: GameState, w: Dictionary, text: String) -> void:
	s.wars.erase(w)
	s.add_log(text, "headline")


static func budget_deficit_pct(s: GameState) -> float:
	var b: Dictionary = s.us["budget"]
	var base: Dictionary = s.us["budget_baseline"]
	var extra := 0.0
	for k in b:
		extra += float(b[k]) - float(base[k])
	return float(s.us["deficit_pct_baseline"]) + extra / float(s.us["gdp"]) * 100.0


static func approval_target(s: GameState) -> float:
	var b: Dictionary = s.us["budget"]
	var base: Dictionary = s.us["budget_baseline"]
	var dom_ratio := float(b["domestic"]) / maxf(float(base["domestic"]), 1.0)
	var t := 48.0 + (dom_ratio - 1.0) * 35.0 - float(s.turn) * 0.03
	t -= maxf(0.0, budget_deficit_pct(s) - 4.0) * 2.5
	t -= float(s.us["scandal"]) * 0.25
	t += float(s.us["mood"])
	t += s.diff("approval")
	t += (float(s.us.get("standing", 50.0)) - 50.0) * 0.05
	return clampf(t, 5.0, 90.0)


static func _us_politics(s: GameState) -> void:
	var u: Dictionary = s.us
	var appr := float(u["approval"])
	appr += (approval_target(s) - appr) * 0.08 + s.rng.randf_range(-1.0, 1.0)
	u["approval"] = clamp100(appr)
	u["mood"] = float(u["mood"]) * 0.9
	u["congress"] = clamp100(float(u["congress"]) + (appr - float(u["congress"])) * 0.05)
	var regen := (5.0 + (appr - 50.0) * 0.08 + (float(u["congress"]) - 50.0) * 0.04) * s.diff("pc")
	u["political_capital"] = clamp100(float(u["political_capital"]) + regen)
	u["standing"] = clamp100(float(u.get("standing", 50.0)) + (55.0 - float(u.get("standing", 50.0))) * 0.02)
	u["scandal"] = maxf(0.0, float(u["scandal"]) - 1.0)
	u["gdp"] = float(u["gdp"]) * (1.0 + 2.2 / 1200.0)
	if s.wars.is_empty():
		u["peace_months"] = int(u["peace_months"]) + 1


static func _endings(s: GameState) -> void:
	var u: Dictionary = s.us
	if float(u["scandal"]) >= 100.0:
		if float(u["congress"]) < 40.0:
			trigger_ending(s, "impeached", "Congress impeached and removed you after the scandals piled up.")
			return
		u["scandal"] = 70.0
		u["approval"] = float(u["approval"]) - 8.0
		s.add_log("You survive impeachment hearings, badly bruised.", "scandal")
	var recent := 0
	for t in s.resignations:
		if s.turn - int(t) < 12:
			recent += 1
	if recent >= 4:
		trigger_ending(s, "cabinet", "Four cabinet resignations in a year. Your party forced you out.")
		return
	# Assassination risk from hostile, terror-sponsoring states.
	var risk := 0.0
	for iso in s.active_isos():
		var d: Dictionary = s.countries[iso]
		if float(d["terror"]) > 60.0 and float(d["relation"]) < -30.0:
			risk += (float(d["terror"]) - 60.0) * 0.002
	risk *= (1.3 - Advisors.intel_accuracy(s) / 100.0) * s.diff("risk")
	if s.rng.randf() * 100.0 < risk:
		if s.rng.randf() < 0.3:
			trigger_ending(s, "assassinated", "You were killed in an attack by a foreign-backed cell.")
			return
		u["approval"] = float(u["approval"]) + 6.0
		s.add_log("You survive an assassination attempt. The country rallies.", "headline")
	# Nuclear escalation: a nuclear power facing defeat at US-backed hands.
	for w in s.wars:
		var loser := ""
		if float(w["progress"]) > 80.0:
			loser = w["b"]
		elif float(w["progress"]) < -80.0:
			loser = w["a"]
		if loser == "":
			continue
		var winner: String = w["a"] if loser == w["b"] else w["b"]
		if s.c(loser).get("nuclear", false) and s.us["troops"].has(winner) and s.rng.randf() < 0.15:
			trigger_ending(s, "nuclear", "Facing defeat, %s used nuclear weapons against US forces." % s.c(loser)["name"])
			return


static func _elections(s: GameState) -> void:
	if s.turn == s.next_election_turn - 24 and s.elections_enabled:
		var swing := (float(s.us["approval"]) - 50.0) * 0.8 - 4.0
		s.us["congress"] = clamp100(float(s.us["congress"]) + swing)
		var verdict := "Your party gains seats" if swing > 0.0 else "Your party loses seats"
		s.add_log("MIDTERMS: %s. Congress support now %d%%." % [verdict, int(s.us["congress"])], "headline")
	if s.turn < s.next_election_turn:
		return
	if s.turn >= s.end_turn:
		trigger_ending(s, "retired", "Your second term is over. You leave office with %d%% approval." % int(s.us["approval"]))
		return
	s.next_election_turn += 48
	if not s.elections_enabled:
		return
	var vote := float(s.us["approval"]) + 3.0 - s.diff("challenger") + s.rng.randf_range(-4.0, 4.0)
	s.last_election = {"vote": vote, "won": vote >= 50.0, "turn": s.turn}
	if vote < 50.0:
		trigger_ending(s, "defeated", "You lost the election with %.1f%% of the vote." % vote)
		return
	s.elections_won += 1
	s.add_log("ELECTION: you win re-election with %.1f%% of the vote." % vote, "headline")
	s.pending.append({"id": "election_review", "title": "Election night: you win", "ctx": "",
		"text": "With %.1f%% of the vote, you have a second term. The panel's verdict on your first: approval %d%%, %d treaties, %d active wars, agenda score %d." % [vote, int(s.us["approval"]), int(s.us["treaties"]), s.wars.size(), int(s.agenda_score())],
		"choices": [{"label": "Begin the second term", "effects": [], "advisors": {}}]})


static func trigger_ending(s: GameState, kind: String, text: String) -> void:
	s.game_over = true
	s.ending = kind
	s.ending_text = text
	s.score = s.agenda_score()
	s.add_log("GAME OVER: " + text, "headline")
