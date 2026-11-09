class_name Crises
extends RefCounted
## Crises with a clock. A crisis runs for three or four months instead of resolving on one card:
## an opening briefing, a month or two in which you work it (diary time and country actions), a
## final decision, then an outcome that depends on how strong a hand you built.
##
## State lives in s.us["crises"]: [{id, kind, iso, iso2, months, clock, hand, title, used, final, worked}]
##   iso   the country where it happens (and where most of your options are)
##   iso2  the other party, if any (the aggressor in a standoff)
##   hand  0-100: your chance, in percent, that it ends well
## Deterministic: only s.rng is used. No UI code.

const MAX_ACTIVE := 2
const KINDS := {
	"hostage": {"clock": 3, "speaker": "nsa", "art": "terror", "short": "Hostages in %s"},
	"standoff": {"clock": 3, "speaker": "defense", "art": "war", "short": "Standoff over %s"},
	"breakout": {"clock": 4, "speaker": "cia", "art": "nuclear", "short": "%s races for the bomb"},
	"famine": {"clock": 3, "speaker": "un", "art": "famine", "short": "Famine in %s"},
	"coup": {"clock": 3, "speaker": "cia", "art": "covert", "short": "Coup plot in %s"},
}
## What strengthens your hand: kind -> {action id -> [points, "iso" | "iso2"]}. Once a month each.
const HELPS := {
	"hostage": {"envoy": [10, "iso"], "op_covert": [8, "iso"], "fund_opposition": [5, "iso"], "aid": [4, "iso"]},
	"standoff": {"deploy": [25, "iso"], "pact": [25, "iso"], "arms": [10, "iso"], "envoy": [8, "iso2"], "sanction": [8, "iso2"], "op_influence": [6, "iso2"]},
	"breakout": {"sanction": [12, "iso"], "cyber": [15, "iso"], "envoy": [8, "iso"], "op_covert": [8, "iso"], "strike": [18, "iso"], "op_air": [20, "iso"]},
	"famine": {"aid": [15, "iso"], "op_aid": [25, "iso"], "envoy": [3, "iso"]},
	"coup": {"aid": [8, "iso"], "envoy": [8, "iso"], "deploy": [20, "iso"], "arms": [6, "iso"], "pact": [15, "iso"]},
}
const START_CHOICES := {
	"hostage": ["Take personal charge of the negotiation", "Leave it to the State Department", "Say nothing and wait"],
	"standoff": ["Call both capitals yourself", "Have the Pentagon signal quietly", "Wait and watch"],
	"breakout": ["Make stopping it your personal priority", "Hand it to the intelligence community", "Wait for better evidence"],
	"famine": ["Lead the relief effort yourself", "Leave it to the aid agencies", "Wait for the UN appeal"],
	"coup": ["Phone the government and promise support", "Have the station chief keep watch", "Stay out of their politics"],
}


static func list(s: GameState) -> Array:
	return s.us.get("crises", [])


static func for_iso(s: GameState, iso: String) -> Dictionary:
	for c in list(s):
		if c["iso"] == iso:
			return c
	return {}


static func by_id(s: GameState, id: String) -> Dictionary:
	for c in list(s):
		if str(c["id"]) == id:
			return c
	return {}


## 1 opening, 2 building, 3 the final decision.
static func stage(c: Dictionary) -> int:
	if int(c["months"]) >= int(c["clock"]) - 1:
		return 3
	return 1 if int(c["months"]) == 0 else 2


static func months_left(c: Dictionary) -> int:
	return maxi(0, int(c["clock"]) - int(c["months"]))


static func hand_word(c: Dictionary) -> String:
	var h := float(c["hand"])
	if h < 30.0:
		return "weak"
	if h < 55.0:
		return "even"
	if h < 75.0:
		return "good"
	return "strong"


## A plain-language hint for the interface: what would strengthen your hand right now.
static func helps_text(s: GameState, c: Dictionary) -> String:
	var bits: Array = []
	var table: Dictionary = HELPS[c["kind"]]
	for id in table:
		if c["used"].has(id):
			continue
		var target: String = c[table[id][1]]
		if target == "" or not Actions.DEFS.has(id):
			continue
		var avail := Actions.available(s, target, id)
		if avail["ok"]:
			bits.append("%s (%s)" % [String(Actions.DEFS[id]["label"]).to_lower(), s.c(target)["name"]])
	if bits.is_empty():
		return "Diary time is the main way to work this now."
	return "Helps: " + ", ".join(bits.slice(0, 3)) + "."


## The best available helping action, for guidance and pins: [iso, action id] or [].
static func best_help(s: GameState, c: Dictionary) -> Array:
	var best: Array = []
	var pts := 0.0
	var table: Dictionary = HELPS[c["kind"]]
	for id in table:
		if c["used"].has(id) or not Actions.DEFS.has(id):
			continue
		var target: String = c[table[id][1]]
		if target != "" and float(table[id][0]) > pts and Actions.available(s, target, id)["ok"]:
			pts = float(table[id][0])
			best = [target, id]
	return best


static func add_hand(c: Dictionary, delta: float) -> void:
	c["hand"] = clampf(float(c["hand"]) + delta, 5.0, 95.0)


## Called from Actions.perform: a country action may strengthen your hand in a live crisis.
static func on_action(s: GameState, iso: String, id: String) -> String:
	for c in list(s):
		var table: Dictionary = HELPS[c["kind"]]
		if not table.has(id) or c["used"].has(id):
			continue
		if c[table[id][1]] != iso:
			continue
		c["used"][id] = true
		add_hand(c, float(table[id][0]))
		return "%s: your hand is now %s." % [c["title"], hand_word(c)]
	return ""


## Diary time spent on a crisis. Returns the result line.
static func work(s: GameState, id: String, _map_data: Dictionary) -> String:
	var c := by_id(s, id)
	if c.is_empty():
		return "The crisis is already over."
	add_hand(c, 12.0)
	c["worked"] = true
	return "%s: a day in the Situation Room. Your hand is now %s." % [c["title"], hand_word(c)]


## Start of the monthly tick (before the calendar advances): crises deteriorate, and those whose
## time is up are settled.
static func tick(s: GameState, map_data: Dictionary) -> void:
	if not s.us.has("crises"):
		s.us["crises"] = []
	for c in list(s).duplicate():
		if not s.is_active(c["iso"]) or (c["iso2"] != "" and not s.is_active(c["iso2"])):
			s.us["crises"].erase(c)
			continue
		if c["kind"] == "standoff" and (s.at_war(c["iso"]) or s.at_war(c["iso2"])):
			s.us["crises"].erase(c)
			continue
		c["months"] = int(c["months"]) + 1
		c["used"] = {}
		c["worked"] = false
		add_hand(c, -8.0)
		if int(c["months"]) >= int(c["clock"]):
			_resolve(s, c, map_data)
			s.us["crises"].erase(c)
		elif stage(c) == 2:
			s.add_log("%s: the situation is getting worse. Your hand is %s." % [c["title"], hand_word(c)], "op", c["iso"])


## After the calendar advances: final-decision briefings, and perhaps a new crisis.
static func after(s: GameState, map_data: Dictionary) -> void:
	if s.game_over:
		return
	for c in list(s):
		if stage(c) == 3 and not c.get("final", false):
			c["final"] = true
			_final_card(s, c)
	_maybe_start(s, map_data)


static func _maybe_start(s: GameState, map_data: Dictionary) -> void:
	var active := list(s).size()
	if active >= MAX_ACTIVE or s.turn < 3:
		return
	var since := s.turn - int(s.stats.get("crisis_last", -99))
	if since < 4:
		return
	if s.rng.randf() > (0.12 if active == 0 else 0.04):
		return
	var options := _candidates(s, map_data)
	if options.is_empty():
		return
	var kinds := options.keys()
	kinds.sort()
	var kind: String = kinds[s.rng.randi_range(0, kinds.size() - 1)]
	var pick: Array = options[kind][s.rng.randi_range(0, options[kind].size() - 1)]
	start(s, kind, pick[0], pick[1])


static func _candidates(s: GameState, map_data: Dictionary) -> Dictionary:
	var out := {}
	var busy := {}
	for c in list(s):
		busy[c["iso"]] = true
		busy[c["iso2"]] = true
	for iso in s.active_isos():
		if busy.has(iso) or s.at_war(iso):
			continue
		var d := s.c(iso)
		var rel := float(d["relation"])
		if float(d["terror"]) > 50.0 and rel < 10.0 and float(d["pop"]) > 3.0:
			_push(out, "hostage", [iso, ""])
		if rel < -30.0 and not d.get("nuclear", false) and float(d["ambition"]) > 55.0 and float(d["military"]) > 45.0 and float(d["gdp"]) > 20.0 * s.cost_scale():
			_push(out, "breakout", [iso, ""])
		if float(d["hunger"]) > 62.0 and float(d["pop"]) > 5.0 and rel > -50.0 and Actions.op_for(s, iso, "aid").is_empty():
			_push(out, "famine", [iso, ""])
		if rel >= 30.0 and float(d["stability"]) < 40.0 and not d.get("civil_war", false):
			_push(out, "coup", [iso, ""])
		if rel >= 25.0 and not s.us["troops"].has(iso):
			for n in s.neighbors_of(iso, map_data):
				if not s.is_active(n) or s.at_war(n) or busy.has(n):
					continue
				var nd := s.c(n)
				if float(nd["ambition"]) > 60.0 and float(nd["military"]) > float(d["military"]) and nd["bloc"] != d["bloc"] and float(nd["relation"]) < rel - 20.0:
					_push(out, "standoff", [iso, n])
					break
	return out


static func _push(out: Dictionary, kind: String, item: Array) -> void:
	if not out.has(kind):
		out[kind] = []
	out[kind].append(item)


## Open a crisis and put its first briefing on the desk.
static func start(s: GameState, kind: String, iso: String, iso2: String = "") -> Dictionary:
	if not s.us.has("crises"):
		s.us["crises"] = []
	var n := int(s.stats.get("crisis_count", 0)) + 1
	s.stats["crisis_count"] = n
	s.stats["crisis_last"] = s.turn
	var def: Dictionary = KINDS[kind]
	var name := String(s.c(iso)["name"])
	var c := {"id": n, "kind": kind, "iso": iso, "iso2": iso2, "months": 0, "clock": int(def["clock"]),
		"hand": 30.0, "title": String(def["short"]) % name, "used": {}, "final": false, "worked": false}
	s.us["crises"].append(c)
	var labels: Array = START_CHOICES[kind]
	var sp := String(def["speaker"])
	var card := {"id": "crisis_start", "speaker": sp, "art": def["art"], "ctx": iso, "crisis": n, "choices": [
		{"label": labels[0], "effects": [["us", "political_capital", -8], ["crisis", 15]], "advisors": {sp: 3, "chief": -1}},
		{"label": labels[1], "effects": [["crisis", 6]], "advisors": {sp: 1}},
		{"label": labels[2], "effects": [["crisis", -5]], "advisors": {sp: -3, "chief": 1}},
	]}
	Events.system_card(card, "crisis_%s_start" % kind, {"$NAME": name, "$B": String(s.c(iso2).get("name", ""))})
	s.pending.append(card)
	s.add_log("CRISIS: %s. It will be settled within %d months." % [c["title"], int(c["clock"])], "headline", iso, 1)
	return c


static func _final_card(s: GameState, c: Dictionary) -> void:
	var kind := String(c["kind"])
	var def: Dictionary = KINDS[kind]
	var sp := String(def["speaker"])
	var choices: Array = []
	match kind:
		"hostage":
			choices = [
				{"label": "Authorise a rescue raid", "effects": [["chance", 0.5, [["crisis", 32], ["us", "approval", 2]], [["crisis", -24], ["us", "approval", -3]]]], "advisors": {"defense": 3, "nsa": 2, "state": -2}},
				{"label": "Pay quietly through a third party ($1bn)", "effects": [["funds", "covert", -1], ["crisis", 24], ["us", "scandal", 10]], "advisors": {"cia": 2, "chief": -2, "nsa": -2}},
				{"label": "Hold the line and keep talking", "effects": [["crisis", 4]], "advisors": {"state": 2}},
			]
		"standoff":
			choices = [
				{"label": "Send a carrier group ($2bn)", "effects": [["funds", "defense", -2], ["crisis", 24]], "advisors": {"defense": 4, "nsa": 2, "treasury": -1}},
				{"label": "Call their bluff in public", "effects": [["chance", 0.5, [["crisis", 28], ["us", "credibility", 4]], [["crisis", -20], ["us", "credibility", -4]]]], "advisors": {"nsa": 2, "state": -3}},
				{"label": "Urge both sides to talk", "effects": [["crisis", 6]], "advisors": {"state": 3, "un": 2, "defense": -2}},
			]
		"breakout":
			choices = [
				{"label": "Strike the sites (15 PC)", "effects": [["us", "political_capital", -15], ["crisis", 36], ["us", "standing", -5], ["add", "$C", "relation", -25]], "advisors": {"defense": 3, "nsa": 3, "state": -4, "un": -5}},
				{"label": "Offer sanctions relief for inspections", "effects": [["crisis", 20], ["us", "approval", -1], ["add", "$C", "relation", 8]], "advisors": {"state": 4, "un": 3, "nsa": -3}},
				{"label": "Tighten the squeeze and wait", "effects": [["crisis", 6]], "advisors": {"treasury": 2, "cia": 1}},
			]
		"famine":
			choices = [
				{"label": "Airlift food now ($2bn)", "effects": [["funds", "aid", -2], ["crisis", 32]], "advisors": {"un": 4, "state": 3, "treasury": -2}},
				{"label": "Rally other donors", "effects": [["chance", 0.6, [["crisis", 20], ["us", "standing", 1]], [["crisis", -4]]]], "advisors": {"un": 2, "treasury": 2}},
				{"label": "Let the agencies cope", "effects": [], "advisors": {"un": -4, "state": -2, "chief": 1}},
			]
		"coup":
			choices = [
				{"label": "Warn the plotters off", "effects": [["chance", 0.55, [["crisis", 24]], [["crisis", -12]]]], "advisors": {"cia": 3, "state": 1}},
				{"label": "Fly in support for the government ($1bn)", "effects": [["funds", "defense", -1], ["crisis", 24]], "advisors": {"defense": 3, "nsa": 2, "treasury": -1}},
				{"label": "Stay out of it", "effects": [], "advisors": {"cia": -3, "state": -2, "chief": 1}},
			]
	var card := {"id": "crisis_final", "speaker": sp, "art": def["art"], "ctx": c["iso"], "crisis": c["id"], "choices": choices}
	Events.system_card(card, "crisis_%s_final" % kind, {"$NAME": String(s.c(c["iso"])["name"]), "$B": String(s.c(c["iso2"]).get("name", ""))})
	s.pending.append(card)
	s.add_log("%s: the decisive month." % c["title"], "headline", c["iso"], 1)


static func _resolve(s: GameState, c: Dictionary, map_data: Dictionary) -> void:
	var iso := String(c["iso"])
	var d := s.c(iso)
	var name := String(d["name"])
	var good := s.rng.randf() * 100.0 < float(c["hand"])
	var u := s.us
	var text := ""
	match String(c["kind"]):
		"hostage":
			if good:
				_us(u, "approval", 4.0)
				_us(u, "standing", 2.0)
				text = "the hostages in %s come home alive" % name
			else:
				_us(u, "approval", -5.0)
				u["scandal"] = float(u["scandal"]) + 5.0
				d["relation"] = clampf(float(d["relation"]) - 10.0, -100.0, 100.0)
				text = "the hostage crisis in %s ends in tragedy" % name
		"standoff":
			var ad := s.c(c["iso2"])
			if good:
				ad["ambition"] = clampf(float(ad["ambition"]) - 15.0, 0.0, 100.0)
				d["relation"] = clampf(float(d["relation"]) + 10.0, -100.0, 100.0)
				_us(u, "credibility", 5.0)
				_us(u, "approval", 2.0)
				text = "%s pulls its forces back from the border of %s" % [ad["name"], name]
			else:
				_us(u, "credibility", -5.0)
				text = "%s crosses the border into %s" % [ad["name"], name]
				s.add_log("CRISIS ENDS BADLY: %s." % text, "war", iso)
				Simulation.start_war(s, c["iso2"], iso, 10.0)
		"breakout":
			if good:
				d["ambition"] = clampf(float(d["ambition"]) - 12.0, 0.0, 100.0)
				d["military"] = clampf(float(d["military"]) - 5.0, 0.0, 100.0)
				_us(u, "standing", 3.0)
				_us(u, "approval", 2.0)
				text = "%s halts its weapons programme" % name
			else:
				d["nuclear"] = true
				_us(u, "standing", -5.0)
				_us(u, "approval", -3.0)
				_us(u, "credibility", -5.0)
				text = "%s tests a nuclear device" % name
		"famine":
			if good:
				d["hunger"] = clampf(float(d["hunger"]) - 20.0, 0.0, 100.0)
				d["relation"] = clampf(float(d["relation"]) + 10.0, -100.0, 100.0)
				_us(u, "standing", 4.0)
				_us(u, "approval", 1.0)
				text = "food reaches %s in time and the famine is averted" % name
			else:
				d["hunger"] = clampf(float(d["hunger"]) + 12.0, 0.0, 100.0)
				d["stability"] = clampf(float(d["stability"]) - 15.0, 0.0, 100.0)
				_us(u, "standing", -4.0)
				text = "famine takes hold in %s" % name
		"coup":
			if good:
				d["stability"] = clampf(float(d["stability"]) + 15.0, 0.0, 100.0)
				d["relation"] = clampf(float(d["relation"]) + 8.0, -100.0, 100.0)
				_us(u, "credibility", 3.0)
				text = "the plot in %s collapses and the government holds" % name
			else:
				_us(u, "approval", -2.0)
				text = "the plotters in %s seize power" % name
				Simulation.regime_change(s, iso, false)
	s.stats["crises_won" if good else "crises_lost"] = int(s.stats.get("crises_won" if good else "crises_lost", 0)) + 1
	if good or String(c["kind"]) != "standoff":
		s.add_log("%s: %s." % ["CRISIS ENDS WELL" if good else "CRISIS ENDS BADLY", text], "headline", iso)
	s.fx.append({"iso": iso, "kind": "victory" if good else "halt", "text": "Crisis over" if good else "Crisis lost"})


static func _us(u: Dictionary, key: String, delta: float) -> void:
	u[key] = clampf(float(u.get(key, 50.0)) + delta, 0.0, 100.0)
