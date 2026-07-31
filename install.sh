#!/usr/bin/env bash
# claude-boink installer — symlinks the skill globally, optionally wires it into CLAUDE.md.
# Idempotent: safe to re-run.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
LINK="$SKILLS/boink"
CLAUDEMD="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md"

WITH_CLAUDEMD=0
for arg in "$@"; do
  case "$arg" in
    --claudemd) WITH_CLAUDEMD=1 ;;
    -h|--help)
      echo "usage: install.sh [--claudemd]"
      echo "  --claudemd   also append the always-on stanza to $CLAUDEMD"
      exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

mkdir -p "$SKILLS"

if [ -L "$LINK" ]; then
  current="$(readlink -f "$LINK")"
  if [ "$current" = "$REPO" ]; then
    echo "ok      symlink already points here: $LINK -> $REPO"
  else
    echo "error   $LINK is a symlink to $current, not $REPO" >&2
    echo "        remove it first if you want to replace it" >&2
    exit 1
  fi
elif [ -e "$LINK" ]; then
  echo "error   $LINK exists and is not a symlink; refusing to overwrite" >&2
  exit 1
else
  ln -s "$REPO" "$LINK"
  echo "linked  $LINK -> $REPO"
fi

if [ "$WITH_CLAUDEMD" -eq 1 ]; then
  if [ -f "$CLAUDEMD" ] && grep -q '^# boink$' "$CLAUDEMD"; then
    echo "ok      CLAUDE.md already has a boink stanza"
  else
    cat >> "$CLAUDEMD" <<'STANZA'

# boink
- **boink** (`~/.claude/skills/boink/SKILL.md`) — passive anti-stall watchdog.
  ALWAYS ACTIVE, no invocation needed. Whenever you create a semantic monitor
  (Monitor tool, background wait, poll loop, CI/build/deploy watch, or any turn
  ending in "I'll check back when…"), immediately arm a recurring BOINK via
  `CronCreate(cron: "2-59/5 * * * *", prompt: "BOINK", recurring: true)` — one
  per session, check `CronList` first. On each BOINK, follow the protocol in
  SKILL.md: re-observe with a fresh command, never answer from memory, classify
  (PROGRESSING / DONE / STALLED / DEAD / MONITOR-BROKEN), act, then recount and
  `CronDelete` if zero semantic monitors remain.
STANZA
    echo "wrote   boink stanza appended to $CLAUDEMD"
  fi
else
  echo "note    re-run with --claudemd to make it always-on via CLAUDE.md"
fi

echo "done    restart Claude Code (or start a new session) to pick it up"
