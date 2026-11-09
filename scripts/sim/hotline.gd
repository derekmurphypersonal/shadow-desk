class_name Hotline
extends RefCounted
## Hotline calls: a short negotiation with a foreign leader, in two exchanges. First how you open,
## then what you put on the table. How well each lands depends on the leader's temperament, which is
## read from their country (ambition, stability, freedom, relations). Leaders are an office and a
## temperament, never a name.
##
## A call is a plain Dictionary the interface holds while the line is open:
##   {iso, name, temper: [..], mood (0-100), round (0, 1, 2 = over), lines: [[who, text]], fit, picks}
## Pure rules: begin() / options() / choose() / finish(). finish() applies the outcome to GameState.

const TEMPERS := {
	"proud": "proud", "cornered": "cornered", "warm": "warm", "pragmatic": "pragmatic", "hostile": "hostile", "cautious": "cautious",
}
const OPENINGS := [
	{"id": "respect", "label": "Open with respect", "hint": "Praise their country and their standing."},
	{"id": "direct", "label": "Get straight to business", "hint": "No ceremony. Say what you want."},
	{"id": "pressure", "label": "Lean on them", "hint": "Remind them what Washington can do."},
]
const OFFERS := [
	{"id": "trade", "label": "Offer better access to US markets", "hint": "Economic carrot. Pulls them away from rivals."},
	{"id": "security", "label": "Offer security assurances", "hint": "Worth most to the nervous and the threatened."},
	{"id": "listen", "label": "Ask for nothing and listen", "hint": "Small gain, and you learn how they really stand."},
	{"id": "warn", "label": "Warn them off their current course", "hint": "Can cool an ambitious regime. Can also backfire."},
]
## How each line lands with each temperament: -2 badly … +2 very well.
const FIT := {
	"respect": {"proud": 2, "cornered": 1, "warm": 1, "pragmatic": 0, "hostile": 0, "cautious": 1},
	"direct": {"proud": -1, "cornered": 0, "warm": 1, "pragmatic": 2, "hostile": 0, "cautious": -1},
	"pressure": {"proud": -2, "cornered": 1, "warm": -2, "pragmatic": -1, "hostile": -1, "cautious": 1},
	"trade": {"proud": 0, "cornered": 1, "warm": 1, "pragmatic": 2, "hostile": -1, "cautious": 1},
	"security": {"proud": -1, "cornered": 2, "warm": 1, "pragmatic": 0, "hostile": -2, "cautious": 2},
	"listen": {"proud": 1, "cornered": 0, "warm": 1, "pragmatic": 0, "hostile": 1, "cautious": 1},
	"warn": {"proud": -2, "cornered": 1, "warm": -1, "pragmatic": 0, "hostile": -1, "cautious": 1},
}
const REPLIES := {
	"respect": {
		1: ["You honour us. It has been some time since Washington spoke to us this way.", "Kind words. My people will be glad to hear them repeated in public."],
		0: ["Thank you. We have heard fine words from Washington before.", "Courteous. Now, why are you really calling?"],
		-1: ["Flattery is what one offers when one has nothing else.", "Spare me the ceremony."],
	},
	"direct": {
		1: ["Good. I prefer a leader who does not waste my afternoon.", "Then let us talk as two people with work to do."],
		0: ["Very well. Go on.", "You are in a hurry. I am listening."],
		-1: ["You speak to me as if to a clerk.", "In my country we greet a guest before we bargain with him."],
	},
	"pressure": {
		1: ["I understand you. There is no need to say more.", "We are not looking for a quarrel with the United States."],
		0: ["I have been threatened by larger men than you.", "Noted. Is there more?"],
		-1: ["You forget yourself. This is a sovereign nation.", "Threats, on the first call. My generals will enjoy hearing of it."],
	},
	"trade": {
		1: ["Now that is worth a conversation. My finance minister will call yours.", "Markets, not speeches. Yes. We can work with that."],
		0: ["Perhaps. Your Congress has promised such things before.", "We will study it."],
		-1: ["We are not for sale.", "You think everything has a price. It is your national weakness."],
	},
	"security": {
		1: ["If you mean it, it changes a great deal for us.", "My neighbours will think twice. Thank you."],
		0: ["An assurance is a word. We will see what stands behind it.", "We will consider what that is worth."],
		-1: ["We need no protector, and we did not ask for one.", "Your assurances have a way of arriving with soldiers."],
	},
	"listen": {
		1: ["Then I will be frank with you, as you have been patient with me.", "It is rare to be asked. Let me tell you how it looks from here."],
		0: ["There is not much to say. But thank you for asking.", "We watch, and we wait. As you do."],
		-1: ["You called to say nothing? My time is not free.", "If you have no proposal, we have no business."],
	},
	"warn": {
		1: ["I hear you. We will not give you cause.", "It will be reconsidered. You have my word."],
		0: ["We will do what our interests require.", "Your concern is noted."],
		-1: ["Do not lecture me about my own region.", "You have just made my hardliners very happy."],
	},
}
const CLOSERS := {
	"good": ["Call again. My door is open.", "This was useful. We should not leave it so long."],
	"fair": ["We will be in touch through the usual channels.", "Good day, then."],
	"bad": ["I think we are finished here.", "Next time, send your ambassador."],
}


## The leader's temperament, from the state of their country. One or two words.
static func temper(s: GameState, iso: String) -> Array:
	var d := s.c(iso)
	var out: Array = []
	if float(d["ambition"]) > 65.0:
		out.append("proud")
	if float(d["stability"]) < 35.0 or s.at_war(iso):
		out.append("cornered")
	if float(d["relation"]) < -30.0:
		out.append("hostile")
	elif float(d["relation"]) > 40.0:
		out.append("warm")
	if out.size() < 2 and float(d["freedom"]) > 70.0:
		out.append("pragmatic")
	if out.is_empty():
		out.append("cautious")
	return out.slice(0, 2)


static func begin(s: GameState, iso: String) -> Dictionary:
	var d := s.c(iso)
	var mood := clampf(50.0 + float(d["relation"]) * 0.3, 15.0, 85.0)
	return {"iso": iso, "name": String(d["name"]), "temper": temper(s, iso), "mood": mood, "round": 0,
		"lines": [["them", "The line is open. I am told the President wishes to speak with me."]], "fit": 0, "picks": []}


static func options(call: Dictionary) -> Array:
	match int(call["round"]):
		0: return OPENINGS
		1: return OFFERS
	return []


static func fit(call: Dictionary, id: String) -> int:
	var total := 0
	for t in call["temper"]:
		total += int(FIT[id][t])
	return clampi(total, -2, 2)


## Say something. Moves the mood, adds both sides' lines, advances the round.
static func choose(s: GameState, call: Dictionary, id: String) -> Dictionary:
	if int(call["round"]) >= 2:
		return call
	var label := ""
	for o in options(call):
		if o["id"] == id:
			label = String(o["label"])
	var f := fit(call, id)
	var band := 1 if f >= 1 else (-1 if f <= -1 else 0)
	var pool: Array = REPLIES[id][band]
	call["lines"].append(["you", label + "."])
	call["lines"].append(["them", String(pool[s.rng.randi_range(0, pool.size() - 1)])])
	call["mood"] = clampf(float(call["mood"]) + 11.0 * float(f) + s.rng.randf_range(-3.0, 3.0), 0.0, 100.0)
	call["fit"] = int(call["fit"]) + f
	call["picks"].append(id)
	call["round"] = int(call["round"]) + 1
	if int(call["round"]) >= 2:
		var tone := "good" if int(call["fit"]) >= 2 else ("bad" if int(call["fit"]) <= -2 else "fair")
		var closers: Array = CLOSERS[tone]
		call["lines"].append(["them", String(closers[s.rng.randi_range(0, closers.size() - 1)])])
		call["tone"] = tone
	return call


## Hang up: apply what the call achieved. Returns a one-line result.
static func finish(s: GameState, call: Dictionary) -> String:
	var iso := String(call["iso"])
	var d := s.c(iso)
	if d.is_empty():
		return "The line went dead."
	var total := int(call["fit"])
	var offer := String(call["picks"][1]) if call["picks"].size() > 1 else ""
	var offer_fit := fit(call, offer) if offer != "" else 0
	var rel := clampf(1.5 + 2.0 * float(total), -6.0, 8.0)
	d["relation"] = clampf(float(d["relation"]) + rel, -100.0, 100.0)
	var extra := ""
	match offer:
		"trade":
			if offer_fit >= 1:
				d["rival_pull"] = maxf(0.0, float(d.get("rival_pull", 0.0)) - 10.0)
				extra = " Rival influence falls."
		"security":
			if offer_fit >= 1:
				d["rival_pull"] = maxf(0.0, float(d.get("rival_pull", 0.0)) - 15.0)
				d["stability"] = clampf(float(d["stability"]) + 2.0, 0.0, 100.0)
				extra = " They feel safer, and rivals lose ground."
		"listen":
			d["intel_until"] = maxi(int(d.get("intel_until", -1)), s.turn + 3)
			extra = " You learn how they really stand: clear figures for three months."
		"warn":
			if offer_fit >= 1:
				d["ambition"] = clampf(float(d["ambition"]) - 6.0, 0.0, 100.0)
				extra = " They step back: ambition −6."
			elif offer_fit <= -1:
				d["ambition"] = clampf(float(d["ambition"]) + 3.0, 0.0, 100.0)
				extra = " It backfires: ambition +3."
	s.stats["hotline"] = int(s.stats.get("hotline", 0)) + 1
	var how: String = {"good": "goes well", "fair": "is correct but cool", "bad": "goes badly"}[String(call.get("tone", "fair"))]
	return "Hotline with %s %s: relations %+d.%s" % [call["name"], how, int(round(rel)), extra]


## For bots and tests: play the call by picking the best-fitting line each round.
static func auto(s: GameState, iso: String) -> String:
	var call := begin(s, iso)
	for r in 2:
		var best := ""
		var best_f := -99
		for o in options(call):
			var f := fit(call, String(o["id"]))
			if f > best_f:
				best_f = f
				best = String(o["id"])
		choose(s, call, best)
	return finish(s, call)
