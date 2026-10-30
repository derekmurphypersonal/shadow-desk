extends SceneTree
## Prints the event log of a no-action playthrough: godot --headless --path . -s tests/debug_log.gd -- <scenario> <seed>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "classic_1990"
	var seed_value: int = int(args[1]) if args.size() > 1 else 1
	var map_data := ScenarioLoader.load_map()
	var s := ScenarioLoader.new_game(id, "peacemaker", false, seed_value, map_data)
	var ev := ScenarioLoader.load_events(id)
	Events.check(s, ev, map_data)
	for i in 80:
		while not s.pending.is_empty():
			Events.resolve(s, 0, map_data)
		Simulation.tick(s, map_data, ev)
		if s.game_over:
			break
	for m in s.messages:
		print(m["date"], "  ", m["text"])
	print("approval ", s.us["approval"], " pc ", s.us["political_capital"], " funds ", s.us["funds"])
	quit()
