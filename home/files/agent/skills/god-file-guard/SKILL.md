---
name: god-file-guard
description: Detect and split oversized god files, modules, classes or components that own too many concerns. Use when a source file passes the size budget, when the file-size guard blocks an edit, or when asked to refactor a large file.
---

# God File Guard

A god file owns several unrelated concerns. It is the most common structural
problem across this machine's projects, and it makes every future change more
expensive. The goal is to **prevent growth**, not just notice it.

## Budgets

Per source file, excluding vendored/generated/minified/test-fixture code:

| Lines | State | Action |
|---|---|---|
| ≤ 400 | healthy | none |
| 401–600 | getting large | extract before adding a concern |
| 601–1000 | warning | plan a split now |
| > 1000 | god file | split; may only shrink from here |

The `file-size-guard` extension enforces the hard limit on `edit`/`write` and
warns past the soft limit. Thresholds: `PI_FILE_SOFT_LINES` (600),
`PI_FILE_HARD_LINES` (1000). Do not raise them to dodge a split.

### When the guard blocks (the human decides)

In an interactive session the guard does not just refuse; it asks the human to
choose:

- **Allow this edit once** - proceed with this one change; the block returns on
  the next turn.
- **Allow this file for the rest of the session** - proceed, but the file still
  needs splitting; the guard will keep reminding you.
- **Stop and split this file first in a new session** (recommended) - the agent
  must stop the feature and write a short handoff: the pending feature and its
  state, a numbered split plan, and where it is recorded. The user starts a new
  session for the split, then returns to the feature.
- **Cancel this edit** - do not change the file; ask how to proceed.

Rules for the agent:

- Never assume an approval is permanent or extends to other files.
- If the user chooses "split first", do not start the split in the current
  session. Write the handoff and stop.
- Never route around the guard with shell redirection (`>`, `>>`, `tee`); this
  raises a warning and is a guideline violation.

## 1. Find offenders

```bash
# pi command (whole repo, respects gitignore):
/godfiles

# or portable scan:
bash "$HOME/.pi/agent/skills/god-file-guard/scripts/godfiles.sh" .
```

## 2. Decide whether it is really a god file

Size is a signal, not a verdict. It is a god file if it has **more than one
responsibility**. Ask:

- Do two changes in unrelated areas both edit this file? (git history helps:
  `git log --oneline -- <file> | wc -l`)
- Does the file mix layers (transport + business rules + storage, or view +
  state + side effects)?
- Would a new contributor need to read most of the file to understand one part?
- Does its name need "and" or "manager"/"utils"/"helpers"/"controller" to
  describe it?

If yes to any, split it. If it is genuinely one cohesive unit (a large data
table, a generated catalog, a single parser for one format), exclude it via a
path like `generated/` or a project override rather than pretending it is fine.

## 3. Split procedure (stack-agnostic)

Do **one extraction per commit**, tests green between steps.

1. **Map responsibilities.** List the distinct jobs the file does. Pick the one
   with the fewest inbound dependencies first.
2. **Extract pure logic first.** Move data/parsing/math to a new module with no
   framework imports. This is the easiest to test and the safest to move.
3. **Keep the public surface stable.** The original file should re-export or
   delegate, so callers and smoke tests keep working. Rename callers only after.
4. **Extract one view/coordination piece next**, passing it the data it needs
   rather than letting it reach back into the coordinator.
5. **Delete dead code** as you go; do not copy it into the new module.
6. **Test the new unit directly** (new test file), plus the existing suite and
   smoke test.
7. **Repeat** until the file is under budget, then update `AGENTS.md` /
   `ARCHITECTURE.md` / `REPO-MAP.md` in the same commit.

If an extraction gets stuck, revert to the last green commit rather than
leaving a half-split file.

## 4. Where to split, by stack

- **Python**: module-level functions to `core/<domain>.py`; a `QWidget`/class
  into one widget per file; dataclasses to a shared types module.
- **Node / Express**: routes (thin) → controllers → services → a `store`/`db`
  layer. Extract EJS includes/partials; put helpers in `lib/`.
- **React / Vue / Svelte**: one component per file; pull state into hooks/
  composables; pull side effects into a service; presentational vs container.
- **Go**: one package per concern; move methods to the type's file; keep
  `main`/wiring thin.
- **Rust**: one module per concern; `impl` blocks split by topic across files.
- **Front-end JS utilities**: split by domain (`format.js`, `dates.js`,
  `http.js`), never a single `utils.js`.

## 5. Do not

- Do not add a new responsibility to a file over the soft limit.
- Do not bypass the guard by writing through the shell (`cat >`, `tee`, `sed -i`
  is fine for mechanical renames but not for adding features).
- Do not treat a one-time approval as blanket permission; the guard will ask
  again next turn.
- Do not split by "cut the file in half"; split by responsibility.
- Do not leave re-export shims forever; migrate callers and remove them.
