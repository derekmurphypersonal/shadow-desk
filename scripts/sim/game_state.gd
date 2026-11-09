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
var mandates: Array = []               # this term's goals (see Mandates)
var stats: Dictionary = {}             # counters for achievements
var flags: Dictionary = {}             # story flags set by event choices
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
	for key in ["MANDATE MET", "treaty ally", "WAR", "ELECTION", "MIDTERMS", "VICTORY", "Coup", "coup", "dissolves", "partnership", "invasion", "defeats", "repels", "ceasefire", "resigns", "Civil war", "assassination", "Western camp", "breaks with"]:
		if tx.contains(key):
			return true
	return false


func record_history() -> void:
	history.append({
		"turn": turn, "date": date_string(), "approval": float(us["approval"]),
		"standing": float(us.get("standing", 50.0)), "pc": float(us["political_capital"]),
		"hunger": world_weighted("hunger"), "freedom": world_weighted("freedom"),
		"wars": wars.size(), "score": agenda_score(), "friendly_gdp": friendly_gdp_share(),
		"tyranny": float(us.get("tyranny", 0.0)),
	})
	stats["max_tyranny"] = maxf(float(stats.get("max_tyranny", 0.0)), float(us.get("tyranny", 0.0)))
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
		"strongman":
			return float(us.get("grip", 0.0)) + 8.0 * elections_won + (25.0 if us.get("third_term", false) else 0.0)
	return 0.0


func legacy_points() -> float:
	## History's verdict on the presidency, used for the end-of-game grade.
	var base := {"retired": 55.0, "defeated": 35.0, "cabinet": 20.0, "impeached": 10.0, "assassinated": 30.0, "nuclear": 0.0,
		"deposed": 5.0, "resigned": 15.0, "dictator": 25.0}
	var pts := float(base.get(ending, 30.0))
	pts += clampf(agenda_score() / 3.0, -20.0, 30.0)
	pts += (float(us["approval"]) - 50.0) * 0.4
	pts += (float(us.get("standing", 50.0)) - 50.0) * 0.2
	pts += float(elections_won) * 5.0
	pts += {"easy": -5.0, "normal": 0.0, "hard": 8.0}.get(difficulty, 0.0)
	pts += float(stats.get("mandates_done", 0)) * 2.5
	pts -= float(stats.get("pact_betrayals", 0)) * 4.0
	if agenda != "strongman":
		pts -= float(us.get("tyranny", 0.0)) * 0.2
	return pts


## Achievements earned by a finished (or running) presidency: [id, title, description].
const ACHIEVEMENTS := [
	["two_terms", "Four more years", "Win re-election."],
	["a_plus", "For the history books", "Finish with an A or A+ from history."],
	["hard_win", "Lame duck, my foot", "Serve out both terms on Hard."],
	["peace", "Peace in our time", "Sign 6 peace deals or treaties in one presidency."],
	["mandates", "Promises kept", "Meet 5 term mandates in one presidency."],
	["allies", "Hearts and minds", "Have 25 countries with relations of 60 or more."],
	["hegemon", "Unipolar moment", "Bring the friendly share of world GDP to 75%."],
	["liberator", "Nation builder", "Win an invasion."],
	["kuwait", "Desert Storm", "Liberate Kuwait."],
	["clean", "Clean hands", "Serve out your presidency without a single covert operation."],
	["teflon", "Teflon president", "Survive impeachment hearings."],
	["pacts", "Arsenal of democracy", "Hold 5 defence pacts at once."],
	["credible", "A man of his word", "Honour every defence pact that was tested (at least one)."],
	["famine", "Bread, not bombs", "Cut world hunger by 4 points (population-weighted)."],
	["survivor", "Still standing", "Survive an assassination attempt."],
	["for_life", "President for life", "Seize a third term and rule to its end."],
	["restored", "The republic endures", "Bring tyranny from 40 or more back below 5 and finish your presidency."],
]


func earned_achievements() -> Array:
	var out: Array = []
	var served := ending == "retired"
	var allies := 0
	var pacts := 0
	for iso in active_isos():
		if float(countries[iso]["relation"]) >= 60.0:
			allies += 1
		if countries[iso].get("pact", false):
			pacts += 1
	var checks := {
		"two_terms": elections_won >= 1,
		"a_plus": game_over and grade() in ["A", "A+"],
		"hard_win": served and difficulty == "hard",
		"peace": int(us.get("treaties", 0)) >= 6,
		"mandates": int(stats.get("mandates_done", 0)) >= 5,
		"allies": allies >= 25,
		"hegemon": friendly_gdp_share() >= 75.0,
		"liberator": int(stats.get("invasions_won", 0)) >= 1,
		"kuwait": flags.has("kuwait_liberated"),
		"clean": served and int(stats.get("covert", 0)) == 0,
		"teflon": int(stats.get("impeach_survived", 0)) >= 1,
		"pacts": int(stats.get("max_pacts", 0)) >= 5 or pacts >= 5,
		"credible": int(stats.get("pact_tests", 0)) >= 1 and int(stats.get("pact_betrayals", 0)) == 0,
		"famine": float(baseline.get("hunger", 0.0)) - world_weighted("hunger") >= 4.0,
		"survivor": int(stats.get("attempts_survived", 0)) >= 1,
		"for_life": ending == "dictator",
		"restored": served and float(stats.get("max_tyranny", 0.0)) >= 40.0 and float(us.get("tyranny", 0.0)) < 5.0,
	}
	for a in ACHIEVEMENTS:
		if checks.get(a[0], false):
			out.append(a)
	return out


func grade() -> String:
	var pts := legacy_points()
	for pair in [[103.0, "A+"], [92.0, "A"], [78.0, "B"], [62.0, "C"], [48.0, "D"]]:
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
		"mandates": mandates, "stats": stats, "flags": flags,
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
	s.mandates = d.get("mandates", [])
	s.stats = d.get("stats", {})
	s.flags = d.get("flags", {})
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
