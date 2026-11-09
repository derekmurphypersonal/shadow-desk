# Design notes

Why the game works the way it does, release by release. The changelog says what changed; this says why.

## 1.5: the playability release

### The problem, measured

`tests/telemetry.gd` plays the guided bot (it does exactly what the game's own advice says) through 8 presidencies per scenario and counts what each month asks of the player. In 1.4, on normal difficulty with default settings:

| | 1990 | 2026 |
| --- | --- | --- |
| Months with no briefing and no big news | 37% | 40% |
| Longest run of such months | 5 | 7 |
| Political capital gained per month, after upkeep | +4.2 | +1.9 |
| Average political capital on hand | 64 | 17 |
| Months in which the advice led to any action | 11% | 18% |
| Advice items repeated from the month before | 83% | 86% |

The cheapest action cost 4 or 5 political capital, so a month was one small action, sometimes a briefing, and End month. The dossier listed 21 or 22 options in one scroll with five visible. A decision closed with a stamp and no account of what it changed.

### Decisions

- **Time is a second currency.** The diary (`scripts/sim/diary.gd`) gives every month five or six engagements and three time slots. They cost time rather than political capital so that a President who is broke still has a month to play. Effects are about a third of a paid action, and repeatable approval gains are kept small (+0.6) because approval drifts 8% of the way to its target each month, which turns a steady +1 a month into roughly +12 at equilibrium.
- **The simulation still ticks monthly.** Days are presentation. Each log entry carries a `day` derived from a hash of its text, not from the dice, so adding the month sweep changed no outcomes. Diary items carry real weekdays for their dates.
- **The diary is state, not UI.** It lives in `s.us["diary"]`, is drawn with the game's seeded RNG, saves with the game and has a bot (`Diary.auto`) so the balance tests cover it.
- **Show effects before and after.** `scripts/sim/report.gd` reads a choice's effect list into chips (preview) and diffs two snapshots of the state (result). Both are pure reads of `GameState`; the interface only draws them. The briefing card applies the decision itself and stays open to show the result, so the consequence is seen in the same place the choice was made.
- **Exact numbers in previews.** The game already prints exact figures elsewhere (costs, odds, "scandal +15"). Hiding them on briefings made choices feel arbitrary rather than tense. Gambles are marked as gambles.
- **Pacing by rule, not by more content.** Template events stop adding briefings beyond two a month. With an empty desk an event is brought forward 80% of the time, and always if the previous month was empty too, so quiet months are rare and never back to back. Minor events can still be left to the cabinet.
- **Political capital refills against the tank.** Regeneration is scaled by `1.5 - PC/80` (clamped 0.5 to 1.5): quick when low, slow when hoarded. The advice also names concrete things to buy with spare capital, which is what made the 1990 bot start spending it.
- **One place to look.** The Desk tab holds the diary, the attention list and everything running. Pins put the same advice on the map. The dossier leads with what the cabinet would do and folds the rest by type; impossible options are one line, with reasons on request.
- **Two clicks from the map.** The action ring anchors on the country's centroid (so it follows pan and zoom) and offers only what is possible now. The dossier remains the place for detail.
- **Teach by doing.** The first month is a four-item checklist that ticks itself off. Every presidency opens with a briefing so the first thing a player does is decide something.

### Results (same bot, same seeds)

| | 1990 | 2026 |
| --- | --- | --- |
| Months with no briefing and no big news | 8% | 7% |
| Longest run of such months | 1 | 1 |
| Average political capital on hand | 42 | 26 |
| Diary engagements kept per month | 2.8 | 2.9 |
| Advice items repeated from the month before | 57% | 87% |

Known gap: in 2026 the attention list still repeats, because its top items are long-running mandates (a war to end, a country to protect). The diary and pins now carry the month-to-month variety instead.

Balance moved a little toward the player (bot approval up 1 to 4 points). The passive bot still loses every game; careful bots still win nearly all.
