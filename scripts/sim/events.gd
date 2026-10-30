class_name Events
extends RefCounted
## Data-driven events. Scripted events fire on dates or conditions; template events pick a
## matching country at random. Events with choices become decision cards in s.pending.

const COUNTRY_RANGES := {
	"relation": [-100.0, 100.0], "stability": [0.0, 100.0], "freedom": [0.0, 100.0],
	"military": [0.0, 100.0], "hunger": [0.0, 100.0], "ambition": [0.0, 100.0], "terror": [0.0, 100.0],
}
const TEMPLATE_COOLDOWN := 6


static func check(s: GameState, events: Array, map_data: Dictionary) -> void:
	var templates_fired := 0
	for ev in events:
		if ev.has("system") and not s.has_system(ev["system"]):
			continue
		if ev.get("template", false):
			if templates_fired >= 2:
				continue
			if s.fired_events.has(ev["id"]) and s.turn - int(s.fired_events[ev["id"]]) < TEMPLATE_COOLDOWN:
				continue
			if s.rng.randf() >= float(ev.get("chance", 0.1)):
				continue
			var candidates: Array = []
			for iso in s.active_isos():
				if conditions_met(s, ev.get("if", []), iso):
					candidates.append(iso)
			if candidates.is_empty():
				continue
			var iso: String = candidates[s.rng.randi_range(0, candidates.size() - 1)]
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


static func fire(s: GameState, ev: Dictionary, iso: String, map_data: Dictionary) -> void:
	s.fired_events[ev["id"]] = s.turn
	var name: String = s.c(iso).get("name", "") if iso != "" else ""
	var title := String(ev.get("title", "")).replace("$NAME", name)
	var text := String(ev.get("text", "")).replace("$NAME", name)
	apply(s, ev.get("effects", []), iso, map_data)
	var choices: Array = ev.get("choices", []).duplicate(true)
	for ch in choices:
		ch["label"] = String(ch["label"]).replace("$NAME", name)
	if choices.is_empty():
		s.add_log("%s. %s" % [title, text], "headline")
		return
	if ev.get("minor", false) and s.auto_minor:
		var best := cabinet_choice(s, choices)
		apply(s, choices[best].get("effects", []), iso, map_data)
		var adv: Dictionary = choices[best].get("advisors", {})
		for id in adv:
			Advisors.adjust(s, id, float(adv[id]))
		s.add_log("%s. Your cabinet handled it: %s." % [title, String(choices[best]["label"]).trim_suffix(".")], "cabinet")
		return
	s.pending.append({"id": ev["id"], "title": title, "text": text, "ctx": iso, "speaker": ev.get("speaker", "nsa"),
		"art": ev.get("art", art_for(String(ev["id"]), title)), "choices": choices})
	s.add_log(title, "headline")


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
				if field in ["approval", "political_capital", "congress", "standing", "scandal"]:
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
