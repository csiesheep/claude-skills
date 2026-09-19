# New machine

This repo is `~/.claude/skills`. Two pieces of user-level config are kept here
too and installed next to it:

| In this repo | Installed to |
|---|---|
| `setup/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `agent-team-delivery/references/agents/*.md` | `~/.claude/agents/` |

Edit them here, then run the installer again. A target that differs from the
repo is shown as a diff and left alone; `--force` replaces it.

## Steps

1. Install Claude Code and sign in.
2. Clone this repo with its submodules:
   `git clone --recurse-submodules https://github.com/csiesheep/claude-skills.git ~/.claude/skills`
3. `bash ~/.claude/skills/setup/install.sh`
4. Open a new session and check that the Agent tool offers `peer-be`, `peer-fe`,
   `peer-writer`, `peer-artist`, `peer-chore` and `orch-checker`.

## Not in this repo

- Tools the games need: git with the identity in
  `initialize_a_game/references/conventions.md`, `gh auth login`, Node,
  `npx wrangler login`.
- The Obsidian vault (plans, rulebooks, decisions) and each game repo: clone
  them separately.
- Claude's auto-memory stays on the old machine. The vault notes are the
  record that travels.
- `peer-artist` expects ComfyUI at `http://127.0.0.1:8000`. Without it, art
  issues come back blocked.
