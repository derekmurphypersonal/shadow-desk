# Modding Shadow Desk

Everything about the world lives in JSON under `data/scenarios/`. Copy a scenario folder, rename it, edit, and it appears on the New Presidency screen. No code changes needed.

## Scenario folder

| File | Holds |
| --- | --- |
| `scenario.json` | Name, description, start date, months to first election, cost scale, blocs, US starting state and budget, opening wars, optional systems (`cyber`, `climate`) |
| `countries.json` | One entry per country, keyed by ISO-3 code (as in `data/map/world.json`) |
| `events.json` | Scenario-specific events |
| `map_groups.json` | Optional unions drawn from several modern shapes, e.g. `{"SUN": ["RUS", "UKR", ...]}` |

`data/scenarios/common_events.json` holds events every scenario shares.

## Country fields

`name`, `region`, `pop` (millions), `gdp` ($bn), `growth` (%/yr), `stability`, `freedom`, `military`, `hunger`, `ambition`, `terror` (0-100), `relation` (-100 to 100, with the US), `bloc`, `nuclear`, `civil_war`. Optional: `dormant: true` (exists but inactive until a `split`), `fold_into` (stays dormant; its map shape belongs to another country), `player: true` (the USA).

## Events

```json
{
  "id": "unique_id",
  "speaker": "state",
  "when": {"date": "1991-08", "if": [["active", "SUN"]]},
  "title": "Headline",
  "text": "Body read aloud by the speaker.",
  "effects": [["add", "SUN", "stability", -18]],
  "choices": [
    {"label": "Option text", "effects": [...], "advisors": {"state": 3, "un": 2}}
  ]
}
```

- **Timing:** `"date": "YYYY-MM"` fires once that month; `"after": "YYYY-MM"` plus `"chance": 0.1` rolls monthly; `"repeat": 24` lets it recur after 24 months; `"once": false` allows refiring.
- **Templates:** `"template": true` with top-level `"chance"` and `"if"` picks a random matching country each month. Use `$C` for that country in effects and `$NAME` for its name in text.
- **Speaker:** `chief`, `state`, `defense`, `treasury`, `nsa`, `cia`, `un`. That advisor's portrait and voice present the card.
- **Advisors:** trust change for each advisor when the choice is picked; shown to the player as For/Against.
- **Systems:** `"system": "cyber"` limits an event to scenarios with that system.

### Conditions (`if`)

`["stat", ISO, field, op, value]`, `["self", field, op, value]` (templates), `["active", ISO]`, `["at_war", ISO]`, `["civil_war", ISO]`, `["us", field, op, value]`, `["state", ISO, s]` / `["not_state", ISO, s]` / `["self_state", s]` where s is `war`, `civil_war`, `sanctioned`, `troops`, `nuclear`, `ally`, `hostile`, `west`; `["self_region", "Caribbean", ...]`; `["system", "climate"]`. Ops: `>`, `<`, `>=`, `<=`, `==`.

### Effects

| Effect | Example |
| --- | --- |
| Change a stat | `["add", "IRQ", "military", -10]`, `["set", ...]`, `["mul", "MEX", "gdp", 0.95]` |
| US state | `["us", "approval", 3]` (also `political_capital`, `congress`, `standing`, `scandal`, `treaties`) |
| Spend funds | `["funds", "aid", -2]` (pools: `aid`, `covert`, `defense`, `domestic`) |
| War and peace | `["war", "IRQ", "KWT", 0]`, `["end_war", "IRQ"]`, `["civil_war", "BIH", true]` |
| Troops | `["deploy", "SAU"]`, `["withdraw", "SOM"]` |
| Politics | `["sanction", "IRN"]`, `["regime", "HTI", true]` (true = US-friendly), `["rename", "DEU", "Germany"]` |
| Unions | `["split", "SUN"]`, `["bloc_all", "warsaw", "nonaligned"]` |
| Advisors | `["trust", "cia", 5]` |
| Chance | `["chance", 0.4, [effects if yes], [effects if no]]` |
| News | `["log", "Text for the news wire."]` |

Run `godot --headless --path . -s tests/run_tests.gd` after editing: it plays every scenario for ten years and fails on broken references or out-of-range stats.
