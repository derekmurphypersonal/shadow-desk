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

## 1.6: tension and conversation

1.5 gave every month something to do. What it still lacked was anything that builds: every briefing resolved the moment it was clicked, and nothing had a deadline except the election. 1.6 adds three things on top of the diary.

### Crises with a clock (`scripts/sim/crises.gd`)

- **One number the player can read.** A crisis has a `hand` from 5 to 95, which is literally the percentage chance it ends well. The interface shows the word and the number. No hidden modifiers: what you do moves the hand, and the hand decides the roll.
- **Three beats.** Opening briefing (take charge, delegate, or wait), one or two months to work it, a final decision with a safe option, a costly option and a gamble. Then the outcome. That is long enough to feel a clock and short enough not to become a chore.
- **It uses the systems that already exist.** Diary time (+12, once a month per crisis) and ordinary country actions (a table per kind, each action counting once a month) strengthen the hand. No new action list to learn. Neglect costs 8 a month.
- **Outcomes change the world, not just a score.** A lost standoff starts a war through `Simulation.start_war`, a lost breakout sets `nuclear`, a lost coup is a hostile regime change. A won crisis pays approval, standing or credibility.
- **Scarce.** At most two at once, none in the first three months, at least four months apart. Measured: about six per presidency. A bot that works every crisis wins about four in five. A President who waits at every step reaches the end with a hand of 5% and loses nearly all of them.
- **Voiced without an explosion of lines.** Two templated briefings per kind (ten in all), with country names stitched in as for other system cards. Outcomes are news, not briefings.
- **State is plain data** in `s.us["crises"]`, so it saves and loads with everything else. Briefing choices reach it through one new effect, `["crisis", points]`.

### Hotline calls (`scripts/sim/hotline.gd`)

- **Leaders are an office and a temperament.** The temperament is read from the country (ambition, stability, freedom, relations), so there is nothing to author per country and no real person is named, drawn or voiced. The interface shows a line meter where a face would be and an interpreter's transcript.
- **Two exchanges, not a dialogue tree.** How you open (respect, business, pressure) and what you offer (trade, security, listening, a warning). Each has a fit against each temperament; the fit moves the mood and the mood decides the result. Short enough to do every month, readable enough to get better at.
- **Options show a hint, not the answer.** The fit is not printed. Reading "proud, cornered" and choosing accordingly is the game.
- **Capped.** A perfect call is worth +8 relations and one side effect, a little less than a paid envoy plus a charm offensive, for one time slot.

### Advisors argue (`Advisors.debate`)

- **Only when the cabinet is split,** so it stays an event. The picker takes the strongest supporter of one option and the strongest supporter of another, or failing that the fiercest opponent of the first.
- **Lines belong to seats, not to events.** Thirty-five short lines (three for, two against, per seat) cover every briefing, which keeps recording cheap and means new events get debate for free. The line is chosen by hash, so the same briefing in the same month always reads the same way.
- **Shown on the option it concerns** and spoken after the briefing, in the seat's voice.

### Balance

Careful bots still serve two terms in nearly every game and the passive bot still loses every game. Crises count toward the grade (+1 for a good end, −1.5 for a bad one).
