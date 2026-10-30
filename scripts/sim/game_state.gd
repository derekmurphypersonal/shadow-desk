class_name GameState
extends RefCounted
## The whole simulation state. Plain Dictionaries and Arrays so it serialises to JSON as-is.
## Nothing in here touches the scene tree, so it runs headless in tests.

const SAVE_VERSION := 2
const DIFFICULTY := {
	"easy": {"pc": 1.3, "approval": 4.0, "rival": 0.6, "risk": 0.5, "challenger": -2.0, "label": "Chief of Staff (easy)"},
	"normal": {"pc": 1.0, "approval": 0.0, "rival": 1.0, "risk": 1.0, "challenger": 0.0, "label": "President (normal)"},
	"hard": {"pc": 0.75, "approval": -6.0, "rival": 1.4, "risk": 1.5, "challenger": 5.0, "label": "Lame Duck (hard)"},
}

var scenario: Dictionary = {}          # scenario.json contents
var countries: Dictionary = {}         # iso -> country Dictionary
var groups: Dictionary = {}            # group iso -> Array of map isos (1990 USSR etc.)
var map_owner: Dictionary = {}         # map polygon iso -> controlling country iso
var us: Dictionary = {}                # player state
var advisors: Array = []               # Array of advisor Dictionaries
var wars: Array = []                   # {a, b, progress, months}
var messages: Array = []                 # {turn, date, text, kind}
var pending: Array = []                # event cards awaiting a decision
var fired_events: Dictionary = {}      # event id -> turn fired
var year: int = 1990
var month: int = 1
var turn: int = 0
var agenda: String = "peacemaker"
var difficulty: String = "normal"
var history: Array = []                # one snapshot per month for charts
var last_election: Dictionary = {}     # {vote, won, turn} for the election-night screen
var elections_enabled: bool = true
var next_election_turn: int = 24
var end_turn: int = 72
var elections_won: int = 0
var game_over: bool = false
var ending: String = ""
var ending_text: String = ""
var baseline: Dictionary = {}          # agenda baselines captured at start
var score: float = 0.0
var resignations: Array = []           # turns on which advisors resigned
var rng_seed: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var fx: Array = []                     # transient visual cues for the UI (not saved)
var auto_minor := false                # cabinet resolves minor events automatically


func c(iso: String) -> Dictionary:
	return countries.get(iso, {})


func is_active(iso: String) -> bool:
	var d: Dictionary = countries.get(iso, {})
	return not d.is_empty() and not d.get("dormant", false) and not d.get("player", false)


func active_isos() -> Array:
	var out: Array = []
	for iso in countries:
		if is_active(iso):
			out.append(iso)
	return out


func date_string() -> String:
	return "%s %d" % [month_name(month), year]


static func month_name(m: int) -> String:
	return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][m - 1]


func date_key() -> String:
	return "%04d-%02d" % [year, month]


func diff(key: String) -> float:
	return float(DIFFICULTY.get(difficulty, DIFFICULTY["normal"])[key])


func turn_headlines(t: int = -1, since: int = -1) -> Array:
	## Log entries from one turn (default: the latest), or from turns since..t, for the digest.
	if t < 0:
		t = turn
	if since < 0:
		since = t
	var out: Array = []
	for m in messages:
		if int(m["turn"]) >= since and int(m["turn"]) <= t and m["kind"] in ["headline", "war", "scandal", "cabinet"]:
			out.append(m)
	out.sort_custom(func(a, b): return is_big_news(a) and not is_big_news(b))
	return out


static func is_big_news(m: Dictionary) -> bool:
	if m["kind"] in ["war", "scandal"]:
		return true
	var tx := String(m["text"])
	for key in ["WAR", "ELECTION", "MIDTERMS", "VICTORY", "Coup", "coup", "dissolves", "partnership", "invasion", "defeats", "repels", "ceasefire", "resigns", "Civil war", "assassination", "Western camp", "breaks with"]:
		if tx.contains(key):
			return true
	return false


func record_history() -> void:
	history.append({
		"turn": turn, "date": date_string(), "approval": float(us["approval"]),
		"standing": float(us.get("standing", 50.0)), "pc": float(us["political_capital"]),
		"hunger": world_weighted("hunger"), "freedom": world_weighted("freedom"),
		"wars": wars.size(), "score": agenda_score(), "friendly_gdp": friendly_gdp_share(),
	})
	if history.size() > 200:
		history = history.slice(history.size() - 200)


func has_system(sys_name: String) -> bool:
	return sys_name in scenario.get("systems", [])


func cost_scale() -> float:
	return float(scenario.get("cost_scale", 1.0))


func add_log(text: String, kind: String = "info") -> void:
	messages.append({"turn": turn, "date": date_string(), "text": text, "kind": kind})
	if messages.size() > 400:
		messages = messages.slice(messages.size() - 400)


func war_for(iso: String) -> Dictionary:
	for w in wars:
		if w["a"] == iso or w["b"] == iso:
			return w
	return {}


func at_war(iso: String) -> bool:
	return not war_for(iso).is_empty()


func enemy_of(iso: String) -> String:
	var w := war_for(iso)
	if w.is_empty():
		return ""
	return w["b"] if w["a"] == iso else w["a"]


func advisor(id: String) -> Dictionary:
	for a in advisors:
		if a["id"] == id:
			return a
	return {}


func neighbors_of(iso: String, map_data: Dictionary) -> Array:
	## Neighbours by current control: union of the map polygons this country controls.
	var out: Array = []
	var mc: Dictionary = map_data.get("countries", {})
	for map_iso in map_owner:
		if map_owner[map_iso] != iso:
			continue
		for n in mc.get(map_iso, {}).get("neighbors", []):
			var owner: String = map_owner.get(n, "")
			if owner != "" and owner != iso and not out.has(owner):
				out.append(owner)
	return out


func recompute_map_owner(map_data: Dictionary) -> void:
	map_owner.clear()
	var member_of := {}
	for g in groups:
		if is_group_intact(g):
			for m in groups[g]:
				member_of[m] = g
	for map_iso in map_data.get("countries", {}):
		var owner: String = map_data["countries"][map_iso].get("owner", map_iso)
		if member_of.has(owner):
			owner = member_of[owner]
		var d: Dictionary = countries.get(owner, {})
		if d.has("fold_into") and d.get("dormant", false):
			owner = d["fold_into"]
		map_owner[map_iso] = owner


func is_group_intact(g: String) -> bool:
	var d: Dictionary = countries.get(g, {})
	return not d.is_empty() and not d.get("dissolved", false)


# ---- Aggregates used by agendas and UI ----

func world_weighted(stat: String) -> float:
	var total := 0.0
	var pop := 0.0
	for iso in active_isos():
		var d: Dictionary = countries[iso]
		total += float(d[stat]) * float(d["pop"])
		pop += float(d["pop"])
	return total / maxf(pop, 1.0)


func friendly_gdp_share() -> float:
	var friendly := float(us.get("gdp", 0.0))
	var total := friendly
	for iso in active_isos():
		var g := float(countries[iso]["gdp"])
		total += g
		if float(countries[iso]["relation"]) >= 50.0:
			friendly += g
	return 100.0 * friendly / maxf(total, 1.0)


func capture_baseline() -> void:
	baseline = {
		"hunger": world_weighted("hunger"),
		"freedom": world_weighted("freedom"),
		"friendly_gdp": friendly_gdp_share(),
	}


func agenda_score() -> float:
	match agenda:
		"peacemaker":
			return float(us.get("peace_months", 0)) + 5.0 * float(us.get("treaties", 0))
		"humanitarian":
			return 10.0 * (float(baseline.get("hunger", 0.0)) - world_weighted("hunger"))
		"democratiser":
			return 10.0 * (world_weighted("freedom") - float(baseline.get("freedom", 0.0)))
		"hegemon":
			return 10.0 * (friendly_gdp_share() - float(baseline.get("friendly_gdp", 0.0)))
	return 0.0


func legacy_points() -> float:
	## History's verdict on the presidency, used for the end-of-game grade.
	var base := {"retired": 55.0, "defeated": 35.0, "cabinet": 20.0, "impeached": 10.0, "assassinated": 30.0, "nuclear": 0.0}
	var pts := float(base.get(ending, 30.0))
	pts += clampf(agenda_score() / 3.0, -20.0, 30.0)
	pts += (float(us["approval"]) - 50.0) * 0.4
	pts += (float(us.get("standing", 50.0)) - 50.0) * 0.2
	pts += float(elections_won) * 5.0
	pts += {"easy": -5.0, "normal": 0.0, "hard": 8.0}.get(difficulty, 0.0)
	return pts


func grade() -> String:
	var pts := legacy_points()
	for pair in [[95.0, "A+"], [85.0, "A"], [72.0, "B"], [58.0, "C"], [45.0, "D"]]:
		if pts >= pair[0]:
			return pair[1]
	return "F"


# ---- Serialisation ----

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "scenario": scenario, "countries": countries, "groups": groups,
		"us": us, "advisors": advisors, "wars": wars, "messages": messages, "pending": pending,
		"fired_events": fired_events, "year": year, "month": month, "turn": turn,
		"agenda": agenda, "difficulty": difficulty, "history": history, "last_election": last_election,
		"elections_enabled": elections_enabled,
		"next_election_turn": next_election_turn, "end_turn": end_turn,
		"elections_won": elections_won, "game_over": game_over, "ending": ending,
		"ending_text": ending_text, "baseline": baseline, "resignations": resignations,
		"rng_seed": rng_seed, "rng_state": str(rng.state),
	}


static func from_dict(d: Dictionary, map_data: Dictionary) -> GameState:
	var s := GameState.new()
	s.scenario = d["scenario"]
	s.countries = d["countries"]
	s.groups = d["groups"]
	s.us = d["us"]
	s.advisors = d["advisors"]
	s.wars = d["wars"]
	s.messages = d["messages"]
	s.pending = d["pending"]
	s.fired_events = d["fired_events"]
	s.year = int(d["year"])
	s.month = int(d["month"])
	s.turn = int(d["turn"])
	s.agenda = d["agenda"]
	s.difficulty = d.get("difficulty", "normal")
	s.history = d.get("history", [])
	s.last_election = d.get("last_election", {})
	s.elections_enabled = d["elections_enabled"]
	s.next_election_turn = int(d["next_election_turn"])
	s.end_turn = int(d["end_turn"])
	s.elections_won = int(d["elections_won"])
	s.game_over = d["game_over"]
	s.ending = d["ending"]
	s.ending_text = d["ending_text"]
	s.baseline = d["baseline"]
	s.resignations = d["resignations"]
	s.rng_seed = int(d["rng_seed"])
	s.rng.seed = s.rng_seed
	s.rng.state = int(d["rng_state"])
	s.recompute_map_owner(map_data)
	return s
