class_name ScenarioLoader
extends RefCounted
## Reads scenario packs from res://data/scenarios/<id>/ and builds a fresh GameState.

const SCENARIO_ROOT := "res://data/scenarios"
const MAP_PATH := "res://data/map/world.json"


static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("Invalid JSON: %s" % path)
	return parsed


static func load_map() -> Dictionary:
	var d: Variant = read_json(MAP_PATH)
	return d if d is Dictionary else {}


static func list_scenarios() -> Array:
	var out: Array = []
	var dir := DirAccess.open(SCENARIO_ROOT)
	if dir == null:
		return out
	for sub in dir.get_directories():
		var meta: Variant = read_json("%s/%s/scenario.json" % [SCENARIO_ROOT, sub])
		if meta is Dictionary:
			out.append(meta)
	out.sort_custom(func(a, b): return a["start"]["year"] < b["start"]["year"])
	return out


static func load_events(scenario_id: String) -> Array:
	var out: Array = []
	var own: Variant = read_json("%s/%s/events.json" % [SCENARIO_ROOT, scenario_id])
	if own is Array:
		out.append_array(own)
	var common: Variant = read_json("%s/common_events.json" % SCENARIO_ROOT)
	if common is Array:
		out.append_array(common)
	return out


static func new_game(scenario_id: String, agenda: String, elections: bool, seed_value: int, map_data: Dictionary, difficulty: String = "normal") -> GameState:
	var base := "%s/%s" % [SCENARIO_ROOT, scenario_id]
	var s := GameState.new()
	s.scenario = read_json(base + "/scenario.json")
	s.countries = read_json(base + "/countries.json")
	var groups: Variant = read_json(base + "/map_groups.json")
	s.groups = groups if groups is Dictionary else {}
	s.year = int(s.scenario["start"]["year"])
	s.month = int(s.scenario["start"]["month"])
	s.agenda = agenda
	s.difficulty = difficulty
	s.elections_enabled = elections
	s.next_election_turn = int(s.scenario.get("first_election_in_months", 24))
	s.end_turn = s.next_election_turn + 48
	s.rng_seed = seed_value
	s.rng.seed = seed_value

	var u: Dictionary = s.scenario["us"]
	s.us = {
		"approval": float(u["approval"]),
		"political_capital": float(u["political_capital"]),
		"congress": float(u["congress"]),
		"budget": (u["budget"] as Dictionary).duplicate(),
		"budget_baseline": (u["budget"] as Dictionary).duplicate(),
		"deficit_pct_baseline": float(u["deficit_pct_baseline"]),
		"gdp": float(u["gdp"]),
		"funds": {"aid": 2.0, "covert": 1.0, "defense": 3.0, "domestic": 5.0},
		"scandal": 0.0,
		"standing": 60.0,
		"treaties": 0,
		"peace_months": 0,
		"troops": {},
		"ops": [],
		"mood": 0.0,
	}
	for iso in s.countries:
		var d: Dictionary = s.countries[iso]
		d["sanctioned"] = false
		d["trade_deal"] = false
		d["covert_pressure"] = 0.0
		d["aid_boost"] = 0.0
		d["us_backed"] = false
		d["rival_pull"] = 0.0
		d["rival_bloc"] = ""
	for w in s.scenario.get("wars", []):
		s.wars.append({"a": w["a"], "b": w["b"], "progress": float(w.get("progress", 0)), "months": int(w.get("months", 0))})
	s.advisors = Advisors.initial_cabinet()
	s.recompute_map_owner(map_data)
	s.capture_baseline()
	s.record_history()
	s.add_log("You take office. %s." % s.scenario.get("name", ""), "headline")
	return s
