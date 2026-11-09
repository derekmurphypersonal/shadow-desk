class_name Report
extends RefCounted
## What a decision costs and what it changed, as short chips the interface can show.
## Pure reads of GameState: snapshot before, snapshot after, diff. No UI code here.
## A chip is {text: String, tone: "good" | "bad" | "neutral"}.

const US := [
	["approval", "Approval", true], ["political_capital", "Political capital", true], ["congress", "Congress", true],
	["standing", "Standing", true], ["scandal", "Scandal", false], ["credibility", "Credibility", true],
	["tyranny", "Tyranny", false],
]
const COUNTRY := [
	["relation", "relations", 1], ["stability", "stability", 1], ["hunger", "hunger", -1],
	["military", "military", 0], ["terror", "terror ties", -1], ["freedom", "freedom", 1], ["ambition", "ambition", -1],
]
const POOLS := {"aid": "Aid", "covert": "Covert", "defense": "Defense", "domestic": "Domestic"}
const US_SHORT := {"approval": "Approval", "political_capital": "PC", "congress": "Congress", "standing": "Standing",
	"scandal": "Scandal", "credibility": "Credibility", "tyranny": "Tyranny", "mood": "Public mood"}


static func snapshot(s: GameState, iso: String = "") -> Dictionary:
	var snap := {"iso": iso, "us": {}, "funds": {}, "trust": {}, "c": {}, "flags": {}}
	for k in US:
		snap["us"][k[0]] = float(s.us.get(k[0], 0.0))
	snap["treaties"] = int(s.us.get("treaties", 0))
	snap["wars"] = s.wars.size()
	snap["troops"] = s.us["troops"].size()
	snap["ops"] = s.us.get("ops", []).size()
	for k in s.us["funds"]:
		snap["funds"][k] = float(s.us["funds"][k])
	for a in s.advisors:
		snap["trust"][a["id"]] = float(a["trust"])
	var d := s.c(iso)
	if iso != "" and not d.is_empty():
		for k in COUNTRY:
			snap["c"][k[0]] = float(d[k[0]])
		for k in ["sanctioned", "trade_deal", "pact", "civil_war"]:
			snap["flags"][k] = bool(d.get(k, false))
		snap["name"] = String(d["name"])
	return snap


## Chips for everything that moved between two snapshots, most important first.
static func diff(s: GameState, before: Dictionary, after: Dictionary, limit: int = 6) -> Array:
	var out: Array = []
	for k in US:
		var a := float(before["us"][k[0]])
		var b := float(after["us"][k[0]])
		if absf(b - a) >= 0.5:
			var up := b > a
			out.append(chip("%s %d → %d" % [k[1], int(round(a)), int(round(b))], "good" if up == k[2] else "bad"))
	for k in after["funds"]:
		var df := float(after["funds"][k]) - float(before["funds"].get(k, 0.0))
		if absf(df) >= 0.05:
			out.append(chip("%s funds %s$%.1fbn" % [POOLS.get(k, k), "+" if df > 0.0 else "−", absf(df)], "good" if df > 0.0 else "bad"))
	if not after["c"].is_empty() and not before["c"].is_empty():
		var nm: String = after.get("name", "")
		for k in COUNTRY:
			var dc := float(after["c"][k[0]]) - float(before["c"][k[0]])
			if absf(dc) >= 0.5:
				var tone := "neutral"
				if int(k[2]) != 0:
					tone = "good" if (dc > 0.0) == (int(k[2]) > 0) else "bad"
				out.append(chip("%s %s %+d" % [nm, k[1], int(round(dc))], tone))
		for k in after["flags"]:
			if after["flags"][k] != before["flags"].get(k, false):
				var on: bool = after["flags"][k]
				match k:
					"sanctioned": out.append(chip("Sanctions imposed" if on else "Sanctions lifted", "neutral"))
					"trade_deal": out.append(chip("Trade deal signed", "good"))
					"pact": out.append(chip("Defence pact signed" if on else "Defence pact ended", "good" if on else "bad"))
					"civil_war": out.append(chip("Civil war begins" if on else "Civil war ends", "bad" if on else "good"))
	if int(after["treaties"]) > int(before["treaties"]):
		out.append(chip("Treaty signed", "good"))
	if int(after["wars"]) != int(before["wars"]):
		out.append(chip("A war begins" if int(after["wars"]) > int(before["wars"]) else "A war ends", "bad" if int(after["wars"]) > int(before["wars"]) else "good"))
	if int(after["troops"]) != int(before["troops"]):
		out.append(chip("US troops deployed" if int(after["troops"]) > int(before["troops"]) else "US troops withdrawn", "neutral"))
	if int(after["ops"]) > int(before["ops"]):
		out.append(chip("Operation begins", "neutral"))
	var moved: Array = []
	for id in after["trust"]:
		var dt := float(after["trust"][id]) - float(before["trust"].get(id, after["trust"][id]))
		if absf(dt) >= 1.0:
			moved.append([absf(dt), id, dt])
	moved.sort_custom(func(x, y): return x[0] > y[0])
	for m in moved.slice(0, 2):
		out.append(chip("%s trust %+d" % [short_title(s, m[1]), int(round(m[2]))], "good" if m[2] > 0.0 else "bad"))
	return out.slice(0, limit)


## Chips for what a briefing choice will cost and is likely to change, read from its effect list.
static func preview(s: GameState, choice: Dictionary, ctx: String, limit: int = 5) -> Array:
	var costs: Array = []
	var rest: Array = []
	_scan(s, choice.get("effects", []), ctx, costs, rest, false)
	if costs.is_empty() and rest.is_empty():
		rest.append(chip("No immediate effect", "neutral"))
	return (costs + rest).slice(0, limit)


static func _scan(s: GameState, effects: Array, ctx: String, costs: Array, rest: Array, gamble: bool) -> void:
	for e in effects:
		var op := String(e[0])
		match op:
			"us":
				var f := String(e[1])
				var v := float(e[2])
				if f == "treaties":
					rest.append(chip("Treaty", "good"))
				elif US_SHORT.has(f) and absf(v) >= 0.5:
					var good := (v > 0.0) != (f in ["scandal", "tyranny"])
					var c := chip("%s %+d" % [US_SHORT[f], int(round(v))], "good" if good else "bad")
					if f == "political_capital" and v < 0.0 and not gamble:
						costs.append(c)
					else:
						rest.append(c)
			"funds":
				var v := float(e[2])
				var c := chip("%s$%sbn %s" % ["" if v < 0.0 else "+", _num(absf(v)), String(POOLS.get(e[1], e[1])).to_lower()], "bad" if v < 0.0 else "good")
				if v < 0.0 and not gamble:
					costs.append(c)
				else:
					rest.append(c)
			"add":
				var iso := Events._iso(e[1], ctx)
				var stat := String(e[2])
				for k in COUNTRY:
					if k[0] == stat and absf(float(e[3])) >= 1.0:
						var tone := "neutral"
						if int(k[2]) != 0:
							tone = "good" if (float(e[3]) > 0.0) == (int(k[2]) > 0) else "bad"
						var who := "" if iso == ctx else String(s.c(iso).get("name", "")) + " "
						rest.append(chip("%s%s %+d" % [who, String(k[1]).capitalize() if who == "" else k[1], int(float(e[3]))], tone))
			"war":
				rest.append(chip("Starts a war", "bad"))
			"end_war":
				rest.append(chip("Ends the war", "good"))
			"deploy":
				rest.append(chip("Sends US troops", "neutral"))
			"withdraw":
				rest.append(chip("Withdraws US troops", "neutral"))
			"start_op":
				rest.append(chip("Starts: %s" % String(Actions.OP_NAMES.get(String(e[2]), e[2])).to_lower(), "neutral"))
			"sanction":
				rest.append(chip("Sanctions", "neutral"))
			"regime":
				rest.append(chip("Regime change", "neutral"))
			"betray":
				rest.append(chip("Breaks the pact", "bad"))
			"pact":
				rest.append(chip("Defence pact", "good"))
			"power":
				rest.append(chip("Raises tyranny" if String(e[1]) not in ["concede", "appease_brass", "liberalise"] else "Eases tyranny", "neutral"))
			"end":
				rest.append(chip("Ends your presidency", "bad"))
			"crisis":
				rest.append(chip("Changes the crisis", "neutral"))
			"chance":
				rest.append(chip("%d%% gamble" % int(float(e[1]) * 100.0), "neutral"))
				_scan(s, e[2], ctx, costs, rest, true)


static func chip(text: String, tone: String) -> Dictionary:
	return {"text": text, "tone": tone}


static func line(chips: Array) -> String:
	var parts: Array = []
	for c in chips:
		parts.append(String(c["text"]))
	return " · ".join(parts)


static func short_title(s: GameState, id: String) -> String:
	return String(s.advisor(id).get("title", id)).replace("Secretary of ", "").replace(" Director", "").replace(" Ambassador", "").replace("National Security Advisor", "NSA").replace(" Secretary", "")


static func _num(v: float) -> String:
	return "%d" % int(v) if is_equal_approx(v, roundf(v)) else "%.1f" % v
