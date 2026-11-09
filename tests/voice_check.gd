extends SceneTree
## Checks that every decision card has a full set of voice recordings for its speaker and the
## Chief of Staff (who stands in when a seat is vacant), for every country it could name.
## godot --headless --path . -s tests/voice_check.gd

func _init() -> void:
	await process_frame
	var audio = root.get_node("Audio")
	var names := {}
	for sc in ["classic_1990", "modern_2026"]:
		var cj = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/%s/countries.json" % sc))
		for iso in cj:
			names[String(cj[iso]["name"])] = true
	var cards: Array = []
	for f in ["common_events.json", "classic_1990/events.json", "modern_2026/events.json"]:
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/" + f))
		if d is Dictionary:
			d = d.get("events", [])
		for ev in d:
			if ev.get("choices", []).is_empty():
				continue
			cards.append([String(ev.get("speaker", "nsa")), String(ev.get("title", "")), String(ev.get("text", ""))])
	var sys = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/system_cards.json"))
	for k in sys:
		cards.append([String(sys[k].get("speaker", "nsa")), String(sys[k]["title"]), String(sys[k]["text"])])
	var missing := 0
	var checked := 0
	var name_list := names.keys()
	for c in cards:
		for seat in [c[0], "chief"]:
			for i in 3:
				var n: String = name_list[(checked * 7 + i * 13) % name_list.size()]
				var card := {"title": c[1], "text": c[2], "voice": {"title": c[1], "text": c[2], "vars": {"$NAME": n, "$B": n}}}
				checked += 1
				if audio._clips_for(card, seat).is_empty():
					missing += 1
					if missing <= 10:
						print("MISSING [%s] %s / %s" % [seat, c[1], n])
	for n in name_list:
		for seat in Advisors.ORDER:
			if audio._clip(seat, audio.normalize(n)) == null:
				missing += 1
				if missing <= 20:
					print("MISSING NAME [%s] %s" % [seat, n])
	print("voice check: %d cards x seats checked, %d missing" % [checked, missing])
	print("RESULT: %s" % ("PASS" if missing == 0 else "FAIL"))
	quit(0 if missing == 0 else 1)
