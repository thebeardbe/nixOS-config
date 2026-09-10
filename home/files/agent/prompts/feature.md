---
description: Full pipeline - builder implements, test-writer tests, reviewer audits
argument-hint: "<feature or change>"
---
Run the full change pipeline for the following, using the `subagent` tool.
Do not do the work yourself.

Target: $@

1. **builder** - implement it per the approved plan. It must not read, create or
   edit tests.
2. **test-writer** - after the builder returns, write and run tests for the
   implementation. Derive them from the source and the task, not from the
   builder's summary.
3. **run the suite** - run the project's full test command yourself and capture
   the result.
4. **reviewer** - review the change and red-team it read-only.

Ordering rule: the builder runs before the test-writer, so tests do not exist
while the builder works. Never pass test source, test names, or test output
back into a builder task; if a test fails, report it to the user and only send
the builder a description of the required behaviour.

Report each stage's Summary and Evidence, then the final verdict and a manual
test plan.
