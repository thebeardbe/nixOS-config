---
name: verify-before-done
description: Define and enforce done for any coding task by running the project's automated gates (tests, lint, build, smoke) locally and handing the user a concrete manual test plan. Use before claiming a task complete, before committing, and before pushing.
---

# Verify Before Done

Never say a task is finished until **automated gates pass** and **a manual test
plan is handed over**. CI alone is not done; manual testing is always required.

## 1. Discover the project's gates

Look for the project's own definition of "checks", in this order:

- `AGENTS.md`, `CODING_GUIDELINES.md`, `CONTRIBUTING.md`, `REPO-MAP.md`
- `Makefile`, `justfile`, `Taskfile`, `package.json` scripts
- `.github/workflows/*.yml` (mirror each relevant step)
- `run-tests.sh`, `ci/`, `scripts/`, `noxfile.py`, `tox.ini`
- language defaults: `pytest`, `npm test`, `cargo test`, `go test ./...`

Write down the exact commands you will run. If there is no automated check at
all, say so and propose the smallest useful one (a test or a smoke script).

## 2. Run the gates locally, in the project's environment

Use the project dev shell / package manager, not an ad-hoc interpreter.

```bash
# examples - use what the project actually defines
<dev-shell> --run '<test command>'
<lint/typecheck/build command>
<smoke command>       # e.g. QT_QPA_PLATFORM=offscreen ... gui_smoke.py
```

Rules:

- Run the **full** suite, not only the tests near your change.
- If a gate cannot run here (no service, no display, missing sample data),
  state which one and why. Do not silently skip it.
- Exit codes matter. Capture them. A green summary line is not enough; paste
  the real tail of the output.

## 3. Produce the manual test plan

Hand the user something they can follow without guessing. Keep it short and
numbered. Always include:

1. **Setup / launch command** - exactly how to run the thing under test.
2. **Happy path steps** - what to click/run and the expected result.
3. **Edge / negative case** - at least one (empty input, wrong password,
   missing file, offline, large value).
4. **Regression check** - one thing your change could plausibly have broken.
5. **Where the logs are** if something fails.

Template:

```
Manual test plan
----------------
1. Setup:   <command>
2. Check A: <action>          -> expect <result>
3. Check B: <edge case>       -> expect <result>
4. Check C: <regression>      -> expect <result>
5. On failure: <log path / command>
```

## 4. Evidence block

Report in this shape:

```
Automated: <command> -> PASS (N tests) | FAIL (details)
           <command> -> PASS
Manual:    handed to user (see plan above)
Not run:   <gate> (reason)
```

## 5. Stop conditions

- A failing gate is a blocker. Fix it or report it; do not commit around it.
- Do not push until automated gates are green and the manual plan is delivered.
- If the user says "this is fine to continue" without testing, that is their
  call, but record that manual verification is still pending.

See project `CODING_GUIDELINES.md` §8 for the audit checklist pattern this
generalises.
