extends SceneTree
## Strategy-bot playtests for balancing: godot --headless --path . -s tests/balance.gd -- [seeds] [difficulty]

const BOTS := ["passive", "diplomat", "hawk", "balanced", "interventionist"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 12
	var diff: String = args[1] if args.size() > 1 else "normal"
	var map_data := ScenarioLoader.load_map()
	for scen in ["classic_1990", "modern_2026"]:
		var events := ScenarioLoader.load_events(scen)
		for bot in BOTS:
			var endings := {}
			var score := 0.0
			var appr := 0.0
			var grade := 0.0
			var months := 0.0
			for sd in seeds:
				var s := ScenarioLoader.new_game(scen, "peacemaker" if bot != "hawk" else "hegemon", true, 1000 + sd, map_data, diff)
				Events.check(s, events, map_data)
				while not s.game_over and s.turn < 200:
					while not s.pending.is_empty():
						Events.resolve(s, _choose(s, bot), map_data)
					_act(s, bot, map_data)
					Simulation.tick(s, map_data, events)
				endings[s.ending] = endings.get(s.ending, 0) + 1
				score += s.agenda_score()
				appr += float(s.us["approval"])
				grade += s.legacy_points()
				months += s.turn
			print("%-13s %-9s endings=%s  score=%.0f  approval=%.0f  legacy=%.0f  months=%.0f" % [scen, bot, str(endings), score / seeds, appr / seeds, grade / seeds, months / seeds])
	quit()


func _choose(s: GameState, bot: String) -> int:
	var card: Dictionary = s.pending[0]
	var choices: Array = card["choices"]
	if bot == "passive":
		return choices.size() - 1
	var best := 0
	var best_v := -1e9
	for i in choices.size():
		var v := 0.0
		var adv: Dictionary = choices[i].get("advisors", {})
		for id in adv:
			var w := 1.0
			if bot == "hawk" and id in ["defense", "nsa", "cia"]:
				w = 2.0
			if bot == "diplomat" and id in ["state", "un"]:
				w = 2.0
			v += float(adv[id]) * w
		if v > best_v:
			best_v = v
			best = i
	return best


func _try(s: GameState, iso: String, id: String, map_data: Dictionary) -> bool:
	if Actions.available(s, iso, id)["ok"]:
		Actions.perform(s, iso, id, map_data)
		return true
	return false


func _act(s: GameState, bot: String, map_data: Dictionary) -> void:
	if bot == "passive":
		return
	var isos := s.active_isos()
	# Budget: balanced and diplomat nudge domestic spending up modestly.
	if bot in ["balanced", "diplomat"] and s.turn == 0:
		s.us["budget"]["domestic"] = float(s.us["budget_baseline"]["domestic"]) * 1.08
	var acted := 0
	for iso in isos:
		if acted >= 3:
			break
		var d: Dictionary = s.countries[iso]
		match bot:
			"diplomat":
				if s.at_war(iso) and _try(s, iso, "peace", map_data):
					acted += 1
				elif float(d.get("rival_pull", 0.0)) >= 15.0 and _try(s, iso, "envoy", map_data):
					acted += 1
				elif float(d["hunger"]) > 55.0 and _try(s, iso, "aid", map_data):
					acted += 1
			"hawk":
				if float(d["relation"]) < -50.0 and float(d["stability"]) < 40.0 and _try(s, iso, "coup", map_data):
					acted += 1
				elif float(d["terror"]) > 60.0 and _try(s, iso, "strike", map_data):
					acted += 1
				elif float(d["relation"]) > 40.0 and float(d["military"]) < 50.0 and _try(s, iso, "arms", map_data):
					acted += 1
			"interventionist":
				if float(d["relation"]) < -40.0 and not d["nuclear"] and _try(s, iso, "op_invade", map_data):
					acted += 1
				elif s.at_war(iso) and float(d["relation"]) > 20.0 and _try(s, iso, "op_support", map_data):
					acted += 1
				elif float(d["hunger"]) > 60.0 and _try(s, iso, "op_aid", map_data):
					acted += 1
				elif float(d.get("rival_pull", 0.0)) >= 15.0 and _try(s, iso, "op_influence", map_data):
					acted += 1
			"balanced":
				if s.at_war(iso) and float(d["relation"]) > 40.0 and _try(s, iso, "deploy", map_data):
					acted += 1
				elif s.at_war(iso) and _try(s, iso, "peace", map_data):
					acted += 1
				elif float(d.get("rival_pull", 0.0)) >= 15.0 and _try(s, iso, "envoy", map_data):
					acted += 1
				elif float(d["relation"]) > 30.0 and not d["trade_deal"] and float(d["gdp"]) > 300.0 and _try(s, iso, "trade", map_data):
					acted += 1
				elif float(d["hunger"]) > 60.0 and _try(s, iso, "aid", map_data):
					acted += 1
