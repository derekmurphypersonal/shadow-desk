extends SceneTree
## Playability telemetry: plays the guided bot and reports how much each month asks of the player.
## godot --headless --path . -s tests/telemetry.gd -- [seeds]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 8
	var map_data := ScenarioLoader.load_map()
	for scen in ["classic_1990", "modern_2026"]:
		var events := ScenarioLoader.load_events(scen)
		for auto_minor in [true, false]:
			var months := 0
			var cards := 0
			var card_hist := {}
			var zero_card := 0
			var quiet := 0          # no card and no big news
			var longest_quiet := 0
			var acts := 0
			var act_hist := {}
			var pc_start := 0.0
			var pc_regen := 0.0
			var afford := 0.0       # distinct action types affordable on PC alone
			var headlines := 0
			var big := 0
			var steps := 0
			var steps_same := 0
			var first12_cards := 0
			var first12_months := 0
			var act_kinds := {}
			var diary_offered := 0
			var diary_done := 0
			for sd in seeds:
				var s := ScenarioLoader.new_game(scen, "peacemaker", true, 1000 + sd, map_data, "normal", "statesman")
				s.auto_minor = auto_minor
				Events.check(s, events, map_data)
				var run := 0
				var prev_titles := []
				while not s.game_over and s.turn < 200:
					months += 1
					var n := s.pending.size()
					while not s.pending.is_empty():
						Events.resolve(s, Events.cabinet_choice(s, s.pending[0]["choices"]), map_data)
					# cards can chain; count resolved
					cards += n
					card_hist[n] = card_hist.get(n, 0) + 1
					if s.turn < 12:
						first12_cards += n
						first12_months += 1
					var hl := s.turn_headlines()
					headlines += hl.size()
					var bign := 0
					for m in hl:
						if GameState.is_big_news(m):
							bign += 1
					big += bign
					if n == 0:
						zero_card += 1
					if n == 0 and bign == 0:
						run += 1
						quiet += 1
						longest_quiet = maxi(longest_quiet, run)
					else:
						run = 0
					diary_offered += Diary.items(s).size()
					diary_done += Diary.auto(s, map_data)
					var pc := float(s.us["political_capital"])
					pc_start += pc
					var sug := Guidance.suggest(s, map_data, 3)
					steps += sug.size()
					var titles := []
					for it in sug:
						titles.append(it["title"])
						if it["title"] in prev_titles:
							steps_same += 1
					prev_titles = titles
					var done := 0
					for it in Guidance.suggest(s, map_data, 6):
						if done >= 3:
							break
						var iso := String(it["iso"])
						var act := String(it["action"])
						if iso != "" and act != "" and Actions.available(s, iso, act)["ok"]:
							Actions.perform(s, iso, act, map_data)
							act_kinds[act] = act_kinds.get(act, 0) + 1
							done += 1
					acts += done
					act_hist[done] = act_hist.get(done, 0) + 1
					var before := float(s.us["political_capital"])
					Simulation.tick(s, map_data, events)
					pc_regen += float(s.us["political_capital"]) - before
			var m := float(months)
			print("\n== %s  cabinet handles minor events: %s  (%d seeds, %d months)" % [scen, auto_minor, seeds, months])
			print("briefing cards per month: %.2f   months with no card: %.0f%%   cards histogram %s" % [cards / m, 100.0 * zero_card / m, str(card_hist)])
			print("first 12 months: %.2f cards a month" % (float(first12_cards) / maxf(first12_months, 1)))
			print("quiet months (no card, no big news): %.0f%%   longest quiet run: %d months" % [100.0 * quiet / m, longest_quiet])
			print("headlines per month: %.2f (big: %.2f)" % [headlines / m, big / m])
			print("guided actions per month: %.2f   histogram %s   kinds %s" % [acts / m, str(act_hist), str(act_kinds)])
			print("diary: %.1f engagements offered, %.1f kept per month" % [diary_offered / m, diary_done / m])
			print("PC at start of month: %.0f   net PC change per month incl. upkeep: %+.1f" % [pc_start / m, pc_regen / m])
			print("next steps shown: %.2f per month; %.0f%% were already shown the month before" % [steps / m, 100.0 * steps_same / maxf(steps, 1)])
	quit()
