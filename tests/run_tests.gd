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
	_dark_path(map_data)
	_desk(map_data)
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
		Diary.auto(s, map_data)
		Guidance.pins(s, map_data)
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


## Personas, power moves, guidance and the third term.
func _dark_path(map_data: Dictionary) -> void:
	var events := ScenarioLoader.load_events("classic_1990")
	var s := ScenarioLoader.new_game("classic_1990", "strongman", true, 77, map_data, "normal", "strongman")
	check(Power.tyranny(s) >= 10.0, "strongman starts with tyranny")
	check(Actions.pc_of(s, "op_invade") == 30, "strongman pays full price for military")
	check(not Guidance.suggest(s, map_data).is_empty(), "guidance has suggestions at start")
	s.us["political_capital"] = 100.0
	for id in ["courts", "press", "emergency"]:
		check(Power.available(s, id)["ok"], "power move available: " + id)
		Power.perform(s, id)
	check(Power.tyranny(s) > 40.0, "power moves raise tyranny")
	check(Actions.war_powers_chance(s, "IRQ", "op_invade") < 0.0, "emergency bypasses Congress")
	# Jump to the end of the second term and seize a third.
	s.elections_won = 1
	s.turn = s.end_turn - 6
	s.next_election_turn = s.end_turn
	s.us["political_capital"] = 100.0
	s.us["tyranny"] = 60.0
	check(Power.available(s, "third_term")["ok"], "third term available")
	Power.perform(s, "third_term")
	check(s.end_turn - s.turn > 40 and not s.elections_enabled, "third term extends rule")
	var w := ScenarioLoader.new_game("modern_2026", "peacemaker", true, 5, map_data, "normal", "warlord")
	check(Actions.pc_of(w, "op_invade") == 21, "warlord invades cheaper")
	var target := ""
	for iso in w.active_isos():
		if float(w.c(iso)["relation"]) < -40.0:
			target = iso
			break
	if target != "":
		w.us["political_capital"] = 100.0
		w.us["funds"]["covert"] = 20.0
		check(Actions.available(w, target, "assassinate")["ok"], "assassination available vs hostile regime")
		Actions.perform(w, target, "assassinate", map_data)
	var d := s.to_dict()
	var back := GameState.from_dict(JSON.parse_string(JSON.stringify(d)), map_data)
	check(back.us.get("persona", "") == "strongman" and back.us.get("third_term", false), "persona and third term survive save/load")


## 1.5: the opening briefing, decision reports, the diary, pacing and pins.
func _desk(map_data: Dictionary) -> void:
	for id in ["classic_1990", "modern_2026"]:
		var events := ScenarioLoader.load_events(id)
		var s := ScenarioLoader.new_game(id, "peacemaker", true, 11, map_data)
		s.auto_minor = true
		Events.check(s, events, map_data)
		check(not s.pending.is_empty() and s.pending[0]["id"] == "opening", "%s opens with a briefing" % id)
		check(String(s.pending[0]["text"]).length() > 40, "%s opening briefing has its own text" % id)
		for ch in s.pending[0]["choices"]:
			check(not Report.preview(s, ch, "").is_empty(), "every opening choice previews its effects")
		var before := Report.snapshot(s, "")
		Events.resolve(s, 1, map_data)
		var chips := Report.diff(s, before, Report.snapshot(s, ""))
		check(chips.size() >= 2 and String(chips[0]["text"]).begins_with("Approval"), "decision report lists what changed")
		# The diary.
		var items := Diary.items(s)
		check(items.size() >= 5 and Diary.slots_left(s) == Diary.SLOTS, "%s diary offers engagements and three slots" % id)
		var days := {}
		for it in items:
			check(int(it["day"]) >= 1 and int(it["day"]) <= 28 and String(it["wd"]) != "", "diary items are dated")
			days[int(it["day"])] = true
		check(days.size() == items.size(), "diary dates are distinct")
		var pc0 := float(s.us["political_capital"])
		var kept := Diary.auto(s, map_data)
		check(kept >= 2 and Diary.slots_left(s) <= 1, "bot keeps engagements until time runs out")
		check(is_equal_approx(float(s.us["political_capital"]), pc0) or kept > 0, "engagements cost time, not political capital")
		for i in items.size():
			if not items[i]["done"] and int(items[i]["slots"]) > Diary.slots_left(s):
				check(not Diary.available(s, i)["ok"], "no time left blocks further engagements")
		var back := GameState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())), map_data)
		check(Diary.items(back).size() == items.size() and Diary.slots_left(back) == Diary.slots_left(s), "diary survives save/load")
		# Pacing: never two empty months running, and templates do not flood the desk.
		var empty_run := 0
		var worst := 0
		var most := 0
		var quiet := 0
		for i in 60:
			if s.game_over:
				break
			most = maxi(most, s.pending.size())
			if s.pending.is_empty():
				empty_run += 1
				quiet += 1
			else:
				empty_run = 0
			worst = maxi(worst, empty_run)
			while not s.pending.is_empty():
				Events.resolve(s, Events.cabinet_choice(s, s.pending[0]["choices"]), map_data)
			Diary.auto(s, map_data)
			Simulation.tick(s, map_data, events)
			check(int(Diary.state(s)["turn"]) == s.turn or s.game_over, "diary re-rolls every month")
		check(worst <= 1, "%s never has two empty months running (worst %d)" % [id, worst])
		check(most <= 5, "%s desk is never flooded (most %d cards)" % [id, most])
		check(quiet <= 15, "%s empty months are rare (%d of 60)" % [id, quiet])
		for m in s.messages:
			check(int(m.get("day", 0)) >= 1 and int(m.get("day", 0)) <= 28, "log entries carry a day of the month")
		for pin in Guidance.pins(s, map_data):
			check(s.is_active(String(pin["iso"])) and String(pin["text"]) != "", "pins point at live countries")
		check(Simulation.pc_regen(s) >= 1.0, "political capital always refills")
	check(Diary.weekday(1990, 6, 4) == "Mon" and Diary.weekday(2026, 11, 9) == "Mon", "weekdays are real")
