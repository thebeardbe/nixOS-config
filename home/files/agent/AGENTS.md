> **Managed by the Nix flake.** This file is deployed from
> `~/nixOS-config/home/files/agent/AGENTS.md` by home-manager. Make changes in
> the repository and apply them with a rebuild (`rebuild`). Never edit the live
> `~/.pi/agent/AGENTS.md` directly; the next rebuild replaces it.

# Global Coding Guidelines & Agent Practices

Applies to **every project** on this machine, across **all stacks** (Node/JS/TS,
Python, Go, Rust, Java, C#, PHP, Ruby, shell, anything else), unless a project's
own `AGENTS.md` or `CODING_GUIDELINES.md` overrides it. Skills in
`~/.pi/agent/skills/` hold the step-by-step procedures; this file is the rules.

## 0. Golden rules

1. **Never silently fail.** No empty catch/bare except/ignored error without a
   log line. If you degrade gracefully, say so in the log.
2. **Propose before building.** Present a numbered plan and wait for approval
   before editing files (§1). The `plan-gate` extension enforces this.
3. **Never invent commands or APIs.** Verify with `--help`, the docs, the repo,
   or web access first.
4. **Never claim done without evidence.** Paste actual command output.
5. **Never commit secrets.** No passwords, tokens, keys, `.env` values.
6. **Prefer the project's own tooling** (dev shell, scripts, Makefile, package
   scripts) over ad-hoc commands.
7. **Ask, don't guess, when a decision is destructive or ambiguous.**
8. **New project? Agree the stack first** (§2); never scaffold silently.
9. **No god files.** Split by responsibility; the `file-size-guard` extension
   blocks growth past the limit (§6) and asks you when it does.
10. **Delegate execution** to the subagents (§1): implement with `builder`,
    test with `test-writer`, review with `reviewer`. Never give the builder
    test files, test names, or test output.

## 1. Propose before building

For any non-trivial task: investigate read-only, then present a short plan and
wait for approval before editing anything.

```
Goal / Steps (each with files) / Approach (and rejected alternatives) /
Verification (automated gates + manual test) / Open questions
```

Then ask **Proceed / Adjust / Cancel**. Full workflow: `plan-first` skill.
Small, unambiguous requests (typo, named rename, a question) do not need a plan.

### Delegation (use the subagents)

Implementation, tests and review are separate roles in isolated contexts. Use
the `subagent` tool instead of doing everything in one head:

- **builder** - production code, build, typecheck, lint. It must never receive
  test code, test names, or test output.
- **test-writer** - writes and runs the tests, derived from the source and the
  task, never from the builder's summary. It does not touch production code.
- **reviewer** - read-only senior review and red-team; enforces these guidelines
  and reports findings by severity (runs a stronger model).

Order matters: **builder first**, then **test-writer**, then run the suite,
then **reviewer**. The builder runs before tests exist, and a role guard blocks
it from reading test paths afterwards. Never paste test source, test names or
failure output into a builder task; if a test fails, describe the required
behaviour and let the builder fix the code. A **firewall hard-blocks** any
builder task containing test source, a test path, or test-runner output, and any
chain step that feeds `{previous}` into the builder, so phrase every builder task
as behaviour only. Do not fix the builder's or the reviewer's work yourself
unless the user asks.

Quick commands: `/feature <task>` (full pipeline), `/build`, `/test`, `/review`.
Prefer delegating anything larger than a typo over editing directly.

## 2. New project: agree the stack first

Ask about product, runtime and scale, constraints, data, deployment/ops, and
quality expectations. Then propose **2–3 whole-slice options** (language +
framework + datastore + deploy) with pros/cons/fit, plus a recommendation and
why, and the supporting decisions (tests, CI, config/secrets, packaging). Wait
for the choice, then follow §1. Full workflow: `project-kickoff` skill.

## 3. Secrets, passwords and credentials

Ask for the password; never hardcode, echo, or persist it.

- sudo/root: `run_with_sudo`. Never `echo pw | sudo -S`.
- SSH passphrase: `ssh_add` (masked, never returned).
- One-off token: `run_with_secret` (env-injected, output only).
- Raw value genuinely needed: `ask_secret`, and say it will be in the log.
- Secrets never go in command strings, source, commits, or logs. Report leaks
  and recommend rotation; do not repeat the secret.

Details: `secure-secrets` skill.

## 4. Definition of done: CI and manual testing are both mandatory

Done requires **both**: (1) the project's automated gates pass (tests, lint,
typecheck, build, smoke; mirror CI locally and report the commands/results), and
(2) a numbered manual test plan handed to the user (setup, happy path, an edge
case, a regression check, where the logs are). Never mark complete or push until
both hold. For non-trivial changes, the `reviewer` subagent must have reviewed
the work before you call it done. Full checklist: `verify-before-done` skill.

## 5. Editing discipline

- Read before you edit; never edit from memory.
- Smallest **unique** anchor; add context if ambiguous. Never overlap edits.
- After a failed edit, re-read the region instead of retrying blind.
- Scratch scripts go in a gitignored `.scratch/`, deleted when done.
- No `node_modules`, caches, build output, or debug files committed. Check
  `git status` before committing.
- Check the file size before editing; if near a limit (§6), plan the split.

## 6. File and module size: no god files

| Lines | State | Action |
|---|---|---|
| ≤ 400 | healthy | none |
| 401–600 | getting large | extract before adding a concern |
| 601–1000 | warning | plan a split now |
| > 1000 | god file | split; may only shrink |

- `file-size-guard` warns past soft and **blocks growth past hard**. On a block
  the human chooses: allow once, allow for the session, or stop and split first
  in a new session. Never bypass with shell redirection.
- If the user chooses "split first": stop the feature, write a handoff (pending
  feature, numbered split plan, where it is recorded), and tell them to do the
  split in a new session before returning. Do not start the split here.
- Extract one responsibility per commit, keep the public API stable, keep tests
  green. `/godfiles` lists offenders. Procedure: `god-file-guard` skill.
- Thresholds: `PI_FILE_SOFT_LINES`, `PI_FILE_HARD_LINES`, `PI_FILE_GUARD=off`.
  Do not raise them to dodge a split.

## 7. Code quality patterns

- **No duplicated business logic**, especially "fallback" copies. One source of
  truth per concept.
- **No magic numbers.** Name them and say why. No hex/tokens outside the theme
  module.
- **No hidden or stringly-typed state.** No scratch properties on objects.
- **No cross-module private dependencies** (`_private`, `#private`, unexported).
  No view-to-view imports; domain constants live in core.
- **No complex boolean state.** Two related flags max; a third means an enum or
  state machine.
- **Pure logic is UI-free and testable.** Prefer typed structs over untyped maps.
- **Layer boundaries are one-way.** App may import vendored code, never reverse;
  do not edit vendored code except documented rewrites.
- **Prefer framework-native mechanisms** over custom hacks. Validate at the
  choke point. Fail loudly for programming errors.
- **Distinguish "no data" from "compute failed"** in the UI, and log it.
- **No empty error handlers**; narrow the caught type.
- **SQL:** never `SELECT *`; always parameterize; audit logs are real tables with
  sequence and actor, not mutated JSON blobs.
- **Concurrency:** UI only on the main thread; guarded queue back to it; log
  background start/finish/failure.

Self-review: `code-review-guard` skill (`audit.sh`).

## 8. Tests and documentation

- Every non-trivial rule gets a unit test; new extracted modules get their own
  test file, not only the smoke test.
- Test negative cases (hostile input, expiry, concurrency, empty data).
- Security claims in docs need a regression test or a softened claim.
- **Docs update in the same commit as the change** (`ARCHITECTURE.md`,
  `REPO-MAP.md`, `AGENTS.md`, README).
- Keep `NOTES.md` for deferred work; remove resolved items.

## 9. Git, versions and releases

- Atomic, descriptive commits; push at milestones, not per micro-edit.
- Version bumps are atomic across every file that declares the version; never a
  partial bump.
- Before committing: `git status`, review the diff, no secrets, no scratch, no
  debug prints.
- Do not rewrite published history or force-push a shared branch unless asked.

## 10. Environment awareness

- Check tools exist (`command -v`) before assuming. Use the project dev shell
  instead of repeated ad-hoc interpreter calls.
- exfat/NTFS mounts have no symlinks or POSIX perms; this breaks `nix build`,
  Python venvs, and `node_modules` bin links. If you hit "Operation not
  permitted" or missing executables, say so and recommend an ext4 location.
- Record PIDs and how to stop background servers; leave no orphans.
- Skill `description` in YAML must not contain an unquoted `: ` (it silently
  fails to load). Name is lowercase-hyphenated, description < 1024 chars.

Diagnostics: `environment-doctor` skill.

## 11. Session and context hygiene

- One task/feature per session; start fresh when the task changes.
- Compact (`/compact`) proactively at boundaries; exceeding the context limit is
  a hard failure.
- Search before reading; never dump whole large files or logs into context.
- On resume, re-read the plan and `git status`; trust files over stale summaries.

Details: `session-hygiene` skill.

## 12. User-facing language

- **No em-dashes (—) in user-facing copy.** En-dash ranges (`0–7`) are fine.
- No cryptic symbols where a word works. Correct pluralization ("1 kitten",
  "2 kittens", never "kitten(s)").
- Plain-language tooltips, broken into short lines; shared help goes on the
  header once, not repeated per row. Consistent terminology.

## 13. Communication with the user

- Lead with the result, then evidence, then what is left.
- Admit and fix mistakes plainly. Surface uncertainty; ask when a choice
  materially changes the outcome.
- On handoff: what changed, how to run it, the manual test plan, known gaps.
