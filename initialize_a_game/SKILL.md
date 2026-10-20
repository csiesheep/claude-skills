---
name: initialize_a_game
description: |
  Kick off a new browser board game for games.csiesheep.com/<game>/ from a board game's name: find the rulebook, settle the name and licensing, write the implementation plan, mock up the pages, create the Obsidian plan note and the GitHub repo, then STOP for the owner's go. On the go, set the repo up for the team (Phase 0 of agent-team-delivery: placeholder deploy, TEAM.md with the ownership the owner confirmed, a first guard shown red); STOP again; on the second go, open the orchestrator session that builds the game (Phase 1). This skill writes no game code beyond Phase 0's thinnest slice.
  Trigger on "/initialize_a_game <name>", "initialize a game", "start a new game project", "kick off <board game> web version". Not for games that already have a repo.
---

# Initialize a game

One command turns a board game's name into a project a team can build:
rulebook → name/licensing → plan → mockups → vault note → repo → **go** →
team setup (Phase 0) → **go** → orchestrator session (Phase 1).

The output is a decision package and a repo that can be verified, not the
game. There are two stops, each one message the owner can answer with "go"
(or with edits): everything the owner has to decide is in that message. The
milestones from M1 on are issues run by the orchestrator, not by this skill.

## Inputs

`/initialize_a_game <board game name> [slug]`

- **board game name**: the published game to base the web version on
  (e.g. "The Resistance", "Coup", "Love Letter").
- **slug** (optional): the URL and repo name, `snake_case`, ASCII. If
  omitted, propose one and confirm it in the first message. The slug
  becomes `games.csiesheep.com/<slug>/`, repo `csiesheep/<slug>`, Worker
  name `<slug>`, and the vault folder `Projects/<slug>/`.

Defaults every project has had so far (say them, do not re-ask):
solo vs AI **and** online rooms with bots filling seats; English +
Traditional Chinese from v1; phone-first; fan-made and unofficial; deploy
as one Cloudflare Worker under the `games` hub. Ask only when the game
makes one of these wrong (a two-player game has no "bots fill seats").

## Steps

Read `references/conventions.md` first — it holds the platform, repo, vault
and deploy conventions the sibling games follow, and the lessons that cost
time before. Match them; the hub expects one shape.

### 1. Rulebook

- Search for the official rulebook (publisher PDF, BGG files, the
  designer's page). Fetch it; if a PDF will not render, extract text
  (`pypdf`, `PYTHONIOENCODING=utf-8`).
- Write `references`-grade notes in your own words into
  `Projects/<slug>/<slug> - rulebook.md` in the vault: components, setup
  by player count, turn structure, win conditions, every table (player
  counts, team sizes, special cases), official variants and expansions.
  Tables as markdown tables. Never paste rulebook prose.
- List what is unclear or contradictory across sources. Those are the
  unknowns the engine tests must pin down.
- Once play-testing starts, the vault rulebook becomes the web version's
  own rule source, with its own versions (v0.1, v0.2 …). Every change is
  a draft note (`<slug> - vX.Y 草稿（…）.md`) holding the owner's words
  verbatim, the proposals, the simulation numbers and the decision; on
  adoption the rulebook is rewritten to that version (keep the previous
  one as a backup). Acceptance tests copy their numbers from it by hand,
  never from the product. (president_2000 went v0.4 → v0.7 this way.)

### 2. Name and licensing — decide this BEFORE the repo exists

Rules and mechanics are not copyrightable; **the product name is a
trademark**, and using it as the name of a similar product on a page with
ads is the real exposure. "Fan-made, unofficial" mitigates, it does not
defend. The Resistance → 天地會 and Zombie in My Pocket → Grave Errand were
both renamed after the fact; renaming later means a new repo, new Worker,
new routes and an orphaned URL.

So, in the first message to the owner:
- Explain the risk in two sentences.
- Propose 3–5 own names (bilingual) with an own setting and faction words
  that keep the play but drop the publisher's title, and recommend one.
- Ask whether to ship under the own name (recommended) or the original
  with a credit line.

The chosen name decides the slug, the repo and every string. Credit the
original exactly once, in the footer, as the design that inspired the
play. No official art, no lifted text, own rules page. Say "not legal
advice".

### 3. Plan

Write `Projects/<slug>/<slug> plan.md` from `references/plan-template.md`.
Fill every section with this game's specifics; keep the milestone shape
M0–M5 (scaffold → engine → bots → solo → rooms → ship), because the
sibling repos and the hub are built for it. Include:
- the rules in scope for v1 (base game exactly; expansions data-driven
  later),
- the bot approach (what the AI must reason about; for hidden-role games a
  posterior over role assignments, for area games a scored search),
- the balance harness (bot-vs-bot, N games per cell, child processes):
  every arm of a comparison runs on the same seeds; a scored check that
  the control arms equal main game for game, so bot changes made for a new
  option cannot move the other arms; `tests/sim.js` takes rule options as
  arguments; the owner reads wins, margin and turnout against a band
  written in the plan (president_2000: each side 25–42 %, margin ≤ 6),
- open questions with your recommended answer for each.

Convert relative dates to absolute. Commit the vault with a short message
and push.

### 4. Pages and UI

Show, do not describe: publish a mockup the owner can look at.
- Prefer the `design` skill (a canvas of phone artboards, 390×844) when it
  is available; otherwise a single HTML artifact with the phone frames
  side by side.
- One artboard per page: landing, setup, lobby, reveal/setup-in-game, the
  main table (two or three states), game over, rules. Real copy in both
  languages, no lorem ipsum.
- Settle the aesthetic with the owner: sketch two or three directions
  first if the setting is open; if the owner already named a theme (a
  Qing-era brotherhood, a haunted mortuary), commit to it and show one.
- Record the chosen tokens (colours, type, semantics of each colour) in
  the plan's "Look" section once picked.
- Phone artboards are 390×844, but draw the fold at 664 px: that is what
  an iPhone 14/15 shows in Safari with its toolbars. A page meant to need
  no scrolling (setup, lobby, game over) is designed to 664. (president_2000's
  setup page came out 760 / 916 px tall and had to be redone.)
- Upload the real assets you already have (portraits, card art) to the
  canvas and use them: grey boxes hide the real proportions.
- For a UI choice, show three versions side by side, give the trade-offs
  in the reply and recommend one. The owner usually picks one and then
  tweaks it; keep the earlier rounds on the canvas, a new round in a new row.

### 5. Repo

Only after the name is settled:
```bash
gh repo create csiesheep/<slug> --public --description "<one line>"
```
Scaffold from the newest sibling repo rather than from scratch:
`president_2000` today (it also carries the rule-version switch, the
three-state harness, the browser layout tools and the live byte-compare);
`tiandihui` for a hidden-role game. Copy `wrangler.jsonc`, `package.json`,
`src/index.js` (prefix router), `public/` skeleton, `tests/` layout and
`tests/harness.js`; strip the old game's engine, bots, strings and art. Set the git identity per conventions, commit the
scaffold, push. Do not deploy yet: the placeholder is part of Phase 0
(step 7), after the owner's go.

### 6. First stop: the decision package and the Phase 0 proposal

End with one message containing:
- the recommended name, the rulebook note link, the plan note link, the
  mockup link, the repo link;
- the open questions as a short numbered list with your recommendation for
  each;
- **the Phase 0 proposal**, also written into the plan's "Team" section:
  - the ownership table for `TEAM.md`: every file or folder of the scaffold
    and of the planned architecture, one row each, with its role (BE, FE,
    writer, artist, orchestrator);
  - the first guard: which numbers group 0 copies from the rulebook note,
    what group 1 checks (the product verb: a game can be set up and every
    seat has a legal move), and how you will break it once to show it red;
  - the placeholder deploy at `games.csiesheep.com/<slug>/` (it goes live);
  - the deploy rule for `TEAM.md`: until M5, while the pages are `noindex`,
    the orchestrator deploys and byte-checks after every land; from M5 on,
    only on the owner's go;
  - the orchestrator's first goal (normally M1) and its priorities.

Then wait. One "go" confirms all of it. If the owner edits something, apply
the edit and say what changed before starting. Nothing in steps 7 to 9
happens without this go.

### 7. Phase 0: make verification exist (on the first go)

`agent-team-delivery` §十二, Phase 0, done by this session. The session may
sit in the vault: run repo commands as `cd <repo> && …` in one call.

1. **Placeholder (M0)**: deploy, then byte-verify the live files per
   conventions.
2. **`/agent-team-delivery init <repo>`**: `TEAM.md`, `tools/orch.sh`,
   `tools/serve.py`, `tools/check_public_imports.mjs`, the starter harness
   (with `tests/acc_modules.js`: set its `SHIP` folders), `.gitignore`. If the six team
   agents are not offered by the Agent tool, run
   `bash ~/.claude/skills/setup/install.sh`.
3. **Ownership and deploy rule**: write the confirmed table and the
   confirmed deploy rule (command `npx wrangler deploy`) into `TEAM.md`
   exactly as confirmed. If the deploy copies only part of the repo into
   `public/`, put `node tools/check_public_imports.mjs public` in the deploy
   script before the upload now, while the list of folders is short. A row the owner did not confirm stays out; ask
   about it.
4. **First guard**: write the thinnest engine slice that makes the product
   verb exist (setup and the legal moves of one turn, nothing more). Group
   0's constants are copied from the rulebook note, never read from the
   product. Make it go red once: `orch falsify` → run → keep the exact line
   the guard printed → `orch restore` → `orch clean`; then run it green.
   - Build the rule version in from day one: `createGame(seed, { rules })`,
     `st.rules` kept in every saved game, new games on the current version,
     old saves keeping theirs. A test that guards a version names the
     versions it holds for (`ON = ["v0.6", "v0.7"]`, a version and the ones
     built on it), never one literal: every version switch in president_2000
     broke tests pinned to the version before.
   - For a seeded simulation, the same idea per behaviour: each change sits
     behind an engine option whose old value replays it, and goldens are
     frozen per version (conventions, Seeded replay switches).
   - Every replay or share link carries that engine version from the first
     release (`?seed=…&cv=v1`, and the server's short-link redirect adds it
     from the stored record); a link without it means the version that was
     live when links first shipped. Before each version bump, freeze the old
     version's outputs into a golden file so "old version unchanged" checks
     compare against it, not against the new code run with the old flag.
     In china_life a share link without the full replay parameters opened
     a different life for every player who scanned it, and only the owner's
     own phone scan caught it.
   - Put one browser layout tool in the starter harness: headless Chrome
     over CDP with `Emulation.setDeviceMetricsOverride` at 390×664 (phone)
     and 1440×900 (desk), measuring boxes, not screenshots alone.
     `--window-size=390` is not a phone: headless has a minimum window width
     and the screenshot only crops it.
5. **Commit and push** the repo (the message says the ownership table was
   confirmed by the owner, with the date); update the plan's Decisions and
   Next steps; commit and push the vault.

### 8. Second stop: show the red, ask to start the team

One message: the live URL and that its bytes match the repo; the `TEAM.md`
link; the harness numbers, green; **what you broke and the exact line the
guard printed when it went red** (a screenshot if the guard is a page). This
is the owner seeing it red, the gate before any work is handed out. Say
plainly that the Phase 0 slice was written and checked by this session only,
so it is the least-verified code in the repo. Ask for the go to start the
orchestrator with the confirmed goal and priorities.

### 9. Phase 1: start the orchestrator (on the second go)

The orchestrator is a new session opened in the repo, not this one: this
session's context is full of research, and subagent worktrees are cut from
the orchestrator's working folder.

- If the host can open a session for the owner (the Claude desktop app: a
  task chip via `spawn_task` with `cwd` set to the repo path, titled "Run the
  <slug> orchestrator"), create it with the opening below as its prompt. The
  owner's click starts it.
- Otherwise give the owner the folder and the opening, to paste into a new
  session started there.

The opening, with the blanks filled from the confirmed proposal:

    你是 <slug> 的 orchestrator,照 agent-team-delivery skill 和 repo 的 TEAM.md 做。
    目標:<goal>。優先序:<priorities>。
    你開 issue、寫 brief、派子 agent(§十三)、獨立驗證、land;你不寫產品程式碼。
    要 owner 裁決的事在 issue 留言標「要 owner 裁決」,我在 issue 上回。
    Phase 0 的最小引擎切片是起手的 session 寫的,沒有經過獨立驗證(§一):在那裡找到缺陷,先假設是它錯。
    先做一張 issue,走完派 → 交付 → 驗 → land,再跟我報告。

This session ends here: no more product code, nothing dispatched from it.
Tick the plan's Next steps and commit the vault. Zongheng (2026-09-18)
skipped all of this and went from kickoff to a deployed game in one session
with no independent check; steps 6 to 9 exist so that does not happen again.

## Conventions the owner expects in replies

- Traditional Chinese unless the owner writes in English; lead with the
  outcome; short sentences; numbers in tables; no em dashes.
- Commit trailer as the session's system reminder specifies.
- After every change to the plan, commit the vault.
- Never claim something is deployed or verified without having checked the
  live bytes.
