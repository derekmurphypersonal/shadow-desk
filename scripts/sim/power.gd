class_name Power
extends RefCounted
## Executive power at home: the road to strongman rule, and what pushes back.
## Tyranny (0-100) rises with every power move and slowly fades. It drags on approval and world
## standing, cools democracies, and brings protests, impeachment drives, restless generals and
## assassins. Assassinations abroad live here too.

const DEFS := {
	"emergency": {"label": "Declare a national emergency", "pc": 15, "tyranny": 12.0,
		"desc": "Rule by decree for 12 months: no Congressional votes on the use of force. Rally effect in a crisis, resentment otherwise."},
	"press": {"label": "Muzzle the press", "pc": 15, "tyranny": 12.0,
		"desc": "Scandal -30 now and fades faster while the press is muzzled. Democracies notice; tyranny won't fade."},
	"purge": {"label": "Purge the cabinet", "pc": 20, "tyranny": 8.0,
		"desc": "Replace every advisor whose trust is below 55 with a loyalist. Loyalists never resign, but a loyalist CIA Director tells you what you want to hear."},
	"courts": {"label": "Pack the courts", "pc": 25, "tyranny": 10.0,
		"desc": "Friendly judges: removal from office now needs a far more hostile Congress."},
	"crackdown": {"label": "Crack down on dissent", "pc": 10, "tyranny": 10.0,
		"desc": "Clear the streets. Protests end; martyrs are possible."},
	"rig": {"label": "Rig the election", "pc": 20, "cost": 1.0, "tyranny": 8.0,
		"desc": "Voter purges and friendly counting: +7 on election day. If it leaks, the scandal is enormous."},
	"postpone": {"label": "Postpone the election", "pc": 30, "tyranny": 25.0,
		"desc": "Push the election back a year under the emergency. Congress, the world and the streets react."},
	"third_term": {"label": "Seize a third term", "pc": 40, "tyranny": 25.0,
		"desc": "Suspend the two-term limit and rule for four more years without elections. There is no going back."},
	"liberalise": {"label": "Restore civil liberties", "pc": 10, "tyranny": -15.0,
		"desc": "End the emergency, free the press, release prisoners. Tyranny -15."},
}
const ORDER := ["emergency", "press", "purge", "courts", "crackdown", "rig", "postpone", "third_term", "liberalise"]


static func tyranny(s: GameState) -> float:
	return float(s.us.get("tyranny", 0.0))


static func add_tyranny(s: GameState, delta: float) -> void:
	s.us["tyranny"] = clampf(tyranny(s) + delta, 0.0, 100.0)


static func emergency(s: GameState) -> bool:
	return int(s.us.get("emergency_until", -1)) > s.turn


static func months_to_election(s: GameState) -> int:
	return s.next_election_turn - s.turn


static func pc_cost(s: GameState, id: String) -> int:
	var base := float(DEFS[id]["pc"])
	if id == "liberalise":
		return int(base)
	return int(round(base * Personas.mod(s, "power", 1.0)))


static func available(s: GameState, id: String) -> Dictionary:
	var u := s.us
	match id:
		"emergency":
			if emergency(s):
				return _no("Already in force for %d more months." % (int(u["emergency_until"]) - s.turn))
		"press":
			if u.get("press_muzzled", false):
				return _no("The press is already muzzled.")
		"purge":
			var any := false
			for a in s.advisors:
				if float(a["trust"]) < 55.0 and int(a.get("vacant_months", 0)) == 0:
					any = true
			if not any:
				return _no("Every advisor's trust is 55 or more. Nobody to purge.")
		"courts":
			if u.get("courts_packed", false):
				return _no("The courts are already yours.")
		"crackdown":
			if int(u.get("protests", 0)) <= 0:
				return _no("There are no protests to crush.")
		"rig":
			if not s.elections_enabled or u.get("third_term", false):
				return _no("There is no election to rig.")
			if months_to_election(s) > 6:
				return _no("Only in the last 6 months before an election (%d to go)." % months_to_election(s))
			if u.get("rigged", false):
				return _no("The fix is already in.")
			if float(u["funds"]["covert"]) < 1.0 * s.cost_scale():
				return _no("Needs $%.1fbn of covert funds." % (1.0 * s.cost_scale()))
		"postpone":
			if not s.elections_enabled or u.get("third_term", false):
				return _no("There is no election to postpone.")
			if not emergency(s):
				return _no("Only under a national emergency.")
			if months_to_election(s) > 6:
				return _no("Only in the last 6 months before an election (%d to go)." % months_to_election(s))
		"third_term":
			if u.get("third_term", false):
				return _no("You already hold power indefinitely.")
			if s.elections_won < 1:
				return _no("Only in your second term.")
			if s.end_turn - s.turn > 12:
				return _no("Only in the last 12 months of your second term (%d to go)." % (s.end_turn - s.turn))
			if tyranny(s) < 50.0:
				return _no("The country isn't ready to accept it (tyranny %d, need 50)." % int(tyranny(s)))
		"liberalise":
			if tyranny(s) < 10.0 and not u.get("press_muzzled", false) and not emergency(s):
				return _no("Civil liberties are intact.")
	var pc := pc_cost(s, id)
	if float(u["political_capital"]) < pc:
		return _no("Needs %d political capital; you have %d." % [pc, int(u["political_capital"])])
	return {"ok": true, "reason": ""}


static func _no(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


static func perform(s: GameState, id: String) -> String:
	s.us["political_capital"] = float(s.us["political_capital"]) - pc_cost(s, id)
	return apply_move(s, id)


## The effect of a power move, also used by briefing-card choices (no PC cost there).
static func apply_move(s: GameState, id: String) -> String:
	var u := s.us
	var def: Dictionary = DEFS.get(id, {})
	if not def.is_empty():
		add_tyranny(s, float(def["tyranny"]))
	var msg := ""
	match id:
		"emergency":
			u["emergency_until"] = s.turn + 12
			var crisis := false
			for w in s.wars:
				if u["troops"].has(w["a"]) or u["troops"].has(w["b"]):
					crisis = true
			if s.turn - int(u.get("attempt_turn", -99)) < 3:
				crisis = true
			_appr(s, 3.0 if crisis else -3.0)
			u["congress"] = clampf(float(u["congress"]) - 5.0, 0.0, 100.0)
			msg = "You declare a national emergency and rule by decree."
		"press":
			u["press_muzzled"] = true
			u["scandal"] = maxf(0.0, float(u["scandal"]) - 30.0)
			_stand(s, -8.0)
			Advisors.adjust(s, "chief", -3)
			Advisors.adjust(s, "state", -2)
			msg = "Broadcast licences are pulled and reporters detained. The scandal coverage stops."
		"purge":
			var n := 0
			for a in s.advisors:
				if float(a["trust"]) < 55.0 and int(a.get("vacant_months", 0)) == 0:
					var female := String(a["id"]) in Advisors.FEMALE_SEATS
					var fits: Array = Advisors.REPLACEMENTS.filter(func(x): return (x in Advisors.FEMALE) == female)
					a["name"] = fits[s.rng.randi_range(0, fits.size() - 1)]
					a["trust"] = 85.0
					a["loyalist"] = true
					n += 1
			_appr(s, -3.0)
			u["scandal"] = float(u["scandal"]) + 10.0
			msg = "You purge %d cabinet members and install loyalists." % n
		"courts":
			u["courts_packed"] = true
			_appr(s, -4.0)
			u["congress"] = clampf(float(u["congress"]) - 6.0, 0.0, 100.0)
			msg = "You expand the Supreme Court and fill it with loyal judges."
		"crackdown":
			u["protests"] = 0
			_stand(s, -6.0)
			_appr(s, 2.0 if Personas.id(s) == "strongman" else -3.0)
			if s.rng.randf() < 0.2:
				_appr(s, -6.0)
				u["scandal"] = float(u["scandal"]) + 15.0
				msg = "The National Guard clears the streets. A student is killed on camera; the footage goes around the world."
			else:
				msg = "The National Guard clears the streets. The protests are over, for now."
		"rig":
			u["funds"]["covert"] = float(u["funds"]["covert"]) - 1.0 * s.cost_scale()
			u["rigged"] = true
			var risk := 35.0 * (1.4 - Advisors.intel_accuracy(s) / 100.0) * Personas.mod(s, "exposure", 1.0)
			if s.rng.randf() * 100.0 < risk:
				u["rigged"] = false
				u["scandal"] = float(u["scandal"]) + 45.0
				_appr(s, -6.0)
				add_tyranny(s, 6.0)
				s.add_log("EXPOSED: a whistleblower reveals your plan to rig the election. Scandal +45.", "scandal")
				msg = "The election-rigging plan leaks."
			else:
				msg = "Voter rolls are quietly purged and the counting machines reprogrammed."
		"postpone":
			s.next_election_turn += 12
			s.end_turn += 12
			u["congress"] = clampf(float(u["congress"]) - 15.0, 0.0, 100.0)
			_stand(s, -15.0)
			_appr(s, -6.0)
			u["protests"] = maxi(int(u.get("protests", 0)), 3)
			msg = "Citing the emergency, you postpone the presidential election by a year."
		"third_term":
			u["third_term"] = true
			s.end_turn += 48
			s.next_election_turn = s.end_turn
			s.elections_enabled = false
			u["congress"] = clampf(float(u["congress"]) - 20.0, 0.0, 100.0)
			_stand(s, -20.0)
			u["protests"] = maxi(int(u.get("protests", 0)), 6)
			msg = "You suspend the two-term limit. There will be no election."
		"liberalise":
			u["press_muzzled"] = false
			u["emergency_until"] = -1
			u["protests"] = 0
			_stand(s, 5.0)
			_appr(s, 2.0)
			Advisors.adjust(s, "state", 2)
			Advisors.adjust(s, "un", 2)
			msg = "You end the emergency, free the press and release political prisoners."
		"trial":
			# Senate trial after articles of impeachment.
			var removal := clampf(20.0 + tyranny(s) * 0.5 - float(u["congress"]) * 0.6 - (25.0 if u.get("courts_packed", false) else 0.0), 5.0, 90.0)
			if s.rng.randf() * 100.0 < removal:
				Simulation.trigger_ending(s, "impeached", "The Senate convicted you of abuse of power and removed you from office.")
				return "Removed by the Senate."
			add_tyranny(s, -5.0)
			_appr(s, -4.0)
			s.stats["impeach_survived"] = int(s.stats.get("impeach_survived", 0)) + 1
			msg = "The Senate falls short of the votes to remove you (%d%% chance)." % int(removal)
		"defy":
			add_tyranny(s, 20.0)
			u["emergency_until"] = maxi(int(u.get("emergency_until", -1)), s.turn + 12)
			u["congress"] = clampf(float(u["congress"]) - 20.0, 0.0, 100.0)
			_stand(s, -15.0)
			Advisors.adjust(s, "defense", -15)
			msg = "You declare the impeachment unconstitutional and govern by decree."
		"purge_brass":
			if s.rng.randf() < 0.35:
				Simulation.trigger_ending(s, "deposed", "The generals moved first. Tanks surrounded the White House at dawn and you were flown into exile.")
				return "Deposed."
			add_tyranny(s, 10.0)
			Advisors.adjust(s, "defense", -10)
			msg = "You retire forty generals overnight. The plotters are scattered."
		"appease_brass":
			add_tyranny(s, -12.0)
			Advisors.adjust(s, "defense", 15)
			msg = "You promise the generals a return to normal politics."
		"concede":
			add_tyranny(s, -8.0)
			u["protests"] = 0
			_appr(s, 2.0)
			msg = "You meet the protest leaders and give ground."
		"security":
			u["security_until"] = s.turn + 12
			msg = "The Secret Service doubles your protection detail."
	if msg != "":
		s.add_log(msg, "headline" if id in ["emergency", "postpone", "third_term", "courts", "defy"] else "action")
	return msg


static func _appr(s: GameState, d: float) -> void:
	s.us["approval"] = clampf(float(s.us["approval"]) + d, 0.0, 100.0)


static func _stand(s: GameState, d: float) -> void:
	s.us["standing"] = clampf(float(s.us.get("standing", 50.0)) + d, 0.0, 100.0)


## Monthly: tyranny fades, the world reacts, and the system pushes back.
static func monthly(s: GameState) -> void:
	var u := s.us
	var t := tyranny(s)
	if not u.get("press_muzzled", false):
		add_tyranny(s, -0.4)
	else:
		u["scandal"] = maxf(0.0, float(u["scandal"]) - 2.0)
	if t > 15.0:
		for iso in s.active_isos():
			var d := s.c(iso)
			if float(d["freedom"]) > 70.0:
				d["relation"] = clampf(float(d["relation"]) - t * 0.012, -100.0, 100.0)
			elif float(d["freedom"]) < 30.0:
				d["relation"] = clampf(float(d["relation"]) + t * 0.008, -100.0, 100.0)
	if t > 20.0:
		u["grip"] = float(u.get("grip", 0.0)) + (t - 20.0) * 0.05
	# Protests.
	var p := int(u.get("protests", 0))
	if p > 0:
		u["protests"] = p - 1
		_appr(s, -0.5)
	elif t > 25.0 and _cool(s, "protests", 8):
		var ch := (t - 25.0) * 0.004 + maxf(0.0, 45.0 - float(u["approval"])) * 0.002
		if s.rng.randf() < ch:
			u["protests"] = 4
			_card(s, "protests", [
				{"label": "Meet the organisers and give ground", "effects": [["power", "concede"]], "advisors": {"chief": 3, "state": 2}},
				{"label": "Wait it out", "effects": [["us", "approval", -2]], "advisors": {}},
				{"label": "Send in the National Guard", "effects": [["power", "crackdown"]], "advisors": {"defense": 1, "chief": -3, "state": -2}},
			])
	# Impeachment for abuse of power.
	if t > 50.0 and float(u["congress"]) < 45.0 and _cool(s, "impeach", 12):
		if s.rng.randf() < (t - 50.0) * 0.004:
			_card(s, "impeach", [
				{"label": "Fight it in the Senate", "effects": [["power", "trial"]], "advisors": {"chief": 1}},
				{"label": "Resign with what dignity remains", "effects": [["end", "resigned", "You resigned rather than face a Senate trial."]], "advisors": {}},
				{"label": "Defy Congress and rule by decree", "effects": [["power", "defy"]], "advisors": {"defense": -6, "state": -4, "chief": -4}},
			])
	# The generals.
	var defense := s.advisor("defense")
	if t > 60.0 and float(defense.get("trust", 60.0)) < 50.0 and not defense.get("loyalist", false) and _cool(s, "generals", 10):
		if s.rng.randf() < (t - 60.0) * 0.004:
			_card(s, "generals", [
				{"label": "Purge the high command", "effects": [["power", "purge_brass"]], "advisors": {"defense": -6, "nsa": 1}},
				{"label": "Promise a return to normal politics", "effects": [["power", "appease_brass"]], "advisors": {"defense": 6}},
				{"label": "Double their budgets", "effects": [["us", "political_capital", -15], ["funds", "defense", -2], ["trust", "defense", 10]], "advisors": {"treasury": -4}},
			], "defense", "war")
	_foreign_assassinations(s)


static func _cool(s: GameState, key: String, months: int) -> bool:
	return s.turn - int(s.fired_events.get("power_" + key, -999)) >= months


static func _card(s: GameState, key: String, choices: Array, speaker: String = "", art: String = "protest") -> void:
	s.fired_events["power_" + key] = s.turn
	var card := {"id": "power_" + key, "speaker": "chief", "art": art, "ctx": "", "choices": choices}
	Events.system_card(card, key, {})
	if speaker != "":
		card["speaker"] = speaker
	s.pending.append(card)
	s.add_log(String(card["title"]), "headline")


## Monthly risk that someone tries to kill the President. Returns true if the game ended.
static func assassination_check(s: GameState) -> bool:
	var u := s.us
	var risk := 0.06   # % per month, any president
	for iso in s.active_isos():
		var d: Dictionary = s.countries[iso]
		if float(d["terror"]) > 60.0 and float(d["relation"]) < -30.0:
			risk += (float(d["terror"]) - 60.0) * 0.003
	risk += tyranny(s) * 0.012 + maxf(0.0, 35.0 - float(u["approval"])) * 0.03
	risk *= (1.3 - Advisors.intel_accuracy(s) / 100.0) * s.diff("risk") * Personas.mod(s, "assassin", 1.0)
	if int(u.get("security_until", -1)) > s.turn:
		risk *= 0.4
	if s.rng.randf() * 100.0 >= risk:
		return false
	var kill := clampf(0.22 + tyranny(s) * 0.004, 0.15, 0.6)
	if s.rng.randf() < kill:
		var who := "a lone gunman" if tyranny(s) < 30.0 else "officers of your own protection detail"
		Simulation.trigger_ending(s, "assassinated", "You were shot and killed by %s. The nation mourns, or doesn't." % who)
		return true
	u["attempt_turn"] = s.turn
	s.stats["attempts_survived"] = int(s.stats.get("attempts_survived", 0)) + 1
	_card(s, "attempt", [
		{"label": "Address the nation calmly", "effects": [["us", "approval", 6], ["us", "standing", 2]], "advisors": {"chief": 3}},
		{"label": "Declare a national emergency", "effects": [["us", "approval", 8], ["power", "emergency"]], "advisors": {"nsa": 2, "chief": -2, "state": -2}},
		{"label": "Double your security and say nothing", "effects": [["us", "approval", 2], ["power", "security"]], "advisors": {"cia": 2}},
	], "", "terror")
	return false


## Leaders abroad are killed too: by plotters, rivals and fanatics.
static func _foreign_assassinations(s: GameState) -> void:
	for iso in s.active_isos():
		var d: Dictionary = s.countries[iso]
		var ch := 0.0004 + maxf(0.0, 40.0 - float(d["stability"])) * 0.00008 + float(d["terror"]) * 0.00002
		if s.rng.randf() >= ch:
			continue
		leader_killed(s, iso, false)
		return


static func leader_killed(s: GameState, iso: String, by_us: bool) -> void:
	var d: Dictionary = s.countries[iso]
	d["stability"] = clampf(float(d["stability"]) - 18.0, 0.0, 100.0)
	d["ambition"] = s.rng.randf_range(15.0, 70.0)
	d["relation"] = clampf(float(d["relation"]) + s.rng.randf_range(-12.0, 18.0 if by_us else 12.0), -100.0, 100.0)
	if float(d["stability"]) < 25.0 and s.rng.randf() < 0.35:
		d["civil_war"] = true
	s.stats["leaders_killed"] = int(s.stats.get("leaders_killed", 0)) + 1
	if by_us:
		return
	s.add_log("The leader of %s is assassinated." % d["name"], "headline")
	var important := float(d["relation"]) >= 40.0 or float(d["pop"]) > 80.0 or Simulation._is_bloc_leader(s, iso)
	if important and s.turn - int(s.fired_events.get("power_leader_killed", -999)) >= 12:
		s.fired_events["power_leader_killed"] = s.turn
		var card := {"id": "power_leader_killed", "speaker": "cia", "art": "terror", "ctx": iso, "choices": [
			{"label": "Back the constitutional successor", "effects": [["funds", "aid", -1], ["add", "$C", "relation", 10], ["add", "$C", "stability", 10]], "advisors": {"state": 3, "un": 2}},
			{"label": "Stay out of it", "effects": [], "advisors": {}},
			{"label": "Quietly shape the succession", "effects": [["funds", "covert", -1], ["chance", 0.45, [["regime", "$C", true]], [["add", "$C", "relation", -20], ["us", "scandal", 15]]]], "advisors": {"cia": 4, "state": -3}},
		]}
		Events.system_card(card, "leader_killed", {"$NAME": d["name"]})
		s.pending.append(card)
