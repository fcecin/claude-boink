# claude-boink

**A timeout for every monitor Claude ever creates.**

Passive, always-on Claude Code skill. The moment Claude creates a monitor — a
`Monitor` task, a background build, a CI watch, or just a turn ending in *"I'll
check back when it's done"* — a contentless prompt saying `BOINK` starts arriving
every five minutes, and keeps arriving until nothing is being waited on.

## Why

Monitors exit on a predicate the agent guessed at: a `grep` filter, an `until`
loop, a poll checking one status string. When the guess is wrong — process
crashed, log rotated, filter can never match, monitor timed out — the result is
**silence**, which is indistinguishable from *"still running, going fine."*
Agents wait in that silence for hours.

A BOINK is the machine equivalent of *"and?" "what's up?" "it's been 7 hours, wtf
is your demented monitor doing"*. It fires on wall-clock time and nothing else,
so a broken predicate can't starve it.

## How

```
CronCreate(cron: "2-59/5 * * * *", prompt: "BOINK", recurring: true)
```

Fires when the REPL is idle **and** a monitor is still live — precisely the stall
state. One per session; concurrent monitors share it.

Each arrival: never answer from memory → re-observe with a fresh command → diff
against the last BOINK → classify **PROGRESSING / DONE / STALLED / DEAD /
MONITOR-BROKEN** → sweep → recount and disarm at zero.

`DONE` and `MONITOR-BROKEN` are the point: in both, the notification that should
have arrived is itself what's broken.

**The sweep** reaps what a session accumulates — finished shells, timed-out
monitors, idle agents, stale task entries, orphaned cron jobs. It's load-bearing,
not tidiness: a dead monitor still counts, so without it the refcount never
reaches zero and the BOINK never disarms. Cardinal rule is **harvest before
reap** — a finished shell holds the result you were waiting for. Nothing that
isn't yours, is still running, or is unharvested gets reaped automatically.

Full protocol in [SKILL.md](SKILL.md).

## Install

```sh
git clone https://github.com/fcecin/claude-boink.git ~/claude-boink
~/claude-boink/install.sh
```

Symlinks the skill into `~/.claude/skills/boink` and adds a trigger line to
`~/.claude/CLAUDE.md` — a pointer only; the protocol stays in `SKILL.md` and
loads on demand.

```
install.sh [install|status|uninstall] [--no-claudemd]
```

Idempotent. The `CLAUDE.md` edit sits between `<!-- boink:begin -->` markers, so
re-running updates it in place rather than appending a duplicate, and `uninstall`
removes it cleanly. `CLAUDE.md` is backed up before any change.

## License

MIT
