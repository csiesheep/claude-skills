#!/usr/bin/env bash
# Installs the user-level Claude Code config kept in this repo:
#   setup/CLAUDE.md                              -> ~/.claude/CLAUDE.md
#   agent-team-delivery/references/agents/*.md   -> ~/.claude/agents/
# This repo is the source of truth: edit here, then run this again.
# A target that differs from the repo is shown as a diff and left alone,
# so a local edit is never lost silently; --force replaces it.
# CLAUDE_CONFIG_DIR, if set, is used instead of ~/.claude.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
dest="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
force=0
[ "${1:-}" = "--force" ] && force=1
new=0 same=0 replaced=0 kept=0

install_one() { # $1 source in this repo, $2 target
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ ! -e "$dst" ]; then
    cp "$src" "$dst"; echo "new       $dst"; new=$((new + 1))
  elif cmp -s "$src" "$dst"; then
    same=$((same + 1))
  elif [ "$force" = 1 ]; then
    cp "$src" "$dst"; echo "replaced  $dst"; replaced=$((replaced + 1))
  else
    echo "differs   $dst (left alone; run with --force to replace)"
    diff -u "$dst" "$src" | head -n 20 || true
    kept=$((kept + 1))
  fi
}

install_one "$repo/setup/CLAUDE.md" "$dest/CLAUDE.md"
for f in "$repo"/agent-team-delivery/references/agents/*.md; do
  install_one "$f" "$dest/agents/$(basename "$f")"
done

echo "new $new, already current $same, replaced $replaced, left alone $kept"
[ "$kept" = 0 ]
