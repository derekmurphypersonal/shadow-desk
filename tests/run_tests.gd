extends SceneTree
## Headless smoke tests: godot --headless --path . -s tests/run_tests.gd

var failures := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)


func _init() -> void:
	var map_data := ScenarioLoader.load_map()
	check(map_data.get("countries", {}).size() > 150, "map loads")
	var scenarios := ScenarioLoader.list_scenarios()
	check(scenarios.size() == 2, "two scenarios")
	for meta in scenarios:
		for seed_value in [1, 2, 3]:
			_run(meta["id"], seed_value, map_data)
	_determinism(map_data)
	_save_roundtrip(map_data)
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _play(s: GameState, events: Array, map_data: Dictionary, turns: int) -> void:
	Events.check(s, events, map_data)
	for i in turns:
		while not s.pending.is_empty():
			Events.resolve(s, s.rng.randi_range(0, s.pending[0]["choices"].size() - 1), map_data)
		# A few random actions each month, like a player would.
		var targets := s.active_isos()
		for k in 3:
			var iso: String = targets[s.rng.randi_range(0, targets.size() - 1)]
			var id: String = Actions.ORDER[s.rng.randi_range(0, Actions.ORDER.size() - 1)]
			if Actions.available(s, iso, id)["ok"]:
				Actions.perform(s, iso, id, map_data)
		Advisors.advise(s, targets[0], map_data)
		Simulation.tick(s, map_data, events)
		if s.game_over:
			break


func _run(id: String, seed_value: int, map_data: Dictionary) -> void:
	var s := ScenarioLoader.new_game(id, "humanitarian", true, seed_value, map_data)
	var events := ScenarioLoader.load_events(id)
	_play(s, events, map_data, 120)
	for iso in s.countries:
		var d: Dictionary = s.countries[iso]
		for k in ["stability", "freedom", "military", "hunger", "ambition"]:
			check(float(d[k]) >= 0.0 and float(d[k]) <= 100.0, "%s %s.%s in range (%s)" % [id, iso, k, d[k]])
		check(float(d["relation"]) >= -100.0 and float(d["relation"]) <= 100.0, "%s %s relation" % [id, iso])
		check(float(d["gdp"]) > 0.0 and is_finite(float(d["gdp"])), "%s %s gdp finite" % [id, iso])
	for map_iso in s.map_owner:
		check(s.countries.has(s.map_owner[map_iso]), "%s map owner %s exists" % [id, map_iso])
	print("%s seed %d: turn %d %s | approval %d | wars %d | log %d | ending=%s %s" % [id, seed_value, s.turn, s.date_string(), int(s.us["approval"]), s.wars.size(), s.messages.size(), s.ending, s.ending_text])


func _determinism(map_data: Dictionary) -> void:
	var a := ScenarioLoader.new_game("classic_1990", "peacemaker", true, 42, map_data)
	var b := ScenarioLoader.new_game("classic_1990", "peacemaker", true, 42, map_data)
	var ev := ScenarioLoader.load_events("classic_1990")
	_play(a, ev, map_data, 30)
	_play(b, ev, map_data, 30)
	check(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "same seed -> same game")


func _save_roundtrip(map_data: Dictionary) -> void:
	var s := ScenarioLoader.new_game("modern_2026", "hegemon", true, 7, map_data)
	var ev := ScenarioLoader.load_events("modern_2026")
	_play(s, ev, map_data, 10)
	var text := JSON.stringify(s.to_dict())
	var r := GameState.from_dict(JSON.parse_string(text), map_data)
	_play(s, ev, map_data, 10)
	_play(r, ev, map_data, 10)
	check(s.turn == r.turn and int(s.us["approval"]) == int(r.us["approval"]), "save/load continues identically")
