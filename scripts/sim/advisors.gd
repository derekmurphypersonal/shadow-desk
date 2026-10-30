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
	"cyber": {"cia": 2, "nsa": 2, "state": -1},
	"peace": {"state": 4, "un": 4, "chief": 1},
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
				adv["name"] = REPLACEMENTS[s.rng.randi_range(0, REPLACEMENTS.size() - 1)]
				adv["trust"] = 60.0
				s.add_log("%s is confirmed as %s." % [adv["name"], adv["title"]], "cabinet")
			continue
		var trust := float(adv["trust"])
		trust += (60.0 - trust) * 0.02
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
