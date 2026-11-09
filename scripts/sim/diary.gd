class_name Diary
extends RefCounted
## The President's diary: each month a handful of dated engagements drawn from the state of the
## world, and time for only some of them. They cost time (slots), not political capital, and each
## resolves on the spot with a small effect, roughly a third the size of a paid action.
##
## State lives in s.us["diary"] = {turn, slots, items: [{kind, iso, day, title, text, slots, w, done, result}]}
## so it is saved with the game. Deterministic: only s.rng is used.

const SLOTS := 3
const OFFERED := 6
const WEEKDAYS := ["Sat", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri"]
const TOWNS := ["Ohio", "Michigan", "Arizona", "Georgia", "Pennsylvania", "Wisconsin", "Iowa", "Nevada", "North Carolina", "New Hampshire"]
const ICONS := {"call": "diplomacy", "dinner": "diplomacy", "intel": "covert", "hill": "congress", "townhall": "approval",
	"troops": "military", "advisor": "congress", "press": "scandal", "review": "score", "purse": "economic",
	"un": "standing", "rest": "pc"}


static func state(s: GameState) -> Dictionary:
	return s.us.get("diary", {"turn": -1, "slots": 0, "items": []})


static func items(s: GameState) -> Array:
	return state(s).get("items", [])


static func slots_left(s: GameState) -> int:
	return int(state(s).get("slots", 0))


static func slots_used(s: GameState) -> int:
	var n := 0
	for it in items(s):
		if it.get("done", false):
			n += int(it["slots"])
	return n


static func weekday(year: int, month: int, day: int) -> String:
	# Zeller's congruence; 0 = Saturday.
	var m := month
	var y := year
	if m < 3:
		m += 12
		y -= 1
	var k := y % 100
	var j := y / 100
	return WEEKDAYS[(day + (13 * (m + 1)) / 5 + k + k / 4 + j / 4 + 5 * j) % 7]


## Draw this month's diary. Called once at the start of every month (and of the game).
static func roll(s: GameState, map_data: Dictionary) -> void:
	if s.game_over:
		return
	var prev := state(s)
	if int(prev.get("turn", -1)) == s.turn:
		return
	# Time you did not use is not wasted: a quiet week buys a little goodwill on the Hill.
	if int(prev.get("turn", -1)) >= 0 and int(prev.get("slots", 0)) > 0:
		s.us["political_capital"] = clampf(float(s.us["political_capital"]) + float(prev["slots"]), 0.0, 100.0)
	var cands := _candidates(s, map_data)
	for c in cands:
		c["w"] = float(c["w"]) + s.rng.randf() * 3.0
	cands.sort_custom(func(a, b): return float(a["w"]) > float(b["w"]))
	var picked: Array = []
	var kinds := {}
	var isos := {}
	for c in cands:
		if picked.size() >= OFFERED:
			break
		var kind := String(c["kind"])
		var cap := 2 if kind == "call" else 1
		if int(kinds.get(kind, 0)) >= cap:
			continue
		if c["iso"] != "" and isos.has(c["iso"]):
			continue
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		if c["iso"] != "":
			isos[c["iso"]] = true
		picked.append(c)
	var days: Array = []
	while days.size() < picked.size():
		var dd := s.rng.randi_range(2, 27)
		if not days.has(dd):
			days.append(dd)
	days.sort()
	# Keep the cabinet's order of importance (w) but lay the items out by date.
	for i in picked.size():
		picked[i]["day"] = days[i]
		picked[i]["wd"] = weekday(s.year, s.month, int(days[i]))
		picked[i]["done"] = false
		picked[i]["result"] = ""
	s.us["diary"] = {"turn": s.turn, "slots": SLOTS, "items": picked}


static func _candidates(s: GameState, map_data: Dictionary) -> Array:
	var out: Array = []
	var u := s.us
	# ---- Calls: mandate countries, courted friends, friends at war, then anyone persuadable.
	var called := {}
	for m in s.mandates:
		var iso := String(m.get("iso", ""))
		if m.get("status", "") == "active" and iso != "" and s.is_active(iso) and String(m["kind"]) in ["flip", "protect", "freedom", "hunger", "end_war"] and float(s.c(iso)["relation"]) > -60.0:
			called[iso] = 9.0
	for iso in s.active_isos():
		var d := s.c(iso)
		if float(d.get("rival_pull", 0.0)) >= 15.0 and float(d["relation"]) > -20.0:
			called[iso] = maxf(float(called.get(iso, 0.0)), 8.0)
		elif s.at_war(iso) and float(d["relation"]) > 30.0:
			called[iso] = maxf(float(called.get(iso, 0.0)), 7.0)
	var pool: Array = []
	for iso in s.active_isos():
		var r := float(s.c(iso)["relation"])
		if r > -35.0 and r < 60.0 and float(s.c(iso)["pop"]) > 4.0 and not called.has(iso):
			pool.append(iso)
	for i in 2:
		if not pool.is_empty():
			var pick: String = pool[s.rng.randi_range(0, pool.size() - 1)]
			called[pick] = 3.5
	for iso in called:
		var nm := String(s.c(iso)["name"])
		out.append(_c("call", iso, float(called[iso]), 1, "Call the leader of %s" % nm, "Twenty minutes on the phone. Relations improve a little; rivals lose ground."))
	# ---- A state dinner for a friend worth keeping.
	var guest := ""
	var guest_score := -1.0
	for iso in s.active_isos():
		var d := s.c(iso)
		var r := float(d["relation"])
		if r >= 15.0 and r < 70.0 and float(d["gdp"]) > 30.0:
			var sc := float(d["gdp"]) * 0.001 + float(d.get("rival_pull", 0.0)) + s.rng.randf() * 20.0
			if sc > guest_score:
				guest_score = sc
				guest = iso
	if guest != "":
		out.append(_c("dinner", guest, 5.0, 2, "State dinner for %s" % s.c(guest)["name"], "Takes two slots. A real lift in relations, and the world notices."))
	# ---- Intelligence deep-dive on the country you can see least clearly.
	var murky := ""
	var murk := -1.0
	for iso in s.active_isos():
		var d := s.c(iso)
		if int(d.get("intel_until", -1)) > s.turn:
			continue
		var sc := (-float(d["relation"])) * 0.3 + float(d["ambition"]) * 0.4 + float(d["military"]) * 0.2 + (30.0 if s.at_war(iso) else 0.0)
		if float(d["relation"]) < 20.0 and sc > murk:
			murk = sc
			murky = iso
	if murky != "":
		out.append(_c("intel", murky, 5.5, 1, "CIA deep-dive on %s" % s.c(murky)["name"], "Clears the fog on their figures for six months."))
	# ---- The home front.
	out.append(_c("hill", "", 4.0 + (3.0 if float(u["congress"]) < 45.0 else 0.0), 1, "Work the Hill", "Lunch with the congressional leadership. Congress support rises."))
	var town: String = TOWNS[s.rng.randi_range(0, TOWNS.size() - 1)]
	out.append(_c("townhall", "", 4.0 + (3.0 if float(u["approval"]) < 48.0 else 0.0), 1, "Town hall in %s" % town, "Take questions from voters. A small lift in approval."))
	out.append(_c("press", "", 3.0 + (4.0 if float(u["scandal"]) > 20.0 else 0.0), 1, "Press conference", "Clears the air if it goes well. One time in five it does not."))
	if not u["troops"].is_empty() or not u.get("ops", []).is_empty():
		out.append(_c("troops", "", 4.5, 1, "Visit the troops", "A day with the forces. Steadies the public mood and the Pentagon."))
	# ---- An advisor who is drifting away.
	var low: Dictionary = {}
	for a in s.advisors:
		if int(a.get("vacant_months", 0)) == 0 and (low.is_empty() or float(a["trust"]) < float(low["trust"])):
			low = a
	if not low.is_empty() and float(low["trust"]) < 62.0:
		var it := _c("advisor", "", 4.0 + (62.0 - float(low["trust"])) * 0.15, 1, "One-to-one with the %s" % low["title"], "Hear them out. Trust recovers.")
		it["adv"] = low["id"]
		out.append(it)
	# ---- Look in on a running operation.
	var ops: Array = u.get("ops", [])
	if not ops.is_empty():
		var op: Dictionary = ops[s.rng.randi_range(0, ops.size() - 1)]
		var it2 := _c("review", String(op["iso"]), 6.0, 1, "Review: %s in %s" % [String(Actions.OP_NAMES[op["type"]]).to_lower(), s.c(op["iso"])["name"]], "An hour in the Situation Room. The operation does more this month.")
		it2["op"] = op["type"]
		out.append(it2)
	# ---- Money.
	out.append(_c("purse", "", 3.0 + (3.0 if _poorest_pool(s)[1] < 1.0 * s.cost_scale() else 0.0), 1, "Lunch with the appropriators", "Shake loose a little money for your leanest fund."))
	if s.month == 9:
		out.append(_c("un", "", 6.0, 2, "Address the UN General Assembly", "Takes two slots. World standing rises."))
	out.append(_c("rest", "", 1.5, 1, "A weekend at Camp David", "Rest, think, and make a few quiet calls. A little political capital."))
	return out


static func _poorest_pool(s: GameState) -> Array:
	var best := "aid"
	var low := 1e9
	for k in ["aid", "covert", "defense"]:
		if float(s.us["funds"][k]) < low:
			low = float(s.us["funds"][k])
			best = k
	return [best, low]


static func _c(kind: String, iso: String, w: float, slots: int, title: String, text: String) -> Dictionary:
	return {"kind": kind, "iso": iso, "w": w, "slots": slots, "title": title, "text": text}


static func available(s: GameState, index: int) -> Dictionary:
	var its := items(s)
	if index < 0 or index >= its.size():
		return {"ok": false, "reason": "Not in the diary."}
	var it: Dictionary = its[index]
	if it.get("done", false):
		return {"ok": false, "reason": "Already done."}
	if int(it["slots"]) > slots_left(s):
		return {"ok": false, "reason": "No time left this month." if slots_left(s) == 0 else "Needs %d slots; you have %d." % [int(it["slots"]), slots_left(s)]}
	if it["iso"] != "" and not s.is_active(it["iso"]):
		return {"ok": false, "reason": "No longer possible."}
	return {"ok": true, "reason": ""}


## Keep an engagement. Returns the one-line result. Assumes available() passed.
static func attend(s: GameState, index: int, map_data: Dictionary) -> String:
	var st := state(s)
	var it: Dictionary = st["items"][index]
	var iso := String(it["iso"])
	var d := s.c(iso)
	var nm := String(d.get("name", ""))
	var u := s.us
	var msg := ""
	match String(it["kind"]):
		"call":
			var gain := s.rng.randf_range(3.0, 5.0) * (1.0 - float(d["ambition"]) / 200.0)
			d["relation"] = clampf(float(d["relation"]) + gain, -100.0, 100.0)
			d["rival_pull"] = maxf(0.0, float(d.get("rival_pull", 0.0)) - 4.0)
			msg = "Call with %s: relations %+d." % [nm, int(round(gain))]
		"dinner":
			d["relation"] = clampf(float(d["relation"]) + 8.0, -100.0, 100.0)
			d["rival_pull"] = maxf(0.0, float(d.get("rival_pull", 0.0)) - 6.0)
			u["standing"] = clampf(float(u.get("standing", 50.0)) + 1.0, 0.0, 100.0)
			msg = "State dinner for %s: relations +8, standing +1." % nm
		"intel":
			d["intel_until"] = s.turn + 6
			Advisors.adjust(s, "cia", 1.0)
			msg = "Deep-dive on %s: clear figures for six months." % nm
		"hill":
			u["congress"] = clampf(float(u["congress"]) + 2.0, 0.0, 100.0)
			msg = "Lunch on the Hill: Congress +2."
		"townhall":
			u["approval"] = clampf(float(u["approval"]) + 0.6, 0.0, 100.0)
			u["mood"] = float(u["mood"]) + 0.3
			msg = "%s: a good night with the voters. Approval up a little." % String(it["title"])
		"press":
			if s.rng.randf() < 0.8:
				if float(u["scandal"]) >= 3.0:
					u["scandal"] = maxf(0.0, float(u["scandal"]) - 4.0)
					msg = "Press conference goes well: scandal −4."
				else:
					u["approval"] = clampf(float(u["approval"]) + 0.6, 0.0, 100.0)
					msg = "Press conference goes well: approval up a little."
			else:
				u["approval"] = clampf(float(u["approval"]) - 1.5, 0.0, 100.0)
				msg = "A hostile question dominates the news: approval −1."
		"troops":
			u["mood"] = float(u["mood"]) + 0.8
			Advisors.adjust(s, "defense", 2.0)
			msg = "Visit to the troops: public mood up, Defense trust +2."
		"advisor":
			var id := String(it.get("adv", "chief"))
			Advisors.adjust(s, id, 6.0)
			msg = "One-to-one with the %s: trust +6." % String(s.advisor(id).get("title", id))
		"review":
			msg = _review(s, iso, String(it.get("op", "")))
		"purse":
			var pool: String = _poorest_pool(s)[0]
			var amt := 0.6 * s.cost_scale()
			u["funds"][pool] = float(u["funds"][pool]) + amt
			msg = "Appropriators find $%.1fbn for %s." % [amt, {"aid": "foreign aid", "covert": "intelligence", "defense": "defense"}[pool]]
		"un":
			u["standing"] = clampf(float(u.get("standing", 50.0)) + 3.0, 0.0, 100.0)
			msg = "Speech to the General Assembly: standing +3."
		"rest":
			u["political_capital"] = clampf(float(u["political_capital"]) + 3.0, 0.0, 100.0)
			msg = "Camp David: political capital +3."
	it["done"] = true
	it["result"] = msg
	st["slots"] = int(st["slots"]) - int(it["slots"])
	s.stats["diary"] = int(s.stats.get("diary", 0)) + 1
	s.add_log(msg, "diary", iso, int(it["day"]))
	if iso != "":
		s.fx.append({"iso": iso, "kind": "aid" if it["kind"] == "review" and it.get("op", "") == "aid" else "envoy", "text": String(it["title"]).split(":")[0]})
	return msg


static func _review(s: GameState, iso: String, type: String) -> String:
	var op := Actions.op_for(s, iso, type)
	var d := s.c(iso)
	var nm := String(d.get("name", ""))
	if op.is_empty():
		return "The operation in %s has already ended." % nm
	match type:
		"influence":
			d["relation"] = clampf(float(d["relation"]) + 2.0, -100.0, 100.0)
			return "Charm offensive in %s sharpened: relations +2." % nm
		"aid":
			d["hunger"] = clampf(float(d["hunger"]) - 2.0, 0.0, 100.0)
			return "Aid programme in %s unblocked: hunger −2." % nm
		"support":
			d["military"] = clampf(float(d["military"]) + 1.0, 0.0, 100.0)
			return "War support for %s speeded up: military +1." % nm
		"air":
			d["military"] = clampf(float(d["military"]) - 2.0, 0.0, 100.0)
			return "Air campaign over %s retargeted: their military −2." % nm
		"invade":
			op["progress"] = float(op["progress"]) + 4.0
			return "Invasion of %s: the generals get what they asked for. Progress +4." % nm
		"covert":
			d["covert_pressure"] = float(d["covert_pressure"]) + 3.0
			return "Covert campaign in %s tightened." % nm
	return "Reviewed."


## For bots and tests: keep the most important engagements until time runs out.
static func auto(s: GameState, map_data: Dictionary) -> int:
	var its := items(s)
	var order: Array = []
	for i in its.size():
		order.append(i)
	order.sort_custom(func(a, b): return float(its[a]["w"]) > float(its[b]["w"]))
	var done := 0
	for i in order:
		if available(s, i)["ok"]:
			attend(s, i, map_data)
			done += 1
	return done
