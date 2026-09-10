---
name: code-review-guard
description: Self-review a diff or codebase against the recurring anti-patterns found in real reviews (silent excepts, God objects, duplicated logic, hidden state, unsafe SQL, complex booleans, magic numbers). Use before committing, after a refactor, or when asked to review code.
---

# Code Review Guard

Run this after writing code and before committing. It pairs with the global
`AGENTS.md` §7 patterns.

## 1. Run the mechanical scan

```bash
bash "$HOME/.pi/agent/skills/code-review-guard/scripts/audit.sh" .
```

It flags: silent `except`, `SELECT *`, string-built SQL, hardcoded secrets,
obvious magic numbers, scratch/debug files, conflict markers, oversized files,
and em-dashes in copy. Treat every hit as a question to answer, not a verdict.

## 2. Read the diff, not just the scan

```bash
git diff --stat
git diff            # or: git diff --staged
```

For each hunk, check:

- **Errors**: could this failure be silent? Is the exception type narrow enough?
  Is there a log line at the right level?
- **Ownership**: does this add a concern to an already-large file/class? If a
  file crossed ~800 lines, plan the extraction now.
- **Duplication**: is the same rule now expressed in two places (especially a
  "fallback" copy)? Consolidate.
- **State**: new boolean flags? More than two related flags means use an enum.
  Scratch attributes attached to objects are not allowed.
- **Boundaries**: does UI import UI, or does core import UI? Does app code
  import vendor correctly and not the reverse?
- **Data**: `SELECT *`, string-built SQL, unparameterized input, JSON blobs
  mutated in place where a table belongs.
- **Numbers**: new literal with meaning? Name it and say why it has that value.
- **Copy**: user-facing strings - no em-dashes, no cryptic symbols, correct
  pluralization, plain language, shared help on the header not per row.

## 3. Adversarial pass

Ask "how would this break in production?" Specifically:

- empty / missing / hostile input;
- expired or concurrent state;
- network offline, DNS hang, rate limit;
- corrupt or partial file;
- a future rename/upstream change in a dependency.

For each: is the failure visible, and is there a test?

## 4. Tests for new structure

- New extracted class -> new test file (not only the smoke test).
- New rule -> unit test with a negative case.
- Security claim in a docstring -> a test that proves it, or soften the claim.

## 5. Report

State what you checked and what you changed. List anything you deliberately
left and why. Do not claim "clean" without naming the scan you ran.
