class_name Events
extends RefCounted
## Data-driven events. Scripted events fire on dates or conditions; template events pick a
## matching country at random. Events with choices become decision cards in s.pending.

const COUNTRY_RANGES := {
	"relation": [-100.0, 100.0], "stability": [0.0, 100.0], "freedom": [0.0, 100.0],
	"military": [0.0, 100.0], "hunger": [0.0, 100.0], "ambition": [0.0, 100.0], "terror": [0.0, 100.0],
}
const TEMPLATE_COOLDOWN := 6


const MAX_CARDS := 2          # template events stop adding briefing cards beyond this many a month


static func check(s: GameState, events: Array, map_data: Dictionary) -> void:
	if s.turn == 0 and not s.fired_events.has("opening"):
		_opening(s)
	var templates_fired := 0
	# Pacing: the longer the desk has been empty, the likelier something lands on it.
	var drought := int(s.us.get("quiet", 0))
	var boost := 1.0 + 0.6 * float(drought)
	for ev in events:
		if ev.has("system") and not s.has_system(ev["system"]):
			continue
		if ev.get("template", false):
			if templates_fired >= 2:
				continue
			var is_card: bool = not (ev.get("minor", false) and s.auto_minor)
			if is_card and s.pending.size() >= MAX_CARDS:
				continue
			if s.fired_events.has(ev["id"]) and s.turn - int(s.fired_events[ev["id"]]) < TEMPLATE_COOLDOWN:
				continue
			if s.rng.randf() >= float(ev.get("chance", 0.1)) * (boost if is_card else 1.0):
				continue
			var candidates: Array = []
			for iso in s.active_isos():
				var key := "%s@%s" % [ev["id"], iso]
				if s.fired_events.has(key) and s.turn - int(s.fired_events[key]) < 36:
					continue
				if conditions_met(s, ev.get("if", []), iso):
					candidates.append(iso)
			if candidates.is_empty():
				continue
			var iso: String = candidates[s.rng.randi_range(0, candidates.size() - 1)]
			s.fired_events["%s@%s" % [ev["id"], iso]] = s.turn
			fire(s, ev, iso, map_data)
			templates_fired += 1
			continue
		var repeat := int(ev.get("repeat", 0))
		if s.fired_events.has(ev["id"]):
			if repeat <= 0 or s.turn - int(s.fired_events[ev["id"]]) < repeat:
				continue
		var when: Dictionary = ev.get("when", {})
		var key := s.date_key()
		if when.has("date") and when["date"] != key:
			continue
		if when.has("after") and key < String(when["after"]):
			continue
		if not conditions_met(s, when.get("if", []), ""):
			continue
		if when.has("chance") and s.rng.randf() >= float(when["chance"]):
			continue
		fire(s, ev, "", map_data)
	if s.pending.is_empty() and s.turn > 0:
		_break_drought(s, events, map_data, drought >= 1)


## Nothing on the desk this month: usually bring an eligible event forward as a real briefing,
## and always do so if last month was empty too. Keeps quiet months rare and never back to back.
static func _break_drought(s: GameState, events: Array, map_data: Dictionary, force: bool) -> void:
	if not force and s.rng.randf() > 0.8:
		return
	var options: Array = []
	for ev in events:
		if not ev.get("template", false) or ev.get("choices", []).is_empty():
			continue
		if ev.has("system") and not s.has_system(ev["system"]):
			continue
		if s.fired_events.has(ev["id"]) and s.turn - int(s.fired_events[ev["id"]]) < 3:
			continue
		options.append(ev)
	while not options.is_empty():
		var ev: Dictionary = options.pop_at(s.rng.randi_range(0, options.size() - 1))
		var candidates: Array = []
		for iso in s.active_isos():
			var key := "%s@%s" % [ev["id"], iso]
			if s.fired_events.has(key) and s.turn - int(s.fired_events[key]) < 36:
				continue
			if conditions_met(s, ev.get("if", []), iso):
				candidates.append(iso)
		if candidates.is_empty():
			continue
		var iso: String = candidates[s.rng.randi_range(0, candidates.size() - 1)]
		s.fired_events["%s@%s" % [ev["id"], iso]] = s.turn
		fire(s, ev, iso, map_data, true)
		return


## Every presidency opens with a decision, so the first month is never empty.
static func _opening(s: GameState) -> void:
	s.fired_events["opening"] = s.turn
	var card := {"id": "opening", "speaker": "chief", "art": "domestic", "ctx": "", "choices": [
		{"label": "Abroad: call our allies first", "effects": [["us", "standing", 3], ["us", "political_capital", 5]], "advisors": {"state": 3, "un": 1}},
		{"label": "At home: start with the voters", "effects": [["us", "approval", 2], ["us", "congress", 2]], "advisors": {"chief": 3, "treasury": 1}},
		{"label": "In the shadows: start with the intelligence brief", "effects": [["funds", "covert", 1], ["trust", "cia", 6]], "advisors": {"cia": 3, "nsa": 1}},
	]}
	var key := "opening_" + String(s.scenario.get("id", ""))
	system_card(card, key if _has_system_card(key) else "opening", {})
	s.pending.append(card)


static func _has_system_card(key: String) -> bool:
	if _system_cards.is_empty():
		var f := FileAccess.open("res://data/scenarios/system_cards.json", FileAccess.READ)
		if f:
			_system_cards = JSON.parse_string(f.get_as_text())
	return _system_cards.has(key)


static var _system_cards: Dictionary = {}


## Fill a code-generated card's title/text from data/scenarios/system_cards.json, keeping the
## template so the voice bank can play pre-recorded lines around the country names.
static func system_card(card: Dictionary, key: String, vars: Dictionary) -> void:
	if _system_cards.is_empty():
		var f := FileAccess.open("res://data/scenarios/system_cards.json", FileAccess.READ)
		if f:
			_system_cards = JSON.parse_string(f.get_as_text())
	var t: Dictionary = _system_cards.get(key, {"title": key, "text": ""})
	var title := String(t["title"])
	var text := String(t["text"])
	for k in vars:
		title = title.replace(k, String(vars[k]))
		text = text.replace(k, String(vars[k]))
	card["title"] = title
	card["text"] = text
	card["speaker"] = String(t.get("speaker", card.get("speaker", "nsa")))
	card["voice"] = {"title": String(t["title"]), "text": String(t["text"]), "vars": vars}


static func fire(s: GameState, ev: Dictionary, iso: String, map_data: Dictionary, force_card: bool = false) -> void:
	s.fired_events[ev["id"]] = s.turn
	var name: String = s.c(iso).get("name", "") if iso != "" else ""
	var title := String(ev.get("title", "")).replace("$NAME", name)
	var text := String(ev.get("text", "")).replace("$NAME", name)
	apply(s, ev.get("effects", []), iso, map_data)
	var choices: Array = ev.get("choices", []).duplicate(true)
	for ch in choices:
		ch["label"] = String(ch["label"]).replace("$NAME", name)
	if choices.is_empty():
		s.add_log("%s. %s" % [title, text], "headline", iso)
		return
	if ev.get("minor", false) and s.auto_minor and not force_card:
		var best := cabinet_choice(s, choices)
		apply(s, choices[best].get("effects", []), iso, map_data)
		var adv: Dictionary = choices[best].get("advisors", {})
		for id in adv:
			Advisors.adjust(s, id, float(adv[id]))
		s.add_log("%s. Your cabinet handled it: %s." % [title, String(choices[best]["label"]).trim_suffix(".")], "cabinet", iso)
		return
	s.pending.append({"id": ev["id"], "title": title, "text": text, "ctx": iso, "speaker": ev.get("speaker", "nsa"),
		"voice": {"title": String(ev.get("title", "")), "text": String(ev.get("text", "")), "vars": {"$NAME": name}},
		"art": ev.get("art", art_for(String(ev["id"]), title)), "choices": choices})
	s.add_log(title, "headline", iso, 1)


const ART_KEYS := [
	["space", ["moon", "space", "rocket"]],
	["nuclear", ["nuclear", "weapons programme", "enrich", "bomb", "breakout", "nk_program", "wmd"]],
	["health", ["virus", "outbreak", "pandemic", "fever"]],
	["famine", ["famine", "drought", "locust", "hunger", "crop"]],
	["disaster", ["disaster", "hurricane", "storm", "flood", "earthquake", "home_storm"]],
	["naval", ["red sea", "red_sea", "strait", "arctic", "ships", "carrier", "naval", "canal", "drills"]],
	["terror", ["bombing", "embassy", "cartel", "terror", "mob", "hostage", "firefight", "mogadishu"]],
	["tech", ["ai ", "ai_", "cyber", "deepfake", "chip", "hack", "meddling", "tech"]],
	["covert", ["spy", "defector", "coup plot", "leak", "mercenar", "covert", "coup"]],
	["election", ["election", "referendum", "midterm", "ballot", "vote"]],
	["protest", ["protest", "refugee", "separatist", "apartheid", "rwanda", "killings", "reporter", "journalist"]],
	["war", ["war", "invad", "invasion", "border", "clash", "offensive", "siege", "deadline", "missile", "coalition", "chechnya", "tanks", "threatens", "gangs", "standoff"]],
	["economy", ["debt", "recession", "boom", "peso", "oil", "tariff", "trade", "nafta", "reconstruction", "default", "economy", "loan"]],
	["domestic", ["shutdown", "aide", "court", "dinner", "white house", "congress", "supreme", "gulf coast"]],
	["diplomacy", ["talks", "summit", "ceasefire", "treaty", "peace", "unity", "reunif", "dissolves", "breaks apart", "split", "independent", "world games", "arms treaty"]],
]


static func art_for(id: String, title: String) -> String:
	var hay := (id + " " + title).to_lower()
	for pair in ART_KEYS:
		for key in pair[1]:
			if hay.contains(key):
				return pair[0]
	return "diplomacy"


## The option most of the cabinet favours, skipping ones you can't afford.
static func cabinet_choice(s: GameState, choices: Array) -> int:
	var best := 0
	var best_v := -1e9
	for i in choices.size():
		var v := 0.0
		for a in choices[i].get("advisors", {}).values():
			v += float(a)
		for e in choices[i].get("effects", []):
			if e[0] == "us" and e[1] == "political_capital" and float(s.us["political_capital"]) + float(e[2]) < 10.0:
				v -= 100.0
			if e[0] == "funds" and float(s.us["funds"].get(e[1], 0.0)) + float(e[2]) < 0.0:
				v -= 100.0
		if v > best_v:
			best_v = v
			best = i
	return best


static func resolve(s: GameState, choice_index: int, map_data: Dictionary) -> String:
	if s.pending.is_empty():
		return ""
	var card: Dictionary = s.pending.pop_front()
	var choices: Array = card.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return ""
	var ch: Dictionary = choices[choice_index]
	apply(s, ch.get("effects", []), card.get("ctx", ""), map_data)
	var adv: Dictionary = ch.get("advisors", {})
	for id in adv:
		Advisors.adjust(s, id, float(adv[id]))
	if card["id"] != "election_review":
		s.add_log("Decision on \"%s\": %s" % [card["title"], ch["label"]], "action")
	return String(ch["label"])


static func _iso(arg: Variant, ctx: String) -> String:
	var a := String(arg)
	return ctx if a == "$C" else a


static func _cmp(a: float, op: String, b: float) -> bool:
	match op:
		">": return a > b
		"<": return a < b
		">=": return a >= b
		"<=": return a <= b
		"==": return is_equal_approx(a, b)
	return false


static func conditions_met(s: GameState, conds: Array, ctx: String) -> bool:
	for cnd in conds:
		var kind: String = cnd[0]
		match kind:
			"stat":
				var d := s.c(_iso(cnd[1], ctx))
				if d.is_empty() or not s.is_active(_iso(cnd[1], ctx)):
					return false
				if not _cmp(float(d[cnd[2]]), cnd[3], float(cnd[4])):
					return false
			"self":
				var d := s.c(ctx)
				if d.is_empty() or not _cmp(float(d[cnd[1]]), cnd[2], float(cnd[3])):
					return false
			"active":
				if not s.is_active(_iso(cnd[1], ctx)):
					return false
			"at_war":
				if not s.at_war(_iso(cnd[1], ctx)):
					return false
			"civil_war":
				if not s.c(_iso(cnd[1], ctx)).get("civil_war", false):
					return false
			"us":
				if not _cmp(float(s.us.get(cnd[1], 0.0)), cnd[2], float(cnd[3])):
					return false
			"self_state":
				if not _has_state(s, ctx, cnd[1]):
					return false
			"not_state":
				if _has_state(s, _iso(cnd[1], ctx), cnd[2]):
					return false
			"state":
				if not _has_state(s, _iso(cnd[1], ctx), cnd[2]):
					return false
			"self_region":
				if not String(s.c(ctx).get("region", "")) in cnd.slice(1):
					return false
			"system":
				if not s.has_system(cnd[1]):
					return false
			"flag":
				if not s.flags.has(String(cnd[1])):
					return false
			"no_flag":
				if s.flags.has(String(cnd[1])):
					return false
	return true


static func _has_state(s: GameState, iso: String, state: String) -> bool:
	var d := s.c(iso)
	if d.is_empty():
		return false
	match state:
		"war": return s.at_war(iso)
		"civil_war": return d.get("civil_war", false)
		"sanctioned": return d.get("sanctioned", false)
		"troops": return s.us["troops"].has(iso)
		"nuclear": return d.get("nuclear", false)
		"ally": return float(d["relation"]) >= 50.0
		"hostile": return float(d["relation"]) <= -40.0
		"west": return d["bloc"] == "west"
		"active": return s.is_active(iso)
	return false


static func apply(s: GameState, effects: Array, ctx: String, map_data: Dictionary) -> void:
	for e in effects:
		var op: String = e[0]
		match op:
			"add", "set", "mul":
				var iso := _iso(e[1], ctx)
				var d := s.c(iso)
				if d.is_empty():
					continue
				var stat: String = e[2]
				if d[stat] is bool:
					d[stat] = bool(e[3])
					continue
				if d[stat] is String:
					d[stat] = String(e[3])
					continue
				var v := float(d[stat])
				if op == "add":
					v += float(e[3])
				elif op == "mul":
					v *= float(e[3])
				else:
					v = float(e[3])
				if COUNTRY_RANGES.has(stat):
					v = clampf(v, COUNTRY_RANGES[stat][0], COUNTRY_RANGES[stat][1])
				d[stat] = maxf(v, 0.0) if stat in ["gdp", "pop"] else v
			"us":
				var field: String = e[1]
				var nv := float(s.us.get(field, 0.0)) + float(e[2])
				if field in ["approval", "political_capital", "congress", "standing", "scandal", "credibility", "tyranny"]:
					nv = clampf(nv, 0.0, 100.0)
				if field == "treaties":
					s.us[field] = int(nv)
				else:
					s.us[field] = maxf(nv, 0.0)
			"funds":
				s.us["funds"][e[1]] = float(s.us["funds"][e[1]]) + float(e[2])
			"war":
				Simulation.start_war(s, _iso(e[1], ctx), _iso(e[2], ctx), float(e[3]))
			"end_war":
				var w := s.war_for(_iso(e[1], ctx))
				if not w.is_empty():
					Simulation.end_war(s, w, "The war between %s and %s ends." % [s.c(w["a"])["name"], s.c(w["b"])["name"]])
			"civil_war":
				var d := s.c(_iso(e[1], ctx))
				if not d.is_empty():
					d["civil_war"] = bool(e[2])
			"deploy":
				var iso := _iso(e[1], ctx)
				if s.is_active(iso):
					s.us["troops"][iso] = 1
			"withdraw":
				s.us["troops"].erase(_iso(e[1], ctx))
			"start_op":
				var iso := _iso(e[1], ctx)
				if s.is_active(iso) and Actions.op_for(s, iso, String(e[2])).is_empty():
					if not s.us.has("ops"):
						s.us["ops"] = []
					s.us["ops"].append({"type": String(e[2]), "iso": iso, "months": 0, "progress": 0.0})
			"flag":
				s.flags[String(e[1])] = e[2] if e.size() > 2 else true
			"pact":
				var pd := s.c(_iso(e[1], ctx))
				if not pd.is_empty():
					pd["pact"] = bool(e[2])
			"betray":
				s.stats["pact_betrayals"] = int(s.stats.get("pact_betrayals", 0)) + 1
				var bd := s.c(_iso(e[1], ctx))
				if not bd.is_empty():
					bd["pact"] = false
					bd["relation"] = clampf(float(bd["relation"]) - 30.0, -100.0, 100.0)
				for iso2 in s.active_isos():
					if s.countries[iso2].get("pact", false):
						s.countries[iso2]["relation"] = clampf(float(s.countries[iso2]["relation"]) - 12.0, -100.0, 100.0)
				s.add_log("Allies question whether a US guarantee means anything.", "headline")
			"regime":
				var iso := _iso(e[1], ctx)
				if s.is_active(iso):
					Simulation.regime_change(s, iso, bool(e[2]))
			"budget_base":
				for k in s.us["budget_baseline"]:
					s.us["budget_baseline"][k] = float(s.us["budget_baseline"][k]) * float(e[1])
			"sanction":
				var d := s.c(_iso(e[1], ctx))
				if not d.is_empty():
					d["sanctioned"] = true
					d["relation"] = clampf(float(d["relation"]) - 15.0, -100.0, 100.0)
			"rename":
				var d := s.c(_iso(e[1], ctx))
				if not d.is_empty():
					d["name"] = e[2]
			"split":
				split_group(s, String(e[1]), map_data)
			"bloc_all":
				for iso in s.countries:
					if s.countries[iso].get("bloc", "") == e[1]:
						s.countries[iso]["bloc"] = e[2]
			"trust":
				Advisors.adjust(s, e[1], float(e[2]))
			"crisis":
				# Strengthen (or weaken) your hand in the crisis this briefing is about.
				var cr := Crises.for_iso(s, ctx)
				if not cr.is_empty():
					Crises.add_hand(cr, float(e[1]))
			"power":
				Power.apply_move(s, String(e[1]))
			"end":
				Simulation.trigger_ending(s, String(e[1]), String(e[2]))
			"log":
				s.add_log(String(e[1]).replace("$NAME", String(s.c(ctx).get("name", ""))), "info")
			"chance":
				if s.rng.randf() < float(e[1]):
					apply(s, e[2], ctx, map_data)
				elif e.size() > 3:
					apply(s, e[3], ctx, map_data)


## Dissolve a multi-state union (USSR, Yugoslavia...) into its dormant successors.
static func split_group(s: GameState, g: String, map_data: Dictionary) -> void:
	if not s.groups.has(g) or not s.is_group_intact(g):
		return
	var members: Array = s.groups[g]
	var gd := s.c(g)
	gd["dissolved"] = true
	var heir := ""
	var heir_pop := -1.0
	for m in members:
		if m == g:
			continue
		var md := s.c(m)
		if md.is_empty() or md.has("fold_into"):
			continue
		md["dormant"] = false
		if float(md["pop"]) > heir_pop:
			heir_pop = float(md["pop"])
			heir = m
	if not members.has(g):
		gd["dormant"] = true
		for w in s.wars:
			if w["a"] == g:
				w["a"] = heir
			if w["b"] == g:
				w["b"] = heir
		if s.us["troops"].has(g):
			s.us["troops"].erase(g)
		for b in s.scenario["blocs"].values():
			if b.get("leader", "") == g:
				b["leader"] = heir
				b["name"] = "%s-aligned" % s.c(heir).get("name", heir)
	s.recompute_map_owner(map_data)
	if not members.has(g):
		s.add_log("%s dissolves." % gd.get("name", g), "headline")


## UN Security Council: a resolution built from the current world, about every ten months.
static func un_resolution(s: GameState) -> void:
	if s.game_over or s.pending.size() >= 2:
		return
	if s.fired_events.has("un") and s.turn - int(s.fired_events["un"]) < 6:
		return
	if s.rng.randf() > 0.12:
		return
	var options: Array = []
	for w in s.wars:
		options.append(["aggression", w["a"], w["b"]])
	for iso in s.active_isos():
		var d := s.c(iso)
		if float(d["hunger"]) > 60.0 and float(d["pop"]) > 5.0:
			options.append(["famine", iso, ""])
		if d.get("civil_war", false):
			options.append(["peacekeeping", iso, ""])
		if float(d["terror"]) > 65.0:
			options.append(["terror", iso, ""])
	if options.is_empty():
		return
	var pick: Array = options[s.rng.randi_range(0, options.size() - 1)]
	var iso: String = pick[1]
	var name: String = s.c(iso)["name"]
	var card := {"id": "un", "speaker": "un", "art": "diplomacy", "ctx": iso}
	match pick[0]:
		"aggression":
			var victim: String = s.c(pick[2])["name"]
			system_card(card, "un_aggression", {"$NAME": name, "$B": victim})
			card["choices"] = [
				{"label": "Vote yes", "effects": [["add", iso, "relation", -12], ["add", pick[2], "relation", 8], ["us", "standing", 4], ["add", iso, "ambition", -4]], "advisors": {"un": 4, "state": 2}},
				{"label": "Abstain", "effects": [["us", "standing", -1]], "advisors": {"un": -1}},
				{"label": "Veto it", "effects": [["add", iso, "relation", 12], ["add", pick[2], "relation", -15], ["us", "standing", -8]], "advisors": {"un": -6, "state": -3}},
			]
		"famine":
			system_card(card, "un_famine", {"$NAME": name})
			card["choices"] = [
				{"label": "Vote yes and pay the largest share ($1bn)", "effects": [["funds", "aid", -1], ["add", iso, "hunger", -12], ["add", iso, "relation", 8], ["us", "standing", 4]], "advisors": {"un": 4, "state": 2, "treasury": -1}},
				{"label": "Vote yes, let others pay", "effects": [["add", iso, "hunger", -4], ["us", "standing", 1]], "advisors": {"un": 1}},
				{"label": "Veto: no open-ended missions", "effects": [["us", "standing", -6], ["add", iso, "relation", -8]], "advisors": {"un": -5, "treasury": 2}},
			]
		"peacekeeping":
			system_card(card, "un_peacekeeping", {"$NAME": name})
			card["choices"] = [
				{"label": "Vote yes and provide airlift ($1bn)", "effects": [["funds", "defense", -1], ["add", iso, "stability", 10], ["us", "standing", 4], ["chance", 0.35, [["civil_war", iso, false], ["log", "Peacekeepers help end the fighting in $NAME."], ["us", "treaties", 1]], []]], "advisors": {"un": 4, "defense": -1}},
				{"label": "Abstain", "effects": [], "advisors": {"un": -1}},
				{"label": "Veto", "effects": [["us", "standing", -6]], "advisors": {"un": -5, "chief": 1}},
			]
		"terror":
			system_card(card, "un_terror", {"$NAME": name})
			card["choices"] = [
				{"label": "Vote yes", "effects": [["sanction", iso], ["add", iso, "terror", -8], ["us", "standing", 3]], "advisors": {"un": 3, "nsa": 2}},
				{"label": "Abstain", "effects": [], "advisors": {"nsa": -1}},
				{"label": "Veto: we'll handle it ourselves", "effects": [["us", "standing", -5]], "advisors": {"un": -4, "nsa": 1}},
			]
	s.fired_events["un"] = s.turn
	s.pending.append(card)
	s.add_log(String(card["title"]), "headline")
