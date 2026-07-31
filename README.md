# claude-boink

**A timeout for every monitor Claude ever creates.**

`BOINK` is a passive, always-on Claude Code skill. It needs no invocation. The
moment Claude creates a semantic monitor — a `Monitor` task, a background build,
a CI watch, a poll loop, or even just a turn that ends in *"I'll check back when
it's done"* — a contentless prompt saying `BOINK` starts arriving every five
minutes, and keeps arriving until nothing is being waited on anymore.

## The problem

Agents write conditional monitors that stall, and then wait on them forever.

Every monitor exits on a predicate the agent guessed at while thinking about the
happy path: a `grep` filter, an `until` loop, a poll checking for one status
string. Then reality does something else:

- the process crashed, and the filter only matched the success line
- the log rotated, and `tail -f` is following an unlinked inode
- the build finished during the same turn it was armed, and the watch is tailing
  a file nothing will ever append to again
- a pipe stage buffered the match into oblivion
- the monitor timed out and was reaped, and nobody noticed
- the condition was impossible from the start — a typo'd path, a job ID that
  never existed

All of these produce the same observable: **silence.** And silence is
indistinguishable from *"still running, going fine."*

That ambiguity is the bug. An agent sitting in silence has no pressure to
re-examine anything, so it doesn't. From the outside it looks like diligent
monitoring. From the inside, nothing whatsoever is happening — for hours.

## The fix

A BOINK is the machine equivalent of a user leaning over and saying:

> "and?"
>
> "what's up?"
>
> "it's been 7 hours, wtf is your demented monitor doing"

It carries no information, no instruction, and no data. It is a **prod**, and its
only job is to force a turn to happen when one would not otherwise happen.

Because it fires on wall-clock time and on nothing else, it cannot be starved by
a broken predicate — it doesn't have one. It's a heartbeat that comes from
*outside* the thing it's checking, which is the only kind worth having.

> Never let the liveness of your monitoring depend on the correctness of your
> monitor.

## How it works

A BOINK fires when **both** hold:

1. **The REPL is idle** — `CronCreate` guarantees this half for free; jobs never
   interrupt a turn in progress.
2. **At least one semantic monitor is still active** — the skill enforces this
   half, arming when the first one appears and disarming when the last one goes.

Idle *and* waiting-on-something is precisely the stall state.

```
CronCreate(cron: "2-59/5 * * * *", prompt: "BOINK", recurring: true)
```

One BOINK per session, not one per monitor. Five concurrent monitors share a
single BOINK; each firing sweeps all of them.

*(`2-59/5` rather than `*/5` — same 5-minute period, but it avoids the `:00` and
`:30` marks that every scheduler on the planet piles onto.)*

On each arrival, Claude runs a six-step protocol: **don't answer from memory →
re-observe with a fresh command → diff against the last BOINK → classify →
act → recount and disarm if empty.**

The classification commits to one word, no hedging:

| | |
| --- | --- |
| **PROGRESSING** | Evidence of motion. Cite the number. |
| **DONE** | Already finished — the monitor missed it. |
| **STALLED** | Alive but not moving. |
| **DEAD** | Process is gone. |
| **MONITOR-BROKEN** | The watched thing is fine; the *watcher* isn't. |

`DONE` and `MONITOR-BROKEN` are the two that justify the whole thing. They're the
states an agent in silence will never discover on its own, because in both cases
the notification that was supposed to arrive is precisely what's broken.

Repeated identical answers are themselves a failure, so there's an escalation
ladder: note it, widen the observation, say **STALLED**, then stop waiting and
surface it with a recommendation. *"Wait a bit longer"* is locally reasonable at
every step and globally catastrophic.

Step six is what terminates the loop — every BOINK is also a refcount check, so
the mechanism that fires it is the same one that notices it's no longer needed.

## Install

```sh
git clone https://github.com/fcecin/claude-boink.git ~/claude-boink
ln -s ~/claude-boink ~/.claude/skills/boink
```

Or run the installer, which does both and is idempotent:

```sh
git clone https://github.com/fcecin/claude-boink.git ~/claude-boink
~/claude-boink/install.sh
```

Symlinking (rather than copying) means `git pull` updates the live skill.

### Making it genuinely always-on

Claude Code surfaces skills by description and loads them when they look
relevant. For a passive ability that should never be missed, add a stanza to
`~/.claude/CLAUDE.md` so it's in context in every session:

```markdown
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
```

`install.sh --claudemd` appends this for you if it isn't already there.

## Manual overrides

The ability is automatic; these exist for steering it.

| Command | Meaning |
| --- | --- |
| `/boink` | Arm now, even with no monitor active. |
| `/boink 15m` | Re-arm at a different interval. |
| `/boink --loud` | Re-arm with a self-describing prompt (survives context compaction). |
| `/boink status` | What's armed, and what's being watched. |
| `/boink off` | Disarm and stand down for this session. |

## Limits

- **Session-only.** Cron jobs are in-memory and don't survive a restart.
- **Idle-only.** BOINKs never interrupt a turn in progress; several may coalesce.
- **Jitter.** Up to 10% of the period late — ~30s for a 5-minute BOINK.
- **7-day expiry.** Recurring jobs auto-delete after a week, with no reminder.
- **Not free.** Each BOINK is a real turn with real tokens. For very long waits,
  `7-59/15` or `13-59/30` buys the same protection far cheaper — the value is in
  *unconditional recurrence*, not in frequency.

## License

MIT — see [LICENSE](LICENSE).
