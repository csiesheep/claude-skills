# Conventions for games on games.csiesheep.com

Learned across dice_war, zombie_in_the_pocket, jiangshi_in_the_pocket,
elevator_inc, betrayal_sound_board, tiandihui and president_2000. Follow
unless the owner says otherwise.

## Platform

- **One Cloudflare Worker per game**, attached to the shared hostname by
  two path-scoped Routes (`games.csiesheep.com/<slug>` and `/<slug>/*`,
  zone `csiesheep.com`). The hub Worker `games` owns the hostname as a
  Custom Domain and serves `/`, `robots.txt`, `ads.txt`, `sitemap.xml`.
- `src/index.js` is a **path-prefix router**: `PREFIX = "/<slug>"`;
  bare prefix 301s to the trailing-slash form; `/<slug>/ws` upgrades to
  the room Durable Object; `/<slug>/sitemap.xml` is prefix-scoped; other
  paths strip the prefix and go to `env.ASSETS` with `run_worker_first`.
  Same-origin redirects from the asset handler must get the prefix put
  back (see tiandihui `src/index.js`).
- **Static assets** in `public/`; `src/` is bundled. Query-string routes
  (`?play`, `?room=ABCD`, `?lang=`) so one build works at any prefix.
- **Rooms** are one Durable Object per room, named by a 4-letter code
  (alphabet without 0/O/1/I), WebSocket Hibernation API, one alarm for all
  timers, per-seat `view(state, seat)` is the only data that leaves the
  object. Bots fill empty seats and take over disconnected humans after a
  grace period; the tab's token in sessionStorage reclaims a seat.
- **Shared engine**: `public/shared/engine.js` is pure and runs in both
  the browser (solo) and the DO. Seeded RNG in the state
  (mulberry32) so games replay from seed + actions. `clone` is a JSON
  clone, not `structuredClone` (V8 crash on this machine).
- **Bots** in `public/shared/bots.js`, table talk templates in
  `public/shared/talk.js`; every decision carries a `why` for talk.
- **i18n**: all player-visible strings in `public/i18n/en.js` and
  `public/i18n/zh-Hant.js`; `app.js` carries no prose. Chinese numerals
  helper (`nums`) where the design calls for 一二三.
- **Rule versions** (president_2000): the engine takes `createGame(seed,
  { rules })` and stores `st.rules`; new games start on the current
  version, a saved game keeps its own. The text tests keep a `V0x_ONLY`
  list of strings only an older version shows (never deleted or changed by
  a later version) and, per version switch, a check that no other string
  uses the words that version took out.
- Text lands and deploys before the code that uses it: a changed string
  may only use the `{placeholders}` it already had, or the live page shows
  a raw `{luck}` until the code lands.
- Card texts are shared by every rule version. Decide at the start whether
  they are versioned; if not, a version switch shows games saved on the
  old version the new wording (president_2000 accepted that).
- Fonts from Google Fonts only; the hub loads only faces a tile uses.

## Repo

- `csiesheep/<slug>`, public, `main`. Git identity per repo:
  `git config user.name csiesheep`, `user.email csiegoat@gmail.com`,
  `core.autocrlf false`.
- `package.json` scripts: `dev` (`wrangler dev`), `deploy`, `test`
  (`node --test`, not `node --test tests/` on Windows), `sim`.
- Tests: `tests/engine.test.js`, `tests/bots.test.js`, `tests/room.test.js`
  (fake DO context), `tests/sim.js` bot-vs-bot harness with `--cell` child
  processes and retries.
- README: what it is, fan-made line, how it works, milestones, develop.
- Commit messages: a sentence, then why, then the session's trailer.

## Deploy and verify

- `npx wrangler deploy` from the repo on the local machine; the dashboard
  is not connected, pushes do not deploy.
- After deploy, byte-compare live files to the repo with sha1 and
  cache-busting retries (`?v=$RANDOM`); the edge briefly serves stale
  files. `/<slug>/index.html` redirects — compare `/<slug>/` instead.
  One differing file right after a deploy is usually the edge: run the
  whole compare again and compare the files the land changed on their own
  before calling it a defect (president_2000 #58: 125/1, then 126/0).
- `wrangler dev` serving a tree you check other commits out in, or one next
  to worktrees you remove, can fail with "Could not resolve …" and then
  hang without answering. `curl -s -m 5` the page before any measurement;
  restart the server if it does not answer.
- `workerd` can be relaunched by its parent: stop the topmost `wrangler`
  `node` process by PID, then check the port is free.
- Local: `npx wrangler dev --port 8788` in the background; stop with
  PowerShell `Get-NetTCPConnection -LocalPort 8788` → `Stop-Process`, and
  kill leftover `workerd`. `workerd` sometimes dies with 0xC0000005 on
  this machine; retry, or serve `public/` with `python -m http.server`
  for pure-static checks.
- Node 24 on this Windows box crashes randomly (access violation) on long
  runs: the harness runs cells as child processes with retries. Treat as
  environmental; re-run a failed test once before believing it.
- Browser pane: `file://` is refused; use a server. Coordinates are
  unreliable — click by `ref` or drive with `javascript_tool`. Hidden
  overlays keep their DOM (`#btnPeek` exists while hidden).

## Shell and browser on this machine

- Bash heredocs here, even quoted (`<<'EOF'`), lose one level of
  backslash: `\\b` arrives as `\b`, which a JS string turns into U+0008.
  Write any code that holds backslashes (regexes, escapes) with the file
  Write/Edit tools, never through a heredoc or `node -e`; after generating
  code, scan it for control characters. (president_2000: an English
  forbidden-word guard matched nothing from #56 to #59.)
- Measuring pages: headless Chrome with a fresh profile per run and
  `--remote-debugging-port=0` (read the port from `DevToolsActivePort`);
  phone widths only through CDP `Emulation.setDeviceMetricsOverride`
  (`--window-size=390` is not a phone: headless has a minimum window width
  and the screenshot only crops it). A run that times out leaves Chrome
  behind: stop it by PID (its command line carries the profile name).
  Never the owner's Chrome, never the desktop app's browser pane (shared
  tabs, a tab cap).
- Phone targets: 390×664, an iPhone 14/15 in Safari with its toolbars, is
  the scored size; print 375×548 (iPhone SE in Safari) as a reading; taps
  at least 44 px.
- Scratch output, logs and probe trees never under `C:\Users\sheep\code\`;
  say so in every agent's brief.

## Vault

- `C:\Users\sheep\code\obsidian\Projects\<slug>\<slug> plan.md` and
  `<slug> - rulebook.md`. Commit and push the vault after every plan
  change. Keep a Decisions list with absolute dates and a Next steps
  checklist with dates on the ticked items.

## Ship (M5) checklist

- Drop `noindex` on both pages; OG + Twitter cards; `VideoGame` JSON-LD;
  1200×630 social image (Pillow with local fonts works: `kaiu.ttf`,
  `NotoSerifTC-VF.ttf`); a crawlable paragraph on the landing.
- Hub (`C:\Users\sheep\code\games`): a tile in `index.html` painted from
  the game's own stylesheet in `css/style.css`, a `SITEMAP_URLS` line with
  lastmod, a `robots.txt` Sitemap pointer to the game's own sitemap if it
  has inner pages, the tile's fonts in the hub font link. Never list a
  page in the sitemap while it is still `noindex`.
- Search Console submission is the owner's manual step. AdSense is a
  separate decision.
- In the same change that drops `noindex`, switch the deploy rule in
  `TEAM.md` to "only on the owner's go": from then on a land is not a ship.

## Licensing position (not legal advice)

Rules are not copyrightable; the trademark is the risk. Own name, own
setting, own faction words, own art and prose; credit the original once
in the footer as the design that inspired the play. Decide the name
before creating the repo — every rename so far cost a new repo, Worker
and URL.
