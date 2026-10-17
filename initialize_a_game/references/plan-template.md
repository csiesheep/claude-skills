# <Game name> — plan

Created <YYYY-MM-DD>. Repo `csiesheep/<slug>`, live at
`https://games.csiesheep.com/<slug>/` (not yet).

## Overview
One paragraph: what the game is, how many players, how long a game, what
the web version adds (solo vs bots, rooms with a 4-letter code, en +
zh-Hant, phone-first). Fan-made, unofficial; own name and setting.

## Why this shape
Which sibling repo it is modelled on and what is reused (router, rooms,
harness). What is new to this game.

## Licensing
Original title, designer, publisher. Rules not copyrightable; trademark
risk in the title. Own name chosen: `<name> / <中文>`. Credit line text.
*Not legal advice.*

## Source material
Links to the rulebook(s) used; the rulebook note `[[<slug> - rulebook]]`;
unclear points across sources and how v1 resolves each.

## Theme
| slot | original | now (zh) | now (en) |
|---|---|---|---|
| title | | | |
| sides / roles | | | |
| bot names | | | |
| favicon | | | |

### Look
Tokens once chosen: ground, ink, accents and what each colour means;
display and body faces; corner and rule style. Link to the design canvas.

## Rules in scope (v1 = base game, exactly)
Player counts, setup, turn structure, win conditions, every table.
Expansions and variants listed as data-driven later work.

## Rule versions
How the web version's own rules change after play-testing: a draft note
per change (the owner's words verbatim, the proposals, the simulation
numbers, the decision), the engine's `createGame(seed, { rules })`, which
version new games start on, and what a game saved on an older version
keeps (its rules, its screens; the card texts if they are not versioned).
A table of versions: date, what changed, simulation numbers, adopted or not.

## Architecture
- Worker + prefix router, static assets, one DO per room.
- `engine.js`: state shape, actions, `view(state, seat)`, RNG.
- `bots.js`: what the AI reasons about; level knobs; `why` for talk.
- `room.js`: phase clocks, grace period, bot fill, idle deletion.
- Solo driver in `app.js`.

## Pages and UI
| Route | View | What is on it |
|---|---|---|
| `/<slug>/` | Landing | |
| `?play` | Solo setup | |
| `?room=ABCD` | Lobby | |
| (in game) | Table | |
| (in game) | Game over | |
| `/<slug>/rules` | Rulebook | |

Mockup link. Phone-first.

Viewport targets: 390×664 (iPhone Safari with toolbars) scored, 375×548
(SE) read, 1440×900 desk. Which pages must fit without scrolling (setup,
lobby, game over), and where the phone layout differs from the desk one
(for example what a candidate panel shows without a tap).

## Bots and balance
Approach; levels; the harness (`node tests/sim.js <games> <n or 0> …`);
target win rates and what "feels human" means for this game.
The band the owner reads (each side's win rate, the average margin, any
game-specific rate such as turnout) and how a rule change is compared:
every arm on the same seeds, the control arms scored equal to main, the
bots tuned seat by seat (one seat changed, the others fixed, paired seeds)
before the numbers go to the owner.

## Team (agent-team-delivery)
Phase 0 proposal; the owner confirms it with the first go.

| Files | Role |
|---|---|
| `public/shared/engine.js`, `public/shared/bots.js`, `src/`, `tests/sim.js` | BE |
| `public/*.html`, `public/app.js`, `public/style.css` | FE |
| `public/i18n/*`, the rules page text, `README.md` | writer |
| `public/art/` and the prompts that made it | artist |
| `tests/` (except `sim.js`), `tools/`, `TEAM.md` | orchestrator |

- First guard: group 0 copies … from the rulebook note; group 1 checks that a
  game can be set up and every seat has a legal move; made red once by ….
- Placeholder deploy: yes / no.
- Deploy rule: the orchestrator deploys after every land until M5 (pages
  `noindex`); from M5, only on the owner's go.
- Orchestrator's first goal: M1 engine; priorities: ….

## Milestones
- M0 Scaffold and team setup (Phase 0): router, placeholder deployed and
  verified, `TEAM.md`, a first guard seen red. M1 on are orchestrator issues.
- M1 Engine + tests (incl. a fuzz test over legal moves).
- M2 Bots + harness, win-rate table.
- M3 Solo UI, bot talk, i18n, rules page.
- M4 Rooms: DO, clocks, chat, bot fill, reconnect, rematch.
- M5 Ship: noindex off, OG, JSON-LD, hub tile, sitemap.

## Open questions (decide before M0)
1. … — recommendation: …

## Decisions
- **<YYYY-MM-DD>** — …

## Next steps
- [ ] Owner confirms the plan, the open questions and the Phase 0 proposal (first go).
- [ ] Phase 0: placeholder, `TEAM.md`, first guard seen red.
- [ ] Owner's second go: the orchestrator session starts M1.
