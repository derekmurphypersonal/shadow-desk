class_name Personas
extends RefCounted
## Leader archetypes. Each one tilts the rules: a perk, a flaw, and its own way to fall.
## Archetypes only; no real leader is named or depicted.

const ORDER := ["statesman", "idealist", "reformer", "warlord", "paranoid", "strongman"]
const DEFS := {
	"statesman": {"name": "The Statesman", "icon": "standing",
		"perk": "Balanced. Plays the game as designed.", "flaw": "No special strengths.",
		"mods": {}},
	"idealist": {"name": "The Idealist", "icon": "diplomacy",
		"perk": "Diplomacy and aid cost 20% less political capital. World standing starts higher; peace talks go better.",
		"flaw": "Covert operations are twice as likely to leak, and the press never forgives it.",
		"mods": {"pc_Diplomacy": 0.8, "pc_Economic": 0.8, "standing0": 8.0, "peace": 8.0, "exposure": 2.0}},
	"reformer": {"name": "The Reformer", "icon": "economic",
		"perk": "Voters reward domestic spending 40% more. Congress starts friendlier.",
		"flaw": "Military options cost 20% more political capital; the Pentagon doesn't trust you.",
		"mods": {"domestic": 1.4, "congress0": 8.0, "pc_Military": 1.2, "trust_defense0": -12.0}},
	"warlord": {"name": "The Warlord", "icon": "military",
		"perk": "Military options cost 30% less. Invasions move 25% faster and wars barely dent your approval.",
		"flaw": "Peace talks go badly and the world slowly turns against you.",
		"mods": {"pc_Military": 0.7, "invade": 1.25, "war_mood": 0.4, "peace": -15.0, "standing_drift": -10.0}},
	"paranoid": {"name": "The Paranoid", "icon": "covert",
		"perk": "Intelligence is 15 points sharper, covert ops rarely leak, and assassins rarely get close.",
		"flaw": "You trust no one and it shows: your cabinet's trust erodes every month, and voters find you cold.",
		"mods": {"intel": 15.0, "exposure": 0.5, "assassin": 0.5, "trust_drift": -0.6, "approval": -2.0}},
	"strongman": {"name": "The Strongman", "icon": "scandal",
		"perk": "Power moves cost 30% less. Your base shrugs off scandal and authoritarian rule. Political capital refills 20% faster.",
		"flaw": "Democracies cool on you, and a hated strongman is a hunted one: assassination risk is 50% higher.",
		"mods": {"power": 0.7, "tyranny_pen": 0.35, "scandal_pen": 0.5, "pc": 1.2, "assassin": 1.5, "standing0": -10.0, "tyranny0": 10.0}},
}


static func id(s: GameState) -> String:
	return String(s.us.get("persona", "statesman"))


static func mod(s: GameState, key: String, default: float) -> float:
	return float(DEFS.get(id(s), DEFS["statesman"])["mods"].get(key, default))


static func name_of(s: GameState) -> String:
	return String(DEFS.get(id(s), DEFS["statesman"])["name"])


## Apply a persona's starting conditions to a fresh game.
static func apply_start(s: GameState) -> void:
	var u := s.us
	u["standing"] = clampf(float(u["standing"]) + mod(s, "standing0", 0.0), 0.0, 100.0)
	u["congress"] = clampf(float(u["congress"]) + mod(s, "congress0", 0.0), 0.0, 100.0)
	u["tyranny"] = mod(s, "tyranny0", 0.0)
	var t := mod(s, "trust_defense0", 0.0)
	if t != 0.0:
		Advisors.adjust(s, "defense", t)
