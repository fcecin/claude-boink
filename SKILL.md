---
name: boink
description: "ALWAYS ACTIVE — passive ability, no invocation needed. The timeout every monitor should have had, plus the garbage collector a live session never had. Whenever you create a semantic monitor (Monitor tool, background wait, poll loop, CI/deploy/build watch, 'I'll check back when X'), also arm a recurring BOINK: a contentless prompt injected every 5 minutes while the REPL is idle and at least one semantic monitor is still active. Each BOINK forces a fresh, evidence-based re-observation AND a sweep that harvests then reaps everything accumulating in the session — dead background shells, dead monitors, finished agents and teammates, stale task-list entries, orphaned cron jobs, leaked processes and temp files. Catches monitors that silently died, filters that can never match, and conditions met an hour ago, instead of hanging forever. Disarms only when zero live semantic monitors remain."
---

# BOINK

## This is a passive ability

You do not wait to be asked for this. There is no command to run first, no
trigger phrase to detect, no user request to satisfy. **BOINK is omnipresent and
automatic.** It is loaded in every session and it engages on its own, the moment
you create a monitor.

Treat it the way you treat the shell being available: not a feature you invoke,
but a property of the environment you work in.

The rule, complete, in one line:

> **Create a semantic monitor → arm a BOINK. Zero semantic monitors left →
> disarm it.**

Everything below is elaboration on that line.

## What a BOINK is

A BOINK is the machine equivalent of the user leaning over and saying:

> "and?"
>
> "what's up?"
>
> "it's been 7 hours, wtf is your demented monitor doing"

That is the entire semantics. Nothing more is encoded in the word. It carries no
new information, no instruction, and no data — it is a **prod**, and its only
function is to force a turn to happen when one would not otherwise happen.

### It is a timeout for every monitor

That is the cleanest way to hold it. Every monitor you create *should* have had a
timeout — a point at which, if the expected thing has not happened, someone goes
and looks. Almost none of them do. The BOINK is that timeout, applied uniformly,
to all of them at once, forever, without you having to remember to attach one.

Unlike a real timeout it does not cancel anything, and it does not fire once. It
repeats every 5 minutes for as long as anything is being waited on. It is less a
deadline than a pulse.

### Why it has to exist

> **Agents write conditional monitors that stall, and then wait on them forever.**

A conditional monitor is any wait whose exit depends on a predicate you guessed
at: a `grep` filter, an `until` loop, a poll checking for one status string, a
`Monitor` watching for a success marker. The predicate is written optimistically,
at the moment of arming, by an agent thinking about the happy path. Then reality
does something else, and the predicate never becomes true:

- The process **crashed** and the filter only matched the success line.
- The log **rotated**, so `tail -f` is now following an unlinked inode.
- The build **already finished** — during the same turn it was armed — and the
  watch is tailing a file nothing will ever append to again.
- A pipe stage **buffered** the match into oblivion (`| head -1`, un-flushed
  `grep`, un-`fflush`ed `awk`).
- The monitor **timed out** and was reaped, and nobody noticed.
- The condition was **impossible from the start** — a typo'd path, a job ID that
  never existed, a status string the tool does not emit.

Every one of these produces the same observable: **silence.** And silence is
indistinguishable from "still running, going fine."

That ambiguity is the bug. An agent sitting in silence has no pressure to
re-examine anything, so it does not. It waits. It can wait for hours. From the
outside this looks like diligent monitoring; from the inside nothing whatsoever
is happening.

**A BOINK breaks the silence unconditionally.** It fires on wall-clock time and
on nothing else. It cannot be starved by a broken predicate, because it does not
have one. It is a heartbeat that comes from outside the thing it is checking —
which is the only kind of heartbeat worth having.

> Never let the liveness of your monitoring depend on the correctness of your
> monitor.

## The firing condition

A BOINK fires when **both** of these hold:

1. **The REPL is idle** — you are not mid-turn. `CronCreate` enforces this half
   for free; jobs never interrupt work in progress.
2. **At least one semantic monitor you created is still active.** This half is
   yours to enforce, by arming when the first one appears and disarming when the
   last one goes.

Idle *and* waiting-on-something is precisely the stall state. Idle with nothing
outstanding is just... idle, and deserves no prodding. Mid-turn is fine by
definition — you are demonstrably doing something.

## What counts as a semantic monitor

A **semantic monitor** is any outstanding wait that will not resolve inside the
current turn, and whose resolution depends on observing a condition rather than
on you finishing your work.

**Counts:**

- A `Monitor` task, of any kind, `persistent` or not
- `Bash(run_in_background: true)` — an `until` loop, a build, a training run
- A poll loop against a remote API
- Watching CI, a deploy, a queue, a migration, a long test suite
- Any turn that ends with "I'll check back when…" / "let me know when…" /
  "waiting for…" — **even with no tool armed at all.** An intention to wait is a
  semantic monitor. This is the case that strands agents hardest, because there
  is no task object anywhere to remind you it exists.

**Does not count:**

- A foreground command you are blocking on right now
- Work that completes inside this turn
- A background task you have already collected the result of
- A monitor you armed and then stopped
- **A dead monitor, shell, or agent that is still listed.** A corpse is not a
  monitor. Keeping this distinction honest is the entire job of
  [the sweep](#the-sweep) — count the live ones, or the BOINK never stops.

The test: *if I stop typing, is there something I am expecting to hear about
later?* If yes, that is a semantic monitor, and the BOINK stays armed.

The word **semantic** is load-bearing. It means *meaningful to the work* — a
wait that matters. Do not arm a BOINK for a 200ms sleep, and do not talk
yourself out of one because the wait "should" be short. The waits that strand
agents are always the ones that should have been short.

## Arming

The moment you create a semantic monitor, check whether a BOINK is already
armed. If not, arm one:

```
CronCreate(
  cron: "2-59/5 * * * *",
  prompt: "BOINK",
  recurring: true
)
```

Every 5 minutes, at :02, :07, :12, :17, :22, :27, :32, :37, :42, :47, :52, :57.

**Exactly one BOINK per session, ever.** It is not per-monitor. Five concurrent
monitors share one BOINK — each firing sweeps all of them. Before arming, check
`CronList`; if a BOINK is already there, you are done, arm nothing.

**Why not `*/5`?** `*/5` lands on :00 and :30, the two minute-marks every
scheduler on the planet piles onto. The offset form is the same 5-minute period
with none of the thundering herd. If you need a different period, keep the
trick: `3-59/10`, `7-59/15`, `13-59/30`.

Record the returned job ID, and say in the same turn that you armed it and at
what interval — so the incoming BOINKs are not a mystery.

### Variant: `--loud`

A bare `BOINK` is deliberately contentless. In a very long session, context may
be compacted between arming and firing, and a future turn may receive the word
`BOINK` with no idea what it means.

For long-running or compaction-prone sessions:

```
prompt: "BOINK — /boink protocol: re-observe the watched thing with a fresh command, classify, report evidence. Do not answer from memory."
```

Same semantics, carries its own instructions. If you receive a bare `BOINK` and
genuinely do not know what it means: **invoke the `boink` skill to reload this
protocol, then follow it.** Do not guess, and do not ignore it.

## The BOINK protocol

Arming the cron is trivial. Responding correctly is the whole skill.

When a BOINK arrives, run these six steps. **Every time. No exceptions, no
shortcuts, no "I just checked."**

### 1. Do not answer from memory

Your belief about the watched thing is **stale by construction** — it dates from
the last time you actually looked, at minimum one interval ago. It is exactly
this belief the BOINK exists to challenge.

If your answer could have been written *before* the BOINK arrived, you have not
done the protocol.

### 2. Sweep and re-observe

Run something. Right now. Look at the world, not at your notes.

Start with the session inventory — `TaskList` and `CronList` — because *is my
monitor still armed at all?* is the cheapest question with the highest yield.
This same enumeration is the **sweep**: one pass over session state, where what
is alive feeds your classification and what is dead gets reaped. See
[The sweep](#the-sweep) for the full inventory and the reaping rules.

Then look at the specific thing you are waiting on:

```bash
ps -p "$PID" -o pid,etime,stat,%cpu,cmd   # is the process even alive?
tail -n 30 run.log                         # what did it last say?
stat -c '%y %s' run.log                    # touched? grown?
gh run view "$RUN_ID"                      # what does the remote actually think?
curl -sS -o /dev/null -w '%{http_code}' "$URL"
ls -la --time-style=full-iso out/
```

Two of these are worth more than the rest combined:

- **mtime and size of the file you are tailing.** Unchanged across three BOINKs
  means nothing is writing to it, and your `tail -f` is following a corpse.
- **liveness of the process itself.** A monitor watching a dead process is
  theatre.

### 3. Compare against the previous BOINK

Keep a running note of what you saw last time. The signal is not the absolute
state — it is **the delta**.

| Observation | Reading |
| --- | --- |
| Log grew, mtime recent, process alive | Progressing |
| Log unchanged, process alive, ~0% CPU | Suspicious — hung, deadlocked, blocked on input |
| Log unchanged, process **gone** | Dead. The monitor missed the exit. |
| Terminal state already in the log | **Done — and your monitor missed it.** |
| Monitor task no longer in `TaskList` | Reaped. You are watching nothing. |

### 4. Classify out loud

Commit to exactly one word. Do not hedge between them.

- **PROGRESSING** — concrete evidence of motion since the last BOINK. Cite it:
  line count, byte count, step number, timestamp.
- **DONE** — the terminal condition already occurred; the monitor missed it.
  Stop waiting, do the real work.
- **STALLED** — alive but not moving. Say how long, in BOINKs.
- **DEAD** — process or job is gone. Report exit status and the last thing it
  said.
- **MONITOR-BROKEN** — the watched thing is fine but the *watcher* is not: it
  exited, timed out, was reaped, is tailing a rotated file, or has a filter that
  cannot match.

**DONE and MONITOR-BROKEN are the two that justify this skill's existence.** They
are the states an agent in silence will never discover on its own, because in
both cases the notification that was supposed to arrive is precisely the thing
that is broken. Look for them first, and hardest.

### 5. Act

| Classification | Action |
| --- | --- |
| PROGRESSING | Nothing. Say so, with the number that proves it. |
| DONE | Stop the monitor, proceed with the real task. |
| STALLED | Escalate per the ladder below. |
| DEAD | Report the failure with the log tail. Do not silently retry. |
| MONITOR-BROKEN | Re-arm a *corrected* monitor — never the identical one — or drop it and rely on the BOINK alone. |

### 6. Recount, and disarm if the set is empty

This is the step that terminates the loop, and the easiest one to forget.

After acting, ask: **are there any *live* semantic monitors left?** If the answer
is zero, `CronDelete` the BOINK now, in this same turn. If one or more remain, it
stays armed and you say nothing about it.

The word *live* is doing real work, and it is why the sweep is not optional
housekeeping. **A dead monitor still appears in the inventory.** If you count
corpses, the count never reaches zero, and the BOINK keeps firing for seven days
over work that finished this morning. The reap in step 2 is what makes the
refcount converge.

Every BOINK is therefore also a refcount check. That is why the BOINK cannot leak
indefinitely: the mechanism that fires it is the same mechanism that notices it
is no longer needed.

### Report

Short, factual, with a number in it:

> BOINK — PROGRESSING. `run.log` 4,182 → 4,610 lines, mtime 14s ago, pid 3312 alive. Step 41/120. 1 monitor active.

> BOINK — DONE. `run.log` line 4,610 reads `FINISHED exit=0`, written 11 min ago. The monitor's filter was `"elapsed_steps="` and never matched the completion line. No monitors left — disarming. Moving on to the artifact upload.

> BOINK — MONITOR-BROKEN. Task `m_4f2` is gone from TaskList; it hit its 300s timeout 22 min ago. The build is still running (pid 8871, 6% CPU). Re-arming with `persistent: true`. BOINK stays armed.

> BOINK — STALLED (3 consecutive). `build.log` unchanged at 812 lines since 14:07, pid 8871 alive at 0.0% CPU, no open sockets. This is not slow, it is stuck. Recommend killing it and re-running with `-v`.

## The sweep

A long session silts up. Background shells finish and are never collected.
Monitors time out, or get auto-stopped for volume, and nobody notices. Agents
deliver their work and linger. Task-list entries sit `in_progress` for hours
after the work landed, or stay blocked by tasks that no longer exist. Cron jobs
outlive the thing they were watching. Processes get orphaned, temp files pile up.

None of this is individually alarming, which is exactly why it accumulates. The
cost shows up later: an inventory so full of corpses you cannot see what is
actually running, and — specifically, mechanically — **a refcount that never
reaches zero, so the BOINK never disarms.**

The BOINK is the natural place to fix this because it is already doing the
enumeration. Steps 2 and 6 walk session state anyway. The sweep is not a second
pass; it is the same pass, with the dead things removed on the way through.

### The cardinal rule: harvest before reap

**Never reap anything whose output you have not already collected.**

A finished background shell is not garbage. It is *the result you were waiting
for*, sitting in a buffer. Reaping it first destroys the evidence and converts a
clean **DONE** into a permanent mystery — you will know the job ended and never
know how.

So the order is always: **read it, use it, then clear it.**

```
Read(<output file path from the task result>)   # harvest
TaskStop(task_id: "…")                          # then reap
```

`TaskOutput` is deprecated; `Read` the output file path the task returned. Never
`Read` the `.output` of a `local_agent` task — it is a symlink to the full
subagent transcript and will flood your context. Use the Agent result instead.

### Inventory

| What | Dead when | Harvest | Then |
| --- | --- | --- | --- |
| **Background shell** (`Bash run_in_background`) | Exited — completion notification arrived, or it is gone from `TaskList` | `Read` its output file | `TaskStop` if still listed |
| **Monitor** | Timed out (default 300 s!), auto-stopped for event volume, watching a dead PID, or tailing a rotated inode | `Read` its output file for anything stderr swallowed | `TaskStop`; re-arm *corrected* if still needed |
| **Agent / teammate** | Returned its result, or has been idle with nothing assigned | Use the Agent result you already got | `TaskStop(task_id: "<name>")` or `"<name>@<team>"` |
| **Task-list entry** | Work is done, or it was superseded by a pivot | — | `TaskUpdate` → `completed` (done) or `deleted` (never real) |
| **Blocked task** | Its `blockedBy` names tasks that are completed or deleted | — | Clear the dependency, or delete if moot |
| **Cron job** | Duplicate BOINK, or watching finished work | `CronList` to see them all | `CronDelete` |
| **OS process** | You spawned it, its parent is gone, it is doing nothing | `ps`, last log lines | `kill` — see the red tier first |
| **Temp file** | In *your* scratchpad, from work that finished | Anything you still need | `rm` |

A few of these deserve emphasis:

- **Monitors default to a 300 000 ms timeout — five minutes.** Roughly one BOINK
  interval. Unless you passed `persistent: true`, assume any monitor older than a
  couple of BOINKs is already dead, and check rather than trust it.
- **Monitors that emit too much are stopped automatically.** This is a silent
  death: you get no notification that watching has ceased. A monitor that was
  chatty and then went quiet is a prime suspect, not a reassurance.
- **`completed` and `deleted` are not interchangeable** on task entries.
  `completed` preserves the record of work that happened; `deleted` erases it
  permanently. Use `deleted` only for entries created in error.

### Three tiers

Reap aggressively where it is provably safe, and nowhere else.

**Green — reap silently, mention only in the tally.**
Things that are yours, provably finished, and already harvested: collected
background shells, monitors confirmed gone from `TaskList`, task entries whose
work demonstrably landed, duplicate or orphaned BOINKs, your own scratchpad
files from finished work.

**Amber — reap, and say so in one clause.**
Things that are yours and almost certainly finished, but where the judgement is
yours rather than the system's: a monitor watching a PID that no longer exists,
an agent idle since it delivered, tasks superseded by a change of direction, a
`persistent` monitor whose subject completed. Name what you reaped and why.

**Red — never auto-reap. Report and ask.**
- Anything you did not create in this session.
- Anything still running that you cannot prove is finished.
- Any process outside your own spawns — never `pkill` by name or pattern; a bare
  `pkill node` will take out the user's editor, dev server, and half their
  desktop.
- User files, project files, anything outside the scratchpad. `rm` targets are
  paths you created, never globs you inferred.
- Anything whose output you have not read.
- Another agent's tasks, monitors, or crons.

When in doubt it is Red. An uncollected corpse costs one line of inventory
noise; a wrong reap can destroy the run you were monitoring, or the user's
unrelated work. **The asymmetry is total, so the bias is total: leave it.**

### Reporting the sweep

The sweep is secondary to the status check and must never crowd it out. A BOINK
that reports beautiful housekeeping and forgets to say whether the build is alive
has failed.

If nothing was reaped, **say nothing about it.** Silence is the correct report
for an empty sweep.

If something was, append one clause to the BOINK line:

> BOINK — PROGRESSING. `run.log` 4,182 → 4,610 lines, mtime 14s ago, pid 3312 alive. Step 41/120. Swept: 2 finished shells (harvested), 1 timed-out monitor, 3 completed task entries. 1 monitor live.

> BOINK — DONE. `deploy.log` line 88 reads `rollout complete`, 6 min ago; the monitor's filter wanted `"Ready in"` and never matched. Swept: stopped the stale monitor, closed tasks 4–7, deleted the duplicate BOINK. Zero monitors left — disarming.

Anything in the Red tier gets stated plainly and left alone:

> Also: 3 orphaned `node` processes from an earlier run (pids 4471, 4488, 4502), parent gone, ~0% CPU. Not mine to reap on my own — want me to kill them?

## The escalation ladder

Repeated identical BOINK responses are themselves a failure. If you have said
"still waiting" three times, the correct fourth response is not "still waiting."

- **1 no-change BOINK** — Note it. Fine. Things take time.
- **2 no-change BOINKs** — Widen the observation. Check something you have not
  checked yet: CPU, open file descriptors, network state, disk space, the parent
  process, the remote's own view.
- **3 no-change BOINKs** — Say the word **STALLED**. Stop describing this as
  normal. Form a hypothesis about *why*, and state it.
- **4+ no-change BOINKs** — Stop waiting. Surface it to the user with a concrete
  recommendation: kill and retry, retry with more logging, or abandon. Do not
  spend a fifth interval hoping.

The ladder exists because "wait a bit longer" is locally reasonable at every
single step and globally catastrophic. Time-box it explicitly, or you will
rediscover this at hour seven.

## Disarming

The BOINK stops for exactly one reason: **there are no semantic monitors left in
the session.** Not because the wait "seems fine," not because the BOINKs are
noisy, not because the user has gone quiet.

```
CronList()              # find the job ID
CronDelete(id: "<id>")  # kill it
```

Check the condition whenever the set of monitors shrinks — a task completes, a
monitor is stopped, the user cancels, you pivot away — and at the end of every
BOINK turn (step 6). If it reaches zero, disarm immediately.

A forgotten BOINK injects a prompt every five minutes for up to seven days. If
you are unsure whether one is armed, `CronList` is free. Run it.

## Anti-patterns

Each of these is a way of receiving a BOINK and extracting no value from it.

**Answering from memory.**
> ❌ "BOINK — still running, I'll let you know when it's done."

No command was run. This is the null response, and it is worse than never having
armed the BOINK: it manufactures false confidence, putting a timestamped claim of
health in the transcript backed by nothing. If you did not look, say you did not
look.

**Treating silence as success.** No output from a monitor means *no output from a
monitor.* A crashed process is extremely quiet. Ask the arming question in
reverse: *if this had died 40 minutes ago, would anything I have observed look
different?* If not, you have learned nothing.

**Re-arming the identical broken monitor.** If a filter failed to match, the
filter is wrong. Re-arming it verbatim bets that reality will change to suit your
predicate. Widen the alternation, or drop it and rely on the BOINK.

**Hedging instead of classifying.** "It might still be starting up, or it could
have failed, hard to say." Pick a word. If you genuinely cannot distinguish
PROGRESSING from DEAD, that is itself a finding: you lack observability, and
getting some is now the task.

**Snoozing.** Receiving a BOINK and deciding to check on the next one. There is
no next one that will be easier.

**Waiting for permission to arm.** BOINK is passive and automatic. Arming it is
not a proposal to put to the user.

**Arming a BOINK instead of a monitor.** BOINK is a 5-minute backstop, not a
notification system. If you need to know within seconds, you still need a
`Monitor` or a background `until` loop. Arm both — the monitor is the fast path,
the BOINK is the unkillable slow one.

**Leaving it armed with nothing to watch.** Step 6 exists. Run it.

**Reaping before harvesting.** Stopping a finished background shell before
reading its output destroys the result you spent an hour waiting for. Worse, a
finished shell is usually *the* **DONE** signal — reap it first and you have
deleted the answer while keeping the question. Read, then clear. Always.

**Counting corpses.** A dead monitor still shows up in the inventory. Refcount
the *live* ones, or the BOINK outlives the work by seven days.

**Reaping by pattern.** `pkill -f node`, `rm -rf` on an inferred glob, stopping
every task in the list because most of them looked done. Reap named things you
created; everything else is Red tier.

**Letting the sweep eat the report.** A tidy inventory is not a status. If the
BOINK line does not say what the watched thing is doing, the sweep was a
distraction.

## Limits — know these before relying on it

- **Session-only.** Cron jobs live in memory in this session and do not survive a
  restart. The `durable` parameter has no effect. Session ends, BOINK ends.
- **Fires only while idle.** A BOINK never interrupts a turn in progress; it
  lands when you are next idle. That is the intent — idle-and-waiting *is* the
  stall condition — but it means BOINKs do not arrive during long tool calls, and
  several may coalesce into one.
- **Jitter.** Recurring jobs fire up to 10% of their period late, so a 5-minute
  BOINK may land ~30s after the mark. Not a precise clock.
- **7-day expiry.** Recurring cron jobs auto-delete after 7 days, firing one
  final time. Anything running longer needs re-arming, and nothing will remind
  you.
- **Not free.** Each BOINK is a real turn with real tokens. For very long waits,
  `7-59/15` or `13-59/30` buys the same protection far cheaper — the value is in
  *unconditional recurrence*, not in frequency.

## Manual overrides

The ability is automatic; these exist for when the user wants to steer it.

| Command | Meaning |
| --- | --- |
| `/boink` | Arm now, even if no monitor is currently active. |
| `/boink 15m` | Re-arm at a different interval (`7-59/15`). |
| `/boink --loud` | Re-arm with the self-describing prompt. |
| `/boink status` | `CronList` plus the current set of live semantic monitors. |
| `/boink sweep` | Run the sweep once, right now, without waiting for a BOINK. |
| `/boink off` | `CronDelete` every armed BOINK, and stand down for this session. |

`/boink off` is the only thing that suppresses the passive behaviour, and only
until the session ends.
