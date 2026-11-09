class_name Mandates
extends RefCounted
## Term mandates: three concrete goals per term, drawn from the live world state.
## Completing one pays out approval, political capital and legacy points.

const REWARD_APPROVAL := 3.0
const REWARD_PC := 15.0


static func roll(s: GameState, map_data: Dictionary) -> void:
	## Pick three fresh mandates for the term that ends at s.next_election_turn (or end_turn).
	var deadline := s.next_election_turn if s.next_election_turn <= s.end_turn else s.end_turn
	var pool: Array = []
	var isos := s.active_isos()
	# End a war.
	for w in s.wars:
		pool.append({"kind": "end_war", "iso": w["b"], "title": "End the war in %s" % s.c(w["b"])["name"],
			"desc": "No war involving %s by the deadline." % s.c(w["b"])["name"]})
	# Feed the hungriest large country.
	var hungry := _top(s, isos, func(d): return float(d["hunger"]) if float(d["pop"]) > 5.0 else -1.0)
	if hungry != "" and float(s.c(hungry)["hunger"]) > 35.0:
		var target := maxf(5.0, float(s.c(hungry)["hunger"]) - 15.0)
		pool.append({"kind": "hunger", "iso": hungry, "target": target, "start": float(s.c(hungry)["hunger"]),
			"title": "Feed %s" % s.c(hungry)["name"], "desc": "Cut hunger in %s to %d or below." % [s.c(hungry)["name"], int(target)]})
	# Win back a country from a rival bloc.
	var flip := ""
	for iso in isos:
		var d := s.c(iso)
		if d["bloc"] not in ["west", "nonaligned"] and not _is_leader(s, iso) and not d["nuclear"] and float(d["relation"]) > -60.0:
			if flip == "" or float(d["relation"]) > float(s.c(flip)["relation"]):
				flip = iso
	if flip != "":
		pool.append({"kind": "flip", "iso": flip, "title": "Win over %s" % s.c(flip)["name"],
			"desc": "Bring %s's relations with the US to 40 or more." % s.c(flip)["name"]})
	# Grow the circle of friends.
	var friends := _count(s, func(d): return float(d["relation"]) >= 60.0)
	pool.append({"kind": "allies", "target": friends + 4, "start": friends, "title": "Widen the circle",
		"desc": "Have %d countries with relations of 60 or more." % (friends + 4)})
	# Approval and standing.
	var appr_t := clampf(maxf(55.0, float(s.us["approval"]) + 8.0), 55.0, 72.0)
	if float(s.us["approval"]) < appr_t:
		pool.append({"kind": "approval", "target": appr_t, "start": float(s.us["approval"]), "title": "Win the country over",
			"desc": "Reach %d%% approval." % int(appr_t)})
	var stand_t := clampf(maxf(75.0, float(s.us.get("standing", 50.0)) + 10.0), 75.0, 90.0)
	if float(s.us.get("standing", 50.0)) < stand_t:
		pool.append({"kind": "standing", "target": stand_t, "start": float(s.us.get("standing", 50.0)), "title": "Restore America's standing",
			"desc": "Raise world standing to %d." % int(stand_t)})
	pool.append({"kind": "treaties", "target": int(s.us["treaties"]) + 2, "start": int(s.us["treaties"]), "title": "Peacemaker in chief",
		"desc": "Sign two peace deals or treaties this term."})
	# Raise freedom in the least free large country that isn't hostile.
	var closed := _top(s, isos, func(d): return 100.0 - float(d["freedom"]) if float(d["pop"]) > 10.0 and float(d["relation"]) > -50.0 else -1.0)
	if closed != "":
		var tgt := float(s.c(closed)["freedom"]) + 15.0
		pool.append({"kind": "freedom", "iso": closed, "target": tgt, "start": float(s.c(closed)["freedom"]),
			"title": "Open up %s" % s.c(closed)["name"], "desc": "Raise freedom in %s to %d." % [s.c(closed)["name"], int(tgt)]})
	# Defuse a terror haven.
	var haven := _top(s, isos, func(d): return float(d["terror"]))
	if haven != "" and float(s.c(haven)["terror"]) > 50.0:
		pool.append({"kind": "terror", "iso": haven, "target": 30.0, "start": float(s.c(haven)["terror"]),
			"title": "Shut down the havens in %s" % s.c(haven)["name"], "desc": "Cut %s's terror ties to 30 or below." % s.c(haven)["name"]})
	# Protect a threatened friend.
	for iso in isos:
		var d := s.c(iso)
		if float(d["relation"]) >= 50.0:
			for n in s.neighbors_of(iso, map_data):
				var nd := s.c(n)
				if not nd.is_empty() and s.is_active(n) and float(nd["ambition"]) > 60.0 and float(nd["military"]) > float(d["military"]):
					pool.append({"kind": "protect", "iso": iso, "threat": n, "title": "Keep %s safe" % d["name"],
						"desc": "%s must not fall to %s or any invader this term." % [d["name"], nd["name"]]})
					break
	# Fiscal discipline.
	pool.append({"kind": "deficit", "target": float(s.us["deficit_pct_baseline"]) - 0.5, "title": "Balance the books",
		"desc": "Be at or under %.1f%% deficit when the term ends." % (float(s.us["deficit_pct_baseline"]) - 0.5)})

	# Three distinct picks, agenda-flavoured: favour kinds that suit the agenda.
	var favour := {"peacemaker": ["end_war", "treaties", "protect"], "humanitarian": ["hunger", "freedom", "standing"],
		"democratiser": ["freedom", "flip", "standing"], "hegemon": ["flip", "allies", "protect"], "strongman": ["approval", "flip", "allies"]}
	var fav: Array = favour.get(s.agenda, [])
	var picked: Array = []
	var kinds_used := {}
	for pass_i in 2:
		var shuffled := pool.duplicate()
		for i in range(shuffled.size() - 1, 0, -1):
			var j := s.rng.randi_range(0, i)
			var tmp = shuffled[i]
			shuffled[i] = shuffled[j]
			shuffled[j] = tmp
		for m in shuffled:
			if picked.size() >= 3:
				break
			if kinds_used.has(m["kind"]):
				continue
			if pass_i == 0 and not fav.has(m["kind"]):
				continue
			kinds_used[m["kind"]] = true
			picked.append(m)
	for m in picked:
		m["status"] = "active"
		m["deadline"] = deadline
		m["term"] = s.elections_won + 1
	s.mandates = picked
	s.add_log("Your mandate for this term: %s." % ", ".join(picked.map(func(m): return String(m["title"]))), "cabinet")


static func progress(s: GameState, m: Dictionary) -> float:
	match String(m["kind"]):
		"end_war":
			return 0.0 if s.at_war(m["iso"]) else 1.0
		"hunger", "terror":
			var cur := float(s.c(m["iso"]).get(m["kind"], 100.0))
			return clampf((float(m["start"]) - cur) / maxf(float(m["start"]) - float(m["target"]), 1.0), 0.0, 1.0)
		"freedom":
			var f := float(s.c(m["iso"]).get("freedom", 0.0))
			return clampf((f - float(m["start"])) / maxf(float(m["target"]) - float(m["start"]), 1.0), 0.0, 1.0)
		"flip":
			return clampf((float(s.c(m["iso"]).get("relation", -100.0)) + 60.0) / 100.0, 0.0, 1.0)
		"allies":
			var n := _count(s, func(d): return float(d["relation"]) >= 60.0)
			return clampf(float(n - int(m["start"])) / maxf(float(m["target"]) - float(m["start"]), 1.0), 0.0, 1.0)
		"approval":
			return clampf((float(s.us["approval"]) - float(m["start"])) / maxf(float(m["target"]) - float(m["start"]), 1.0), 0.0, 1.0)
		"standing":
			return clampf((float(s.us.get("standing", 50.0)) - float(m["start"])) / maxf(float(m["target"]) - float(m["start"]), 1.0), 0.0, 1.0)
		"treaties":
			return clampf(float(int(s.us["treaties"]) - int(m["start"])) / 2.0, 0.0, 1.0)
		"protect":
			return 1.0 if float(s.c(m["iso"]).get("relation", 0.0)) > 0.0 and s.c(m["iso"]).get("bloc", "") != s.c(m["threat"]).get("bloc", "x") else 0.0
		"deficit":
			return 1.0 if Simulation.budget_deficit_pct(s) <= float(m["target"]) else 0.0
	return 0.0


static func _met(s: GameState, m: Dictionary) -> bool:
	match String(m["kind"]):
		"end_war":
			return not s.at_war(m["iso"])
		"hunger":
			return float(s.c(m["iso"]).get("hunger", 100.0)) <= float(m["target"])
		"terror":
			return float(s.c(m["iso"]).get("terror", 100.0)) <= float(m["target"])
		"freedom":
			return float(s.c(m["iso"]).get("freedom", 0.0)) >= float(m["target"])
		"flip":
			return float(s.c(m["iso"]).get("relation", -100.0)) >= 40.0
		"allies":
			return _count(s, func(d): return float(d["relation"]) >= 60.0) >= int(m["target"])
		"approval":
			return float(s.us["approval"]) >= float(m["target"])
		"standing":
			return float(s.us.get("standing", 50.0)) >= float(m["target"])
		"treaties":
			return int(s.us["treaties"]) >= int(m["target"])
	return false


## Monthly: pay out completed mandates; settle "hold until the deadline" ones at the deadline.
static func update(s: GameState) -> void:
	for m in s.mandates:
		if m["status"] != "active":
			continue
		var hold := String(m["kind"]) in ["protect", "deficit"]
		if not hold and _met(s, m):
			_complete(s, m)
		elif hold and String(m["kind"]) == "protect" and progress(s, m) < 1.0:
			_fail(s, m)
		elif s.turn >= int(m["deadline"]):
			if hold and progress(s, m) >= 1.0:
				_complete(s, m)
			else:
				_fail(s, m)


static func _complete(s: GameState, m: Dictionary) -> void:
	m["status"] = "done"
	s.us["approval"] = clampf(float(s.us["approval"]) + REWARD_APPROVAL, 0.0, 100.0)
	s.us["political_capital"] = clampf(float(s.us["political_capital"]) + REWARD_PC, 0.0, 100.0)
	s.stats["mandates_done"] = int(s.stats.get("mandates_done", 0)) + 1
	s.add_log("MANDATE MET: %s. Approval +%d, political capital +%d." % [m["title"], int(REWARD_APPROVAL), int(REWARD_PC)], "headline")
	s.fx.append({"iso": m.get("iso", "USA"), "kind": "victory", "text": "Mandate met"})


static func _fail(s: GameState, m: Dictionary) -> void:
	m["status"] = "failed"
	s.us["approval"] = clampf(float(s.us["approval"]) - 1.0, 0.0, 100.0)
	s.add_log("Mandate missed: %s." % m["title"], "cabinet")


static func _top(s: GameState, isos: Array, score: Callable) -> String:
	var best := ""
	var best_v := -1.0
	for iso in isos:
		var v := float(score.call(s.c(iso)))
		if v > best_v:
			best_v = v
			best = iso
	return best if best_v >= 0.0 else ""


static func _count(s: GameState, pred: Callable) -> int:
	var n := 0
	for iso in s.active_isos():
		if pred.call(s.c(iso)):
			n += 1
	return n


static func _is_leader(s: GameState, iso: String) -> bool:
	for b in s.scenario["blocs"].values():
		if b.get("leader", "") == iso:
			return true
	return false
