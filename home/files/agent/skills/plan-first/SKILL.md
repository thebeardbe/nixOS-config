---
name: plan-first
description: Propose a numbered plan and get explicit approval before writing or changing any files. Use for any non-trivial coding task, before scaffolding, refactors, multi-file changes, or when the user has not yet approved an approach.
---

# Plan First

Do not start building on your own initiative. Understand, propose, wait for
approval, then implement. This exists because agents here have a habit of
jumping straight into edits.

## 1. Investigate read-only

Use `read`, `grep`, `find`, `ls`, and web/docs lookups. **Do not use** `edit`,
`write`, or any command that creates or changes files. Ask clarifying questions
with `ask_user` if the goal is ambiguous.

## 2. Present the plan

Keep it short and concrete. Use this exact shape:

```
Goal:         <one line; what "done" means>
Steps:        1. <action>            [<file(s)>]
              2. <action>            [<file(s)>]
              3. ...
Approach:     <the key decisions and why; alternatives you rejected>
Verification: <automated gates>  +  <what the user should test manually>
Open:         <unknowns, or decisions you need from the user>
```

Rules for the plan:

- One step = one reviewable change. Include the files each step touches.
- State assumptions explicitly; do not hide them inside steps.
- If there is more than one reasonable approach, present the options with
  tradeoffs and a recommendation (see `project-kickoff` for new projects).
- Include how you will verify (tests, lint, build, smoke) and the manual test
  the user will run. Both are required (see global `AGENTS.md` §4).
- Estimate scope if it is large, and propose a checkpoint after the first step.

## 3. Ask to proceed

Ask the user to choose: **Proceed**, **Adjust**, or **Cancel**. Use `ask_user`
so the answer is recorded clearly. Do not begin on silence.

- **Adjust**: revise the plan and ask again.
- **Cancel**: stop and confirm what you will leave untouched.

## 4. Implement step by step

Only after approval:

- Do one step at a time; report what changed and the evidence.
- Run tests after meaningful steps, not only at the end.
- Commit per logical step (see global `AGENTS.md` §9).
- If reality diverges from the plan (a file is bigger than expected, an API is
  different), stop and re-propose; do not silently expand scope.
- If a step reveals a god file or a blocking problem, follow the relevant skill
  (`god-file-guard`) and ask before continuing.

## When a full plan is not needed

Trivial, unambiguous, low-risk requests (fix a typo, rename a symbol the user
named, answer a question) can be done directly. When in doubt, propose. Never
treat "just do it" as a standing exemption for later, unrelated tasks.

## Note on the plan-gate extension

The `plan-gate` extension interrupts the first file-changing action of a session
and asks the user to confirm a plan was approved. That is a safety net, not a
substitute for this workflow. If it fires, present the plan rather than pushing
through.
