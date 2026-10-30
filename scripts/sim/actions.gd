class_name Actions
extends RefCounted
## Player actions against a target country. Each has a cost, a visible chance, and side effects.

const DEFS := {
	"envoy": {"label": "Send envoy", "cat": "Diplomacy", "pc": 5, "pool": "", "cost": 0.0,
		"desc": "Relations +6 to +14."},
	"peace": {"label": "Broker peace", "cat": "Diplomacy", "pc": 15, "pool": "", "cost": 0.0,
		"desc": "Try to end the war this country is fighting."},
	"aid": {"label": "Foreign aid", "cat": "Economic", "pc": 0, "pool": "aid", "cost": 1.0,
		"desc": "Cuts hunger, lifts stability and relations. Graft halves it in closed states."},
	"trade": {"label": "Trade deal", "cat": "Economic", "pc": 10, "pool": "", "cost": 0.0,
		"desc": "Both economies grow faster. Needs relations above 20 and Congress."},
	"sanction": {"label": "Impose sanctions", "cat": "Economic", "pc": 10, "pool": "", "cost": 0.0,
		"desc": "GDP and stability fall; relations crash."},
	"lift_sanction": {"label": "Lift sanctions", "cat": "Economic", "pc": 5, "pool": "", "cost": 0.0,
		"desc": "Relations +10."},
	"arms": {"label": "Arms sale", "cat": "Military", "pc": 0, "pool": "", "cost": 0.0,
		"desc": "Their military +5, relations +6. Earns defense funds. Risky with ambitious regimes."},
	"deploy": {"label": "Deploy troops", "cat": "Military", "pc": 10, "pool": "defense", "cost": 2.0,
		"desc": "Deters attack; joins their defence if attacked. Upkeep each month."},
	"withdraw": {"label": "Withdraw troops", "cat": "Military", "pc": 0, "pool": "", "cost": 0.0,
		"desc": "Bring the troops home."},
	"strike": {"label": "Air strike", "cat": "Military", "pc": 20, "pool": "defense", "cost": 1.0,
		"desc": "Military -10, stability -8. Scandal if unprovoked."},
	"fund_opposition": {"label": "Fund opposition", "cat": "Covert", "pc": 5, "pool": "covert", "cost": 0.5,
		"desc": "Quietly erodes the regime. Exposure risk."},
	"coup": {"label": "Sponsor coup", "cat": "Covert", "pc": 20, "pool": "covert", "cost": 2.0,
		"desc": "Install a friendly regime. High exposure risk."},
	"cyber": {"label": "Cyber operation", "cat": "Covert", "pc": 8, "pool": "covert", "cost": 0.5, "system": "cyber",
		"desc": "Degrade their military and economy. Exposure risk."},
	# ---- Ongoing operations: run every month until you stop them or the money runs out.
	"op_influence": {"label": "Charm offensive", "cat": "Diplomacy", "pc": 4, "pool": "", "cost": 0.0, "op": "influence",
		"desc": "Ongoing. Every month: relations +3, rival influence -6. Upkeep 2 PC a month."},
	"op_aid": {"label": "Aid programme", "cat": "Economic", "pc": 3, "pool": "aid", "cost": 0.5, "op": "aid",
		"desc": "Ongoing. Every month: hunger falls, stability and relations rise. Upkeep from aid funds."},
	"op_support": {"label": "Back their war effort", "cat": "Military", "pc": 8, "pool": "defense", "cost": 1.0, "op": "support",
		"desc": "Ongoing. Every month: weapons, intelligence and advisers strengthen them in their war. Upkeep: defense funds and 2 PC."},
	"op_air": {"label": "Air campaign", "cat": "Military", "pc": 15, "pool": "defense", "cost": 1.0, "op": "air",
		"desc": "Ongoing. Every month: strikes wear down their military and stability. Scandal builds if unprovoked. Upkeep: defense funds and 3 PC."},
	"op_invade": {"label": "Invade", "cat": "Military", "pc": 30, "pool": "defense", "cost": 4.0, "op": "invade",
		"desc": "Ongoing ground war to topple the regime. Needs Congress. Costs approval, money and 4 PC every month until victory or withdrawal."},
	"op_covert": {"label": "Covert campaign", "cat": "Covert", "pc": 6, "pool": "covert", "cost": 0.4, "op": "covert",
		"desc": "Ongoing. Every month: fund dissidents and sabotage; stability erodes. Small monthly exposure risk."},
}
const ORDER := ["envoy", "op_influence", "peace", "aid", "op_aid", "trade", "sanction", "lift_sanction", "arms", "deploy",
	"withdraw", "op_support", "strike", "op_air", "op_invade", "fund_opposition", "op_covert", "coup", "cyber"]
const OP_NAMES := {"influence": "Charm offensive", "aid": "Aid programme", "support": "War support", "air": "Air campaign",
	"invade": "Invasion", "covert": "Covert campaign"}
## Monthly running costs: [pc, pool, $bn before cost scale]
const OP_UPKEEP := {"influence": [2.0, "", 0.0], "aid": [0.0, "aid", 0.5], "support": [2.0, "defense", 0.6],
	"air": [3.0, "defense", 0.8], "invade": [4.0, "defense", 1.5], "covert": [1.0, "covert", 0.3]}


static func cost_of(s: GameState, id: String) -> float:
	return float(DEFS[id]["cost"]) * s.cost_scale()


static func coup_chance(s: GameState, iso: String) -> float:
	var d := s.c(iso)
	return clampf((60.0 - float(d["stability"])) + float(d["covert_pressure"]) * 0.5 + Advisors.intel_accuracy(s) * 0.2, 5.0, 85.0)


static func peace_chance(s: GameState, iso: String) -> float:
	var other := s.enemy_of(iso)
	var d := s.c(iso)
	if other == "" and d.get("civil_war", false):
		return clampf(55.0 - (50.0 - float(d["stability"])) * 0.4 + float(d["relation"]) * 0.2, 5.0, 80.0)
	if other == "":
		return 0.0
	var o := s.c(other)
	var amb := (float(d["ambition"]) + float(o["ambition"])) * 0.5
	var rel := (float(d["relation"]) + float(o["relation"])) * 0.1
	var w := s.war_for(iso)
	var weariness := minf(float(w.get("months", 0)) * 0.6, 20.0)
	var standing := (float(s.us.get("standing", 50.0)) - 50.0) * 0.2
	return clampf(70.0 - amb * 0.6 + rel + weariness + standing, 5.0, 90.0)


static func strike_provoked(s: GameState, iso: String) -> bool:
	var d := s.c(iso)
	return float(d["relation"]) < -40.0 or float(d["terror"]) > 55.0 or _attacking_friend(s, iso)


## Chance Congress authorises force. Returns -1 when no vote is needed.
static func war_powers_chance(s: GameState, iso: String, id: String) -> float:
	if id == "strike" and not strike_provoked(s, iso):
		return clampf(float(s.us["congress"]) + 10.0 + (float(s.us.get("standing", 50.0)) - 50.0) * 0.3, 5.0, 95.0)
	if id == "deploy" and s.at_war(iso):
		return clampf(float(s.us["congress"]) + 25.0, 5.0, 95.0)
	if id == "op_air" and not strike_provoked(s, iso):
		return clampf(float(s.us["congress"]) + (float(s.us.get("standing", 50.0)) - 50.0) * 0.3, 5.0, 90.0)
	if id == "op_invade":
		var bonus := 25.0 if strike_provoked(s, iso) else -10.0
		return clampf(float(s.us["congress"]) + bonus, 5.0, 90.0)
	return -1.0


static func op_for(s: GameState, iso: String, type: String) -> Dictionary:
	for op in s.us.get("ops", []):
		if op["iso"] == iso and op["type"] == type:
			return op
	return {}


static func ops_for(s: GameState, iso: String) -> Array:
	var out: Array = []
	for op in s.us.get("ops", []):
		if op["iso"] == iso:
			out.append(op)
	return out


static func invasion_defence(s: GameState, iso: String) -> float:
	var d := s.c(iso)
	return float(d["military"]) * (0.5 + float(d["stability"]) / 100.0) * 1.3


static func available(s: GameState, iso: String, id: String) -> Dictionary:
	var def: Dictionary = DEFS[id]
	var d := s.c(iso)
	if d.is_empty() or not s.is_active(iso):
		return _no("Not a valid target.")
	if def.has("system") and not s.has_system(def["system"]):
		return _no("Not available in this scenario.")
	var rel := float(d["relation"])
	var troops: Dictionary = s.us["troops"]
	if def.has("op") and not op_for(s, iso, def["op"]).is_empty():
		return _no("Already running. Stop it from the Operations list above.")
	match id:
		"peace":
			if not s.at_war(iso) and not d.get("civil_war", false):
				return _no("There is no war here to end.")
		"trade":
			if d.get("trade_deal", false):
				return _no("A trade deal is already in force.")
			if rel < 20.0:
				return _no("Relations too low (%d, need 20). Try an envoy or a charm offensive." % int(rel))
			if d.get("sanctioned", false):
				return _no("Lift sanctions first.")
		"sanction":
			if d.get("sanctioned", false):
				return _no("Sanctions are already in force.")
		"lift_sanction":
			if not d.get("sanctioned", false):
				return _no("There are no sanctions to lift.")
		"arms":
			if rel < 0.0:
				return _no("They won't buy from us (relations %d, need 0)." % int(rel))
			if d.get("sanctioned", false):
				return _no("Can't sell arms to a country under our sanctions.")
		"deploy":
			if troops.has(iso):
				return _no("US troops are already there.")
			if rel < 30.0:
				return _no("They won't host US troops (relations %d, need 30)." % int(rel))
		"withdraw":
			if not troops.has(iso):
				return _no("There are no US troops there.")
		"aid", "op_aid":
			if rel < -50.0:
				return _no("They refuse our aid while relations are below -50 (now %d)." % int(rel))
		"op_influence":
			if rel > 85.0:
				return _no("Relations are already excellent.")
		"op_support":
			if not s.at_war(iso):
				return _no("Only for a country that is fighting a war.")
			if rel < 0.0:
				return _no("They won't accept our help (relations %d, need 0)." % int(rel))
			if s.war_for(iso).get("a", "") == iso and float(s.c(s.enemy_of(iso)).get("relation", 0.0)) > 40.0:
				return _no("They are the aggressor, attacking one of our friends.")
		"op_air", "strike":
			if rel > 30.0:
				return _no("Relations are friendly (%d). Sanctions or a diplomatic break would come first." % int(rel))
		"op_invade":
			if d.get("nuclear", false):
				return _no("A nuclear power. Your generals refuse to plan it.")
			if rel > 0.0:
				return _no("You can't invade a friendly country (relations %d, must be below 0)." % int(rel))
		"coup":
			if rel > 40.0:
				return _no("They're already friendly (relations %d)." % int(rel))
	var pc := float(def["pc"])
	var have_pc := float(s.us["political_capital"])
	if have_pc < pc:
		return _no("Needs %d political capital; you have %d. It refills every month, faster with high approval." % [int(pc), int(have_pc)])
	if def["pool"] != "" and float(s.us["funds"][def["pool"]]) < cost_of(s, id):
		var hint := {"aid": "Foreign aid", "defense": "Defense", "covert": "Intelligence", "domestic": "Domestic"}
		return _no("Needs $%.1fbn of %s funds; you have $%.1fbn. Raise the %s budget or wait a month." % [cost_of(s, id), def["pool"], float(s.us["funds"][def["pool"]]), hint.get(def["pool"], "")])
	var chance := -1.0
	match id:
		"coup":
			chance = coup_chance(s, iso)
		"peace":
			chance = peace_chance(s, iso)
		"trade":
			chance = clampf(float(s.us["congress"]) + 30.0, 10.0, 95.0)
		"strike", "deploy", "op_air", "op_invade":
			chance = war_powers_chance(s, iso, id)
	return {"ok": true, "reason": "", "chance": chance}


static func _no(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "chance": -1.0}


static func _roll(s: GameState, pct: float) -> bool:
	return s.rng.randf() * 100.0 < pct


static func _expose(s: GameState, iso: String, pct: float, scandal: float, what: String) -> bool:
	## Covert exposure check. Better intel lowers the risk.
	var risk := pct * (1.4 - Advisors.intel_accuracy(s) / 100.0)
	if _roll(s, risk):
		s.us["scandal"] = float(s.us["scandal"]) + scandal
		_standing(s, -10.0)
		s.c(iso)["relation"] = float(s.c(iso)["relation"]) - 25.0
		Advisors.adjust(s, "state", -5)
		Advisors.adjust(s, "un", -4)
		s.add_log("EXPOSED: the press reports a US %s in %s. Scandal +%d." % [what, s.c(iso)["name"], int(scandal)], "scandal")
		return true
	return false


## Perform an action. Returns a one-line result for the UI. Assumes available() passed.
static func perform(s: GameState, iso: String, id: String, map_data: Dictionary) -> String:
	var def: Dictionary = DEFS[id]
	var d := s.c(iso)
	var name: String = d["name"]
	s.us["political_capital"] = float(s.us["political_capital"]) - float(def["pc"])
	if def["pool"] != "":
		s.us["funds"][def["pool"]] = float(s.us["funds"][def["pool"]]) - cost_of(s, id)
	Advisors.react(s, id, iso, map_data)
	var vote := war_powers_chance(s, iso, id)
	if vote >= 0.0 and not _roll(s, vote):
		var refused := "Congress refuses to authorise force against %s (%d%% chance)." % [name, int(vote)]
		s.add_log(refused, "action")
		return refused
	var msg := ""
	match id:
		"envoy":
			var gain := s.rng.randf_range(6.0, 14.0) * (1.0 - float(d["ambition"]) / 200.0)
			_rel(d, gain)
			d["rival_pull"] = maxf(0.0, float(d.get("rival_pull", 0.0)) - 12.0)
			msg = "Envoy to %s: relations +%d." % [name, int(gain)]
		"peace":
			var chance := peace_chance(s, iso)
			if _roll(s, chance):
				if s.at_war(iso):
					var other := s.enemy_of(iso)
					Simulation.end_war(s, s.war_for(iso), "A US-brokered ceasefire ends the war between %s and %s." % [name, s.c(other)["name"]])
				else:
					d["civil_war"] = false
					s.add_log("US mediation ends the civil war in %s." % name, "headline")
				s.us["treaties"] = int(s.us["treaties"]) + 1
				s.us["approval"] = float(s.us["approval"]) + 3.0
				_standing(s, 6.0)
				msg = "Peace deal signed (%d%% chance)." % int(chance)
			else:
				_rel(d, -3.0)
				msg = "Peace talks with %s failed (%d%% chance)." % [name, int(chance)]
		"aid":
			var amount := cost_of(s, id)
			var impact := amount / maxf(float(d["gdp"]), 0.1) * 100.0   # % of their GDP
			var eff := 0.5 if float(d["freedom"]) < 30.0 else 1.0
			d["hunger"] = clampf(float(d["hunger"]) - minf(18.0, impact * 4.0) * eff, 0.0, 100.0)
			d["aid_boost"] = float(d["aid_boost"]) + minf(10.0, impact * 2.0) * eff
			_rel(d, 3.0 + minf(8.0, impact))
			d["rival_pull"] = maxf(0.0, float(d.get("rival_pull", 0.0)) - 6.0)
			_standing(s, 1.0)
			msg = "$%.1fbn in aid to %s (%.1f%% of their GDP)." % [amount, name, impact]
		"trade":
			if _roll(s, clampf(float(s.us["congress"]) + 30.0, 10.0, 95.0)):
				d["trade_deal"] = true
				d["rival_pull"] = 0.0
				_rel(d, 8.0)
				s.us["approval"] = float(s.us["approval"]) + 0.5
				msg = "Trade deal with %s ratified." % name
			else:
				msg = "Congress blocked the %s trade deal." % name
		"sanction":
			_standing(s, 1.0 if float(d["relation"]) < -30.0 else -3.0)
			d["sanctioned"] = true
			_rel(d, -25.0)
			msg = "Sanctions imposed on %s." % name
		"lift_sanction":
			d["sanctioned"] = false
			_rel(d, 10.0)
			msg = "Sanctions on %s lifted." % name
		"arms":
			d["military"] = clampf(float(d["military"]) + 5.0, 0.0, 100.0)
			_rel(d, 6.0)
			s.us["funds"]["defense"] = float(s.us["funds"]["defense"]) + 1.0 * s.cost_scale()
			if float(d["ambition"]) > 60.0:
				d["ambition"] = float(d["ambition"]) + 4.0
				Advisors.adjust(s, "state", -3)
				Advisors.adjust(s, "un", -2)
			msg = "Arms package sold to %s." % name
		"deploy":
			s.us["troops"][iso] = 1
			_rel(d, 5.0)
			d["stability"] = clampf(float(d["stability"]) + 3.0, 0.0, 100.0)
			msg = "US troops deployed to %s." % name
		"withdraw":
			s.us["troops"].erase(iso)
			_rel(d, -5.0)
			msg = "US troops withdrawn from %s." % name
		"strike":
			var provoked := strike_provoked(s, iso)
			d["military"] = clampf(float(d["military"]) - 10.0, 0.0, 100.0)
			d["stability"] = clampf(float(d["stability"]) - 8.0, 0.0, 100.0)
			d["terror"] = clampf(float(d["terror"]) - 10.0, 0.0, 100.0)
			_rel(d, -40.0)
			if not provoked:
				s.us["scandal"] = float(s.us["scandal"]) + 15.0
				_standing(s, -10.0)
				Advisors.adjust(s, "un", -6)
				msg = "Air strikes on %s. Congress demands answers (scandal +15)." % name
			else:
				s.us["approval"] = float(s.us["approval"]) + 1.0
				msg = "Air strikes on %s." % name
			var w := s.war_for(iso)
			if not w.is_empty():
				w["progress"] = float(w["progress"]) + (-12.0 if w["a"] == iso else 12.0)
			if d.get("nuclear", false) and _roll(s, 4.0):
				Simulation.trigger_ending(s, "nuclear", "%s answered the strikes with a nuclear weapon." % name)
		"fund_opposition":
			d["stability"] = clampf(float(d["stability"]) - s.rng.randf_range(4.0, 9.0), 0.0, 100.0)
			d["covert_pressure"] = float(d["covert_pressure"]) + 10.0
			if not _expose(s, iso, 12.0, 15.0, "funding operation"):
				msg = "Opposition groups in %s quietly funded." % name
			else:
				msg = "Funding operation in %s exposed." % name
		"coup":
			var chance := coup_chance(s, iso)
			var ok := _roll(s, chance)
			if ok:
				Simulation.regime_change(s, iso, true)
				msg = "Coup in %s succeeds; a friendly government takes power." % name
			else:
				_rel(d, -30.0)
				d["stability"] = clampf(float(d["stability"]) + 5.0, 0.0, 100.0)
				msg = "Coup attempt in %s fails." % name
			_expose(s, iso, 30.0 if ok else 65.0, 40.0, "-backed coup")
		"op_influence", "op_aid", "op_support", "op_air", "op_invade", "op_covert":
			var type: String = def["op"]
			if not s.us.has("ops"):
				s.us["ops"] = []
			s.us["ops"].append({"type": type, "iso": iso, "months": 0, "progress": 0.0})
			if type == "invade":
				s.add_log("WAR: US forces invade %s." % name, "war")
				s.us["mood"] = float(s.us["mood"]) + (3.0 if strike_provoked(s, iso) else -2.0)
				_rel(d, -60.0)
				if d["bloc"] == "west":
					d["bloc"] = "nonaligned"
			msg = "%s in %s begins." % [OP_NAMES[type], name]
			s.fx.append({"iso": iso, "kind": type, "text": OP_NAMES[type]})
		"cyber":
			d["military"] = clampf(float(d["military"]) - 5.0, 0.0, 100.0)
			d["gdp"] = float(d["gdp"]) * 0.995
			if not _expose(s, iso, 20.0, 10.0, "cyber operation"):
				msg = "Cyber operation degrades %s's command networks." % name
			else:
				msg = "Cyber operation against %s attributed to the US." % name
	if msg != "":
		s.add_log(msg, "action")
		if not def.has("op"):
			s.fx.append({"iso": iso, "kind": id, "text": def["label"]})
	return msg


## Stop an ongoing operation. Invasions end with a withdrawal (approval hit if unfinished).
static func stop_op(s: GameState, iso: String, type: String) -> String:
	var op := op_for(s, iso, type)
	if op.is_empty():
		return ""
	s.us["ops"].erase(op)
	var name: String = s.c(iso).get("name", iso)
	var msg := "%s in %s ended." % [OP_NAMES[type], name]
	if type == "invade":
		s.us["approval"] = float(s.us["approval"]) - 4.0
		msg = "US forces withdraw from %s without victory." % name
	s.add_log(msg, "action")
	return msg


static func _standing(s: GameState, delta: float) -> void:
	s.us["standing"] = clampf(float(s.us.get("standing", 50.0)) + delta, 0.0, 100.0)


static func _rel(d: Dictionary, delta: float) -> void:
	d["relation"] = clampf(float(d["relation"]) + delta, -100.0, 100.0)


static func _attacking_friend(s: GameState, iso: String) -> bool:
	var w := s.war_for(iso)
	if w.is_empty() or w["a"] != iso:
		return false
	return float(s.c(w["b"]).get("relation", 0.0)) > 30.0
