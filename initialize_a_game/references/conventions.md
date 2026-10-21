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
  paths go to `env.ASSETS`.
- **Static files must not run the Worker.** With `run_worker_first: true`
  every JS module, image and sound is a billed Worker request (free plan:
  100 000 a day, then 429 instead of the page). Build the site into
  `public/<slug>/` so asset paths equal URLs, and list only what needs code
  in `run_worker_first`: `["/<slug>", "/<slug>/api/*", "/<slug>/r/*", "/<slug>/ws"]`.
  A miss still falls back to the Worker. china_life: one visit plus two lives
  went from 204 Worker requests to 6 (all API). Older repos (tiandihui)
  strip the prefix in the Worker and must put it back on same-origin
  redirects; new repos should not need that.
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
- **Seeded replay switches** (china_life, a seeded life simulator): every
  behaviour change goes behind an engine option whose old value replays the
  previous behaviour (`mortality: 'v1'`, `decisionEffects: 'off'`). Golden
  files are frozen per version (`pre_v7.json` with `generated_from` = the
  SHA) and the tests read the newest one, with a TODO until the
  orchestrator freezes the next. A new product rule that would move many
  seeds can be opt-in at the engine and passed by the page on every call
  (`birthCap: 1940`), so no golden has to be refrozen. A redraw uses its
  own RNG stream, never the main one, so a seed that is not redrawn stays
  identical and shared replay links keep working; the test for that
  compares the redrawn lives, because the untouched ones cannot tell.
- Text lands and deploys before the code that uses it: a changed string
  may only use the `{placeholders}` it already had, or the live page shows
  a raw `{luck}` until the code lands.
- Card texts are shared by every rule version. Decide at the start whether
  they are versioned; if not, a version switch shows games saved on the
  old version the new wording (president_2000 accepted that).
- Fonts from Google Fonts only; the hub loads only faces a tile uses.
- **Analytics**: one GA4 property for the whole hostname (`G-Q4VS3P3T58`,
  property "games.csiesheep.com"; the blog csiesheep.com is a different
  property). Load gtag after `load`, consent default denied in EEA/UK/CH.
  **`?internal=1`** marks the tab internal in `sessionStorage`
  (`<slug>.internal=1`; `?internal=0` clears it): no gtag, no GA events,
  no telemetry POST (a game's own stats endpoint), on every page of the
  game. Every live check, probe and headless playthrough carries it. The
  acceptance pair: an internal visit loads no gtag and records no upload,
  and a control visit without it does record one (so the measure is
  alive; dedupe of already-reported lives can hide it — clear local
  records first).

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
- The tested tree is not the deployed tree. If the deploy copies a subset
  into `public/` (a build script with a folder whitelist, a bundler), run
  `node tools/check_public_imports.mjs public` before the upload: every
  relative import in the uploaded tree must resolve. (china_life: a new
  `data/geo/` was imported by the map but missing from the whitelist; the
  live page loaded no modules while every test was green.)
- **Bundle at deploy time, not in the repo.** A module-per-file game sends
  one request per module (china_life: 86 JS files, 91 requests per visit).
  The build runs esbuild over the HTML entry points in `public/` with code
  splitting and hashed names, rewrites the script tags, deletes the
  bundled sources, and writes `public/_headers` (the assets root, not
  `public/<slug>/`) with `Cache-Control: public, max-age=31536000,
  immutable` for the hashed folder. Keep splitting: one bundle would make
  the landing page download the whole game. Tests keep running on the
  unbundled repo, so a smoke test of the built `public/` under
  `wrangler dev` is the acceptance (first-visit requests, second visit
  serves the first visit's JS from cache, one full playthrough, each page
  finishes drawing — a title check alone misses a broken module graph).
  Read cache hits from `Network.requestServedFromCache`, and reload the
  same URL for the second visit.
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
- Give headless Chrome a short `--user-data-dir` (for example
  `%TEMP%\cp_<port>`). With a long profile path it starts without opening
  its debug port and says nothing; the script just times out.
- Run the browser test suite in headless Chrome, not in the desktop app's
  pane: a hidden pane throttles timers. An offscreen iframe does not
  advance CSS transitions either, so time steps by DOM insertion, and call
  `getAnimations().forEach(a => a.finish())` (one try per animation;
  infinite ones throw) before reading a computed colour or opacity. Read
  the result from the harness's own state (`import('/tests/harness.js')`
  → `R`) after it finishes, instead of waiting for a summary line.
- The owner often reviews on a phone, where widgets drawn in the chat do
  not show. Send screenshots and mockups as image files; for a live page,
  take them from the deployed origin with the phone size above.
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
  separate decision, and it is judged on the **root domain**: AdSense
  sites are root domains only, so games.csiesheep.com rides on the review
  of csiesheep.com (the WordPress blog). The blog was refused for "low
  value content" in 2026-10; game pages cannot fix that (plan:
  `obsidian/Projects/blog improvement.md`). H5 Games Ads needs an approved
  account and site first, then its own application form.
- In the same change that drops `noindex`, switch the deploy rule in
  `TEAM.md` to "only on the owner's go": from then on a land is not a ship.

## Licensing position (not legal advice)

Rules are not copyrightable; the trademark is the risk. Own name, own
setting, own faction words, own art and prose; credit the original once
in the footer as the design that inspired the play. Decide the name
before creating the repo — every rename so far cost a new repo, Worker
and URL.
