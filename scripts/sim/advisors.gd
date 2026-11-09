class_name Advisors
extends RefCounted
## The seven-member cabinet: portfolio, bias, trust, advice and resignations.
## All names are fictional.

const ROLES := {
	"chief": {"title": "Chief of Staff", "name": "Margaret Holloway"},
	"state": {"title": "Secretary of State", "name": "Daniel Okafor"},
	"defense": {"title": "Secretary of Defense", "name": "Ray Castellano"},
	"treasury": {"title": "Treasury Secretary", "name": "Evelyn Strand"},
	"nsa": {"title": "National Security Advisor", "name": "Victor Lindqvist"},
	"cia": {"title": "CIA Director", "name": "Ruth Abernathy"},
	"un": {"title": "UN Ambassador", "name": "Samuel Ito"},
}
const ORDER := ["chief", "state", "defense", "treasury", "nsa", "cia", "un"]
const FEMALE := ["Margaret Holloway", "Evelyn Strand", "Ruth Abernathy", "Grace Whitfield", "Hannah Cole",
	"Ingrid Sato", "Lena Kowalski", "Priya Raman", "June Halvorsen"]
## Each seat has a recorded voice; replacements are drawn to match it.
const FEMALE_SEATS := ["chief", "treasury", "cia"]
const REPLACEMENTS := ["Alan Pryce", "Grace Whitfield", "Tomas Reyes", "Hannah Cole", "Marcus Bell",
	"Ingrid Sato", "Paul Navarro", "Lena Kowalski", "Owen Marsh", "Priya Raman", "Carl Dunmore", "June Halvorsen"]

## How each action shifts each advisor's trust. Positive = they approve.
const REACTIONS := {
	"envoy": {"state": 2, "un": 1},
	"aid": {"state": 2, "un": 2, "treasury": -1},
	"trade": {"treasury": 3, "state": 1},
	"sanction": {"treasury": 1, "state": -1, "un": 1},
	"lift_sanction": {"state": 2, "nsa": -1},
	"arms": {"defense": 3, "state": -1, "un": -1},
	"deploy": {"defense": 2, "nsa": 2, "chief": -1},
	"withdraw": {"chief": 2, "defense": -2},
	"strike": {"defense": 2, "nsa": 2, "state": -3, "un": -4, "chief": -1},
	"fund_opposition": {"cia": 3, "state": -2},
	"coup": {"cia": 4, "state": -4, "un": -4},
	"assassinate": {"cia": 3, "nsa": 1, "state": -5, "un": -6, "chief": -2},
	"cyber": {"cia": 2, "nsa": 2, "state": -1},
	"peace": {"state": 4, "un": 4, "chief": 1},
	"pact": {"state": 3, "defense": 2, "nsa": 2},
	"end_pact": {"state": -4, "defense": -3, "nsa": -3, "chief": 1},
}


static func initial_cabinet() -> Array:
	var out: Array = []
	for id in ORDER:
		out.append({"id": id, "title": ROLES[id]["title"], "name": ROLES[id]["name"], "trust": 70.0, "vacant_months": 0})
	return out


static func intel_accuracy(s: GameState) -> float:
	var cia := s.advisor("cia")
	var budget_ratio := float(s.us["budget"]["intel"]) / maxf(float(s.us["budget_baseline"]["intel"]), 1.0)
	var acc := 45.0 + float(cia.get("trust", 50.0)) * 0.35 + (budget_ratio - 1.0) * 60.0
	if int(cia.get("vacant_months", 0)) > 0:
		acc -= 20.0
	if cia.get("loyalist", false):
		acc -= 15.0
	acc += Personas.mod(s, "intel", 0.0)
	return clampf(acc, 10.0, 100.0)


## Advice for one country: Array of {id, title, text, action}.
static func advise(s: GameState, iso: String, map_data: Dictionary) -> Array:
	var d := s.c(iso)
	var out: Array = []
	if d.is_empty():
		return out
	var rel := float(d["relation"])
	var at_war := s.at_war(iso)
	var hungry := float(d["hunger"]) > 45.0
	var threatened := false
	for n in s.neighbors_of(iso, map_data):
		var nd := s.c(n)
		if not nd.is_empty() and float(nd["ambition"]) > 60.0 and float(nd["military"]) > float(d["military"]) and float(nd["relation"]) < rel:
			threatened = true

	# Chief of Staff: politics first.
	if float(s.us["approval"]) < 40.0:
		out.append(_a("chief", "Approval is %d%%. Nothing abroad that costs us at home." % int(s.us["approval"]), ""))
	elif at_war and rel > 40.0:
		out.append(_a("chief", "Voters will back helping a friend under attack. Don't let it drag on.", "deploy"))
	else:
		out.append(_a("chief", "Fine by me if it's cheap. Watch the political capital.", ""))
	# State
	if at_war:
		out.append(_a("state", "Get both sides to the table. A peace deal here is worth the capital.", "peace"))
	elif rel < -20.0:
		out.append(_a("state", "Relations are poor. Start with an envoy before anything harder.", "envoy"))
	elif hungry:
		out.append(_a("state", "Aid here buys goodwill and saves lives.", "aid"))
	else:
		out.append(_a("state", "Steady relationship. An envoy keeps it warm.", "envoy"))
	# Defense
	if threatened and rel > 30.0:
		out.append(_a("defense", "A hostile neighbour outguns them. Troops on the ground would deter an attack.", "deploy"))
	elif rel > 25.0 and not at_war:
		out.append(_a("defense", "Arms sales strengthen a partner and help our industry.", "arms"))
	elif rel < -40.0 and float(d["military"]) > 55.0:
		out.append(_a("defense", "A serious military. Do not provoke it without allies.", ""))
	else:
		out.append(_a("defense", "No military interest here right now.", ""))
	# Treasury
	if rel > 20.0 and not d.get("trade_deal", false) and float(d["gdp"]) > 50.0:
		out.append(_a("treasury", "A trade deal would lift both economies.", "trade"))
	elif rel < -40.0 and not d.get("sanctioned", false):
		out.append(_a("treasury", "Sanctions would squeeze them at little cost to us.", "sanction"))
	elif hungry:
		out.append(_a("treasury", "Aid is cheap relative to their economy. Keep it targeted.", "aid"))
	else:
		out.append(_a("treasury", "Nothing here moves our numbers.", ""))
	# NSA
	if float(d["terror"]) > 55.0:
		out.append(_a("nsa", "They shelter groups that target us. Consider strikes on the camps.", "strike"))
	elif float(d["ambition"]) > 65.0:
		out.append(_a("nsa", "An expansionist regime. Shore up its neighbours now.", ""))
	else:
		out.append(_a("nsa", "Low threat.", ""))
	# CIA
	var acc := intel_accuracy(s)
	if rel < -40.0 and float(d["stability"]) < 40.0:
		out.append(_a("cia", "The regime is brittle. A coup has a real chance (%d%%)." % int(Actions.coup_chance(s, iso)), "coup"))
	elif rel < -30.0:
		out.append(_a("cia", "We can fund the opposition quietly.", "fund_opposition"))
	else:
		out.append(_a("cia", "Intel confidence on our reports: %d%%." % int(acc), ""))
	# UN
	if at_war:
		out.append(_a("un", "The Council wants a ceasefire. Lead it.", "peace"))
	elif hungry:
		out.append(_a("un", "Agencies are short of funds for %s. Aid through the UN." % d["name"], "aid"))
	else:
		out.append(_a("un", "No resolutions pending.", ""))
	for a in out:
		var adv := s.advisor(a["id"])
		a["name"] = adv.get("name", "")
		a["title"] = adv.get("title", "")
		a["trust"] = adv.get("trust", 0.0)
	return out


static var _debate_lines: Dictionary = {}


## Two advisors make their case on a briefing: [{id, name, title, choice, side ("for" | "against"), line}].
## The strongest supporter of one option, and the strongest supporter of a different one (or, failing
## that, the fiercest opponent of the first). Empty when the cabinet is not split. No dice are used.
static func debate(s: GameState, card: Dictionary) -> Array:
	if _debate_lines.is_empty():
		var parsed: Variant = ScenarioLoader.read_json("res://data/scenarios/debate_lines.json")
		if parsed is Dictionary:
			_debate_lines = parsed
	var choices: Array = card.get("choices", [])
	var best := {}
	var rival := {}
	for i in choices.size():
		var adv: Dictionary = choices[i].get("advisors", {})
		for id in adv:
			var a := s.advisor(id)
			if a.is_empty() or int(a.get("vacant_months", 0)) > 0 or not _debate_lines.has(id):
				continue
			if float(adv[id]) > float(best.get("v", 0.0)):
				best = {"v": float(adv[id]), "id": id, "choice": i, "side": "for"}
	if best.is_empty():
		return []
	for i in choices.size():
		var adv: Dictionary = choices[i].get("advisors", {})
		for id in adv:
			var a := s.advisor(id)
			if id == best["id"] or a.is_empty() or int(a.get("vacant_months", 0)) > 0 or not _debate_lines.has(id):
				continue
			var v := float(adv[id])
			if i != int(best["choice"]) and v > 0.0 and v > float(rival.get("v", 0.0)):
				rival = {"v": v, "id": id, "choice": i, "side": "for"}
	if rival.is_empty():
		var adv0: Dictionary = choices[int(best["choice"])].get("advisors", {})
		for id in adv0:
			var a := s.advisor(id)
			if id == best["id"] or a.is_empty() or int(a.get("vacant_months", 0)) > 0 or not _debate_lines.has(id):
				continue
			if float(adv0[id]) < float(rival.get("v", 0.0)):
				rival = {"v": float(adv0[id]), "id": id, "choice": int(best["choice"]), "side": "against"}
	if rival.is_empty():
		return []
	var out: Array = []
	for d in [best, rival]:
		var a := s.advisor(d["id"])
		var pool: Array = _debate_lines[d["id"]][d["side"]]
		var pick := absi(("%s|%s|%d" % [card.get("id", ""), d["id"], s.turn]).hash()) % pool.size()
		out.append({"id": d["id"], "name": a.get("name", ""), "title": a.get("title", ""), "choice": d["choice"], "side": d["side"], "line": String(pool[pick])})
	return out


static func _a(id: String, text: String, action: String) -> Dictionary:
	return {"id": id, "text": text, "action": action}


## Shift trust after the player acts. Advisors who recommended the action also gain.
static func react(s: GameState, action: String, iso: String, map_data: Dictionary) -> void:
	var recs := {}
	for a in advise(s, iso, map_data):
		if a["action"] == action:
			recs[a["id"]] = true
	var table: Dictionary = REACTIONS.get(action, {})
	for adv in s.advisors:
		var delta := float(table.get(adv["id"], 0))
		if recs.has(adv["id"]):
			delta += 2.0
		adjust(s, adv["id"], delta)


static func adjust(s: GameState, id: String, delta: float) -> void:
	var adv := s.advisor(id)
	if adv.is_empty():
		return
	adv["trust"] = clampf(float(adv["trust"]) + delta, 0.0, 100.0)


## Monthly: drift, resignations, replacements.
static func monthly(s: GameState) -> void:
	for adv in s.advisors:
		if int(adv["vacant_months"]) > 0:
			adv["vacant_months"] = int(adv["vacant_months"]) - 1
			if int(adv["vacant_months"]) == 0:
				var fits: Array = REPLACEMENTS.filter(func(n): return (n in FEMALE) == (String(adv["id"]) in FEMALE_SEATS))
				adv["name"] = fits[s.rng.randi_range(0, fits.size() - 1)]
				adv["trust"] = 60.0
				adv["loyalist"] = false
				s.add_log("%s is confirmed as %s." % [adv["name"], adv["title"]], "cabinet")
			continue
		var trust := float(adv["trust"])
		trust += (60.0 - trust) * 0.02 + Personas.mod(s, "trust_drift", 0.0)
		if adv.get("loyalist", false):
			trust = maxf(trust, 40.0)
		if float(s.us["scandal"]) > 60.0:
			trust -= 1.0
		adv["trust"] = trust
		if trust < 20.0:
			s.add_log("%s resigns as %s, citing \"fundamental disagreements\"." % [adv["name"], adv["title"]], "cabinet")
			adv["name"] = "(vacant)"
			adv["vacant_months"] = 2
			adv["trust"] = 50.0
			s.us["approval"] = float(s.us["approval"]) - 3.0
			s.resignations.append(s.turn)
