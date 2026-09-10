---
name: session-hygiene
description: Keep agent sessions small and focused so context never overflows, costs stay sane, and summaries stay accurate. Use when a session spans multiple features, many hours or days, or is getting long, and at the start of a resumed session.
---

# Session Hygiene

Long sessions cause three concrete failures seen in practice: hitting the
model's hard context limit (a 400 error that ends the turn), massive cache-read
cost, and stale plans. Manage the session deliberately.

## When to start a new session

Start fresh (do not keep appending) when:

- the task changes to a different feature or project;
- the session has been alive for more than a few hours, or across days;
- you have done 30+ user turns on one thread;
- the context indicator is above ~50% and the work is at a natural boundary.

Before starting fresh, write a short handoff into the repo if it will help
(`NOTES.md`, a task file, or a commit message): goal, state, next steps.

## Context discipline

- Do not paste whole large files or logs. Search first
  (`rg`, `grep -n`), then read only the relevant ranges.
- Prefer `read` with `offset`/`limit` for big files.
- Avoid re-reading the same file repeatedly; note what you learned.
- Keep tool output small: pipe through `tail`/`head`, avoid `-v` unless needed.
- Compact proactively at boundaries with `/compact`, before the limit is hit.
  A request over the maximum context is a hard failure, not a soft warning.
- Do not rely on an old summary for exact values (versions, paths, hashes);
  re-read the source of truth.

## Commit / checkpoint discipline

- Commit at logical steps, not after every micro-edit; push at milestones.
- After a refactor step, commit with a green test suite before continuing.
- If a step half-fails, do not pile more edits on top; make the tree green or
  revert the step.

## Resuming a session

1. Re-read `AGENTS.md` / project guidelines and any `NOTES.md`.
2. Check `git status` and `git log --oneline -5` for the real current state.
3. Restate the plan in one or two lines before editing.
4. If the summary and the files disagree, trust the files.

## Warning signs to call out to the user

- "This session has grown large; I recommend finishing this task and starting
  a new session for the next one."
- "Repeated context limit pressure; compacting now."
- "This file keeps needing edits; it should be split."
