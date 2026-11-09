# Changelog

## 1.6.0 (2026-11-09)

Tension and conversation, built on the 1.5 diary.

- Crises with a clock: five kinds (hostages, a border standoff, a race for the bomb, a famine, a coup plot against a friend) that run for three or four months. Each opens with a voiced briefing, gives you a month or two to work it, comes to a final decision and then ends well or badly. "Your hand" is the chance, in percent, that it ends well: time in the Situation Room (a diary engagement) and the right country actions strengthen it, each month of neglect weakens it. Outcomes are real: a lost standoff starts a war, a lost breakout makes a new nuclear power.
- A crisis strip above the map, a Crises section on the Desk with what would help, crisis pins, and the outcome in the month's playback and the newspaper. At most two crises run at once.
- Hotline calls: for countries that matter (large, nuclear, at war or highly ambitious) the diary offers a negotiation instead of a courtesy call. The leader is an office and a temperament (proud, cornered, warm, pragmatic, hostile, cautious), never a name, face or voice. Two exchanges: how you open, then what you put on the table. Their mood moves with each line and decides the result.
- Advisors argue: when the cabinet is split on a briefing, the strongest voice for one option and the strongest for another (or against the first) make their case in a line each, shown on the option and spoken in their own voices after the briefing.
- Two achievements: Cool head (three crises ended well) and On first-name terms (thirty hotline calls). Crises count toward history's grade.
- Voices: ten crisis briefings and 35 debate lines recorded; `tests/voice_check.gd` covers them.
- Tests: crisis life cycle, save/load, natural frequency, hotline rules and the debate picker. The interface smoke run (`--screenshot=x,scenario,iso,months,,smoke`) drives briefings, the diary, a hotline call, a crisis and the month playback.

## 1.5.0 (2026-11-09)

The playability release. A month now has something to do, something to watch and a clear place to look.

- The President's diary: each month five or six dated engagements drawn from the state of the world (calls to leaders, a state dinner, a CIA deep-dive that clears the fog on a country, lunch on the Hill, a town hall, a press conference, a visit to the troops, a one-to-one with a wavering advisor, an operation review). You have time for three. They cost time, not political capital; unused time becomes a little political capital.
- A new Desk tab: the diary, what needs your attention, and every operation and deployment you have running. The game returns to it at the start of each month.
- Results you can see: every briefing option shows chips for its cost and likely effects; after you choose, the card shows what actually changed. Every figure in the top bar arrows its own changes. Actions float their effect over the country.
- The month plays out: End month runs a few seconds in which the date counts through the month and your diary, your operations and the news appear on a timeline and on the map. Click or press a key to skip; a setting turns it off. Operations now report what they did each month.
- The map as the to-do list: pins mark mandate targets, friends under attack, rival courtship and other openings. Click a country for an action ring of the four option types; the gold ring and star are your cabinet's pick.
- Dossier rebuilt: your cabinet's top recommendations are buttons at the top; all other options fold into Diplomacy, Economic, Military and Covert, showing only what you can do now, with the rest under "Not possible now". Figures sit in two compact columns. The Oval Office tab is shorter, with charts under "Trends and records".
- Steadier pacing: template events add at most two briefings a month; an empty month usually brings an event forward and two empty months never happen in a row. Political capital refills faster when low and slower when hoarded. Advice now names concrete uses for spare capital (trade deals, pacts, an envoy to a country close to a threshold).
- A playable first month: every presidency opens with a voiced briefing, and a four-step checklist (answer a briefing, keep an engagement, act on a country, end the month) replaces the eight-screen tour.
- A Find a country button on the map.
- Tests: new checks for the diary, decision reports, pacing and pins; `tests/telemetry.gd` measures how much each month asks of the player.

Measured with the guided bot over 8 presidencies per scenario (normal difficulty, default settings), 1.4 to 1.5: months with no briefing and no big news fell from 37% to 8% in 1990 and from 40% to 7% in 2026; the longest quiet run fell from 5 and 7 months to 1; average political capital on hand moved from 64 to 42 in 1990 and from 17 to 26 in 2026; the bot keeps about 2.9 diary engagements a month.

## 1.4.0 (2026-11-09)

- Next Steps: a panel on the map and in the Oval Office lists what your cabinet would do next (budget fixes, mandate moves, friends in trouble, advisors about to quit). Click one to jump straight there with the right option ringed.
- Leader archetypes: the Statesman, Idealist, Reformer, Warlord, Paranoid and Strongman, each with a perk and a flaw.
- The strongman path: a new Strongman agenda and Executive Power moves (national emergency, muzzle the press, purge the cabinet, pack the courts, crack down, rig or postpone the election, seize a third term, or restore civil liberties). A tyranny meter drives protests, impeachment for abuse of power, restless generals and assassins.
- Assassinations: leaders abroad are killed by plotters; your CIA can eliminate a hostile leader; presidents face attempts, more often when hated or tyrannical.
- New endings: deposed in a coup, resigned in disgrace, president for life. Three new achievements.
- All new briefings are voiced.

## 1.3.0 (2026-11-09)

- Photographic portraits for all 19 advisors (fictional people, generated locally with an open model).
- Neural voiced briefings: every decision card is pre-recorded, with a distinct natural voice for each cabinet seat. Country names are recorded separately and stitched in, so templated events are voiced too. OS text-to-speech is now only a fallback.
- Briefings arrive over a secure video link: live call timer, audio waveform, camera drift and a glow that follows the voice.
- Voice speed now changes pace without changing the advisor's pitch.
- Replacement advisors match the seat's voice. Defence pacts are no longer offered to hostile countries.

## 1.2.0 (2026-11-06)

- Term mandates: three goals per term (end a war, feed a country, win one back from a rival, widen your circle of friends, balance the books and more), favoured by your agenda. Met mandates pay approval and political capital and count toward your legacy.
- Defence pacts and credibility: sign pacts with close friends (Senate vote). Pacts deter invasions; when a pact partner is attacked you choose to honour it, arm them, or stay out, and your credibility with every ally moves.
- UN Security Council resolutions on aggression, famine, peacekeeping and terror.
- Story arcs: events now set flags that unlock follow-ups (Kuwait, the Soviet collapse, Yugoslavia, the Iran deal, a Ukraine ceasefire, a Taiwan blockade) plus 10 new events.
- Approval breakdown in the Oval Office and on the top bar, showing exactly what moves your numbers.
- Presidential Library: a record of every presidency you've played, and 14 achievements.
- Find a country with Cmd/Ctrl+F. Template events no longer repeat on the same country within three years.
- Balance: grade thresholds raised; hard difficulty is harder; deterrence depends on credibility.

## 1.1.0 (2026-10-30)

- Ongoing operations: air campaign, invasion (with a progress bar to the capital), war support, aid programme, charm offensive, covert campaign. Each charges upkeep monthly and can be stopped any time.
- Every unavailable option now says why, in place, with your current numbers (relations, PC, funds). Options that can't apply are hidden instead of greyed out.
- Pacing: your cabinet handles minor events (toggle in Settings); "Skip ahead" fast-forwards to the next decision; the newspaper appears only for big news by default; faster card and typewriter animations; political capital regenerates faster.
- Art: 15 illustrated briefing scenes (newsprint versions in the paper), country silhouettes in the dossier, redesigned option cards, map shading, coastal glow, ocean texture.
- Map effects: arcs from Washington for strikes, envoys and aid, explosions, aid drops, operation badges.
- Shipping: saves move to a ShadowDesk app-data folder; the Windows executable carries the Shadow Desk icon and version info.

## 1.0.0 (2026-10-30)

- Main menu over an animated world map; new-presidency screen with scenario cards, agendas, difficulty.
- Illustrated cabinet: 19 original advisor portraits; voiced briefings via system text-to-speech.
- President's Daily Brief decision cards with typewriter text and decision stamp.
- Monthly newspaper digest, election-night returns, midterms, game-over screen with history's grade.
- Oval Office tab with approval, standing, world and agenda charts.
- Rival bloc AI courting countries; world standing; Congressional war-powers votes; difficulty levels.
- 83 events (from 23), including the Gulf War, Haiti, Rwanda, Bosnia, NAFTA, Iran, Taiwan, the Arctic and AI.
- Country data from World Bank Open Data (population, GDP, growth, military spending, undernourishment).
- Original music (three loops, two stingers) and sound effects.
- Map polish: graticule, legend, tooltips, pulsing war and courtship markers, smooth zoom, colour-blind palette.
- Settings: volumes, voice, fullscreen, UI scale, digest and typewriter toggles; tutorial; autosave.
- Strategy-bot balance tests.

## 0.1.0

- Vertical slice: map, two scenarios, 13 actions, seven advisors, 23 events, save/load.
