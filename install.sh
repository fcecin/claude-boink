#!/usr/bin/env bash
# claude-boink installer.  install (default) | status | uninstall  [--no-claudemd]
# Idempotent. The CLAUDE.md block sits between markers and is updated in place.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
LINK="$CFG/skills/boink"
CLAUDEMD="$CFG/CLAUDE.md"
SRC="$REPO/claude-md-block.md"
BEGIN='<!-- boink:begin — managed by claude-boink/install.sh; edits here are overwritten -->'
END='<!-- boink:end -->'

CMD=install; WITH_MD=1
for a in "$@"; do case "$a" in
  install|status|uninstall) CMD="$a" ;;
  --no-claudemd) WITH_MD=0 ;;
  -h|--help) sed -n '2p' "${BASH_SOURCE[0]}" | sed 's/^# //'; exit 0 ;;
  *) echo "unknown argument: $a" >&2; exit 2 ;;
esac; done

say() { printf '%-8s %s\n' "$1" "$2"; }
[ -f "$SRC" ] || { echo "error    missing $SRC" >&2; exit 1; }

md_state() {
  if [ ! -f "$CLAUDEMD" ] || ! grep -qF 'boink:begin' "$CLAUDEMD"; then echo absent; return; fi
  if diff -q <(awk '/boink:begin/{i=1;next} /boink:end/{i=0} i' "$CLAUDEMD") "$SRC" >/dev/null 2>&1
    then echo current; else echo stale; fi
}

backup() { if [ -f "$CLAUDEMD" ]; then cp "$CLAUDEMD" "$CLAUDEMD.bak.$(date +%Y%m%d%H%M%S)"; fi; }

write_md() {
  local s t; s="$(md_state)"
  if [ "$s" = current ]; then say ok "CLAUDE.md block is current"; return; fi
  backup; t="$(mktemp)"
  if [ "$s" = stale ]; then
    awk -v b="$BEGIN" -v e="$END" -v f="$SRC" '
      /boink:begin/ { print b; while ((getline l < f) > 0) print l; print e; i=1; next }
      /boink:end/ { i=0; next } i { next } { print }' "$CLAUDEMD" > "$t"
    say update "refreshed boink block in $CLAUDEMD"
  else
    : > "$t"
    if [ -f "$CLAUDEMD" ]; then cat "$CLAUDEMD" > "$t"; fi
    if [ -s "$t" ]; then printf '\n' >> "$t"; fi
    { printf '%s\n' "$BEGIN"; cat "$SRC"; printf '%s\n' "$END"; } >> "$t"
    say write "added boink block to $CLAUDEMD"
  fi
  mv "$t" "$CLAUDEMD"
}

remove_md() {
  local t
  if [ "$(md_state)" = absent ]; then say ok "no boink block in CLAUDE.md"; return; fi
  backup; t="$(mktemp)"
  awk '/boink:begin/{i=1;next} /boink:end/{i=0;next} i{next} {print}' "$CLAUDEMD" > "$t"
  printf '%s\n' "$(cat "$t")" > "$CLAUDEMD"; rm -f "$t"
  say remove "stripped boink block from $CLAUDEMD"
}

linked() { [ -L "$LINK" ] && [ "$(readlink -f "$LINK")" = "$REPO" ]; }

case "$CMD" in
  install)
    if linked; then
      say ok "already linked: $LINK"
    elif [ -e "$LINK" ] || [ -L "$LINK" ]; then
      echo "error    $LINK already exists; remove it first" >&2; exit 1
    else
      mkdir -p "$CFG/skills"; ln -s "$REPO" "$LINK"; say linked "$LINK -> $REPO"
    fi
    if [ "$WITH_MD" -eq 1 ]; then write_md; else say skip "CLAUDE.md untouched"; fi
    say done "start a new session to pick it up"
    ;;
  status)
    say repo "$REPO"
    if linked; then say skill "installed at $LINK"; else say skill "not installed"; fi
    say block "$(md_state) in $CLAUDEMD"
    ;;
  uninstall)
    if linked; then rm -f "$LINK"; say removed "$LINK"; else say ok "nothing linked at $LINK"; fi
    if [ "$WITH_MD" -eq 1 ]; then remove_md; else say skip "CLAUDE.md untouched"; fi
    ;;
esac
