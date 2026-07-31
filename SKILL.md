---
name: boink
description: "ALWAYS ACTIVE, no invocation needed. Whenever you create a semantic monitor (Monitor tool, background Bash, poll loop, CI/build/deploy watch, or any turn ending in 'I'll check back when X'), arm a recurring BOINK — a contentless prompt injected every 5 minutes while the REPL is idle and a monitor is still live. Each BOINK forces a fresh evidence-based status check and sweeps the dead shells, monitors, agents, task entries and cron jobs a session accumulates. Catches monitors that silently died, filters that can never match, and conditions met an hour ago. Disarms when no live monitors remain."
---

# BOINK

Passive ability. Nobody asks for it; you arm it yourself.

> Create a semantic monitor → arm a BOINK. No live monitors left → disarm it.

## Why

Monitors exit on a predicate you guessed at while thinking about the happy path.
When the guess is wrong — process crashed, log rotated, filter can never match,
monitor timed out, condition impossible from the start — the result is
**silence**, and silence is indistinguishable from "still running, going fine."
Agents wait in that silence for hours.

A BOINK is the user leaning over and saying *"and?" "what's up?" "it's been 7
hours, wtf is your demented monitor doing"*. It fires on wall-clock time and
nothing else, so a broken predicate cannot starve it.

> Never let the liveness of your monitoring depend on the correctness of your
> monitor.

## Arm

One per session, not one per monitor. Check `CronList` first.

```
CronCreate(cron: "2-59/5 * * * *", prompt: "BOINK", recurring: true)
```

(`2-59/5`, not `*/5` — same 5 minutes, avoids the `:00`/`:30` pileup.)

A **semantic monitor** is any wait that outlives the turn: a `Monitor` task,
`Bash(run_in_background: true)`, a poll loop, a CI/deploy/build watch — including
a turn that merely ends in "I'll check back when…" with no tool armed at all.
That last one strands agents hardest, because nothing exists to remind you.

## On each BOINK

**1. Never answer from memory.** If your answer could have been written before
the BOINK arrived, you skipped the protocol.

**2. Re-observe.** `TaskList` and `CronList` first — *is my monitor even alive?*
Then the thing itself:

```bash
ps -p "$PID" -o pid,etime,stat,%cpu,cmd
tail -n 30 run.log
stat -c '%y %s' run.log       # unchanged across 3 BOINKs = tailing a corpse
gh run view "$RUN_ID"
```

**3. Diff against the last BOINK.** The signal is the delta, not the state.

**4. Classify — one word, no hedging.**

| | |
|---|---|
| **PROGRESSING** | Motion since last BOINK. Cite the number. |
| **DONE** | Already finished; the monitor missed it. Stop waiting. |
| **STALLED** | Alive, not moving. Say how many BOINKs. |
| **DEAD** | Gone. Report exit status and log tail. |
| **MONITOR-BROKEN** | Watched thing is fine, the watcher isn't. Re-arm *corrected*, never identical. |

**DONE** and **MONITOR-BROKEN** are why this exists — in both, the notification
that should have arrived is itself the broken thing.

**5. Sweep** (below).

**6. Recount live monitors.** Zero → `CronDelete` the BOINK now. A dead monitor
still shows in the inventory; count corpses and it never disarms.

Report in one line, with a number in it:

> BOINK — DONE. `run.log:4610` reads `FINISHED exit=0`, 11 min ago; the filter wanted `elapsed_steps=` and never matched. Swept 2 shells, 1 dead monitor. Zero live — disarming.

**Escalate.** Three no-change BOINKs → say STALLED and state a hypothesis. Four+
→ stop waiting, surface it with a recommendation. "Wait a bit longer" is
reasonable every single time and catastrophic in aggregate.

## The sweep

Sessions silt up: shells finished but never collected, monitors timed out
(default **300 s**, about one BOINK) or auto-stopped for event volume, agents
idle after delivering, task entries stale, cron jobs outliving their subject.
Step 2 already enumerates all of it — reap on the way through.

**Harvest before reap.** A finished background shell is the result you waited
for, and usually the DONE signal itself. `Read` its output file, *then*
`TaskStop`. (`TaskOutput` is deprecated. Never `Read` a `local_agent` `.output`
— it is the full subagent transcript and will flood your context.)

| Reap | With |
|---|---|
| Background shell, monitor, agent | `TaskStop(task_id)` after harvesting |
| Task entry | `TaskUpdate` → `completed` (real work) or `deleted` (created in error) |
| Cron job | `CronDelete` |
| Your own temp files | `rm` on paths you created |

**Never auto-reap** anything that isn't yours, is still running, is unharvested,
or lives outside your scratchpad — report it and ask. No `pkill` by pattern: a
bare `pkill node` takes out the user's editor and dev server. In doubt, leave it.
A stray corpse costs one line of noise; a wrong kill destroys the run.

The sweep is secondary. A BOINK reporting tidy housekeeping while omitting
whether the build is alive has failed.

## Limits

- **Session-only** — in-memory, gone on restart. `durable` does nothing.
- **Idle-only** — never interrupts a turn; several BOINKs may coalesce.
- **7-day expiry** on recurring jobs, with no reminder.
- **Costs tokens.** For long waits `7-59/15` or `13-59/30` buys the same
  protection cheaper — the value is unconditional recurrence, not frequency.

`/boink` arm now · `/boink sweep` sweep now · `/boink off` disarm and stand down.
