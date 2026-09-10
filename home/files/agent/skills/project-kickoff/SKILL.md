---
name: project-kickoff
description: Start a new project by asking the questions that determine the stack, then proposing two or three options with tradeoffs and a recommendation before any scaffolding. Use when creating a new project, starting a greenfield service or app, or choosing a framework, language or database.
---

# Project Kickoff

Never pick a stack silently and never scaffold first. Agree the stack with the
user, then follow `plan-first` for the build plan.

## 1. Ask the discovery questions

Ask these (use `ask_user` for the ones with clear choices, plain questions for
open ones). Do not propose anything until you have answers.

**Product**
- What does it do, in one sentence, and who uses it?
- What is the must-have first version (the smallest thing that is useful)?

**Runtime and scale**
- Where does it run (local only, VPS, cloud, serverless, desktop, mobile)?
- Expected load and data volume now, and in a year?
- Any offline / latency / real-time requirements?

**Constraints**
- Languages/frameworks the user already knows or wants, and any they refuse.
- Existing code, services, or data it must integrate with.
- Hosting, licence, budget, and any compliance needs.

**Data**
- Relational or document data? How much? Retention? Migrations?
- Who else reads the data (analytics, exports)?

**Delivery and ops**
- How is it deployed (containers, bare metal, PaaS)?
- CI expectations, environments (dev/staging/prod), secret management.
- Monitoring/logging needs.

**Quality**
- Testing expectations, packaging/distribution, target platforms.

## 2. Propose options

Present **2 to 3** coherent options (not a laundry list). For each, cover the
whole slice, not just the language.

```
Option A - <name>
  Stack:   <language/runtime> + <framework> + <datastore> + <deploy>
  Pros:    ...
  Cons:    ...
  Fit:     <when this is the right call>

Option B - ...
Option C - ...
```

Then give a clear recommendation:

```
Recommendation: <option>
Why: <2-4 concrete reasons tied to the answers above>
Not chosen: <why the others lose here>
```

Also propose the supporting decisions: test framework, lint/format, CI, config
and secret handling, container/package layout, and project structure.

## 3. Agree, then plan the build

Wait for the user to pick. Record the decision (a short `ARCHITECTURE.md` or a
line in the README is fine). Then switch to the `plan-first` skill: present the
numbered build plan for the first milestone and ask to proceed. Only scaffold
after that.

## 4. Set the project up for the guidelines

As part of the first milestone, create:

- `AGENTS.md` with the stack, commands to run/test/build, and any project
  overrides to the global guidelines.
- A test setup and at least one real test.
- CI that runs the automated gates (see `verify-before-done`).
- `.gitignore` that excludes dependencies, build output, and `.env`.
- A `NOTES.md` for deferred work.
- `file-size-guard` thresholds only if this project legitimately differs from
  the defaults (prefer the defaults).

Do not raise the god-file thresholds to avoid structuring the project.
