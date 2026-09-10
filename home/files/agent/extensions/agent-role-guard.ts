import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { bashTouchesTests, isTestPath } from "./lib/test-content.ts";

/**
 * agent-role-guard: enforce role boundaries for subagents.
 *
 * The subagent extension sets PI_AGENT_ROLE=<agent name> on each child process.
 *
 *   builder      must not see or touch test code: read/grep/find/ls/edit/write
 *                and shell access to test paths are blocked. Searches must
 *                name an explicit non-test location too, because an unscoped
 *                search scans the whole tree and can surface test code.
 *                Running the test suite is allowed.
 *   test-writer  may only create or edit test files; a write to any other path
 *                is blocked so production code stays with the builder.
 *
 * Config (environment):
 *   PI_ROLE_GUARD=off   disable
 *
 * Inactive for every other role and for the main (non-subagent) session.
 * The parent-side counterpart is `subagent-firewall.ts`.
 */

const ROLE = (process.env.PI_AGENT_ROLE ?? "").trim().toLowerCase();
const OFF = ["off", "0", "false"].includes((process.env.PI_ROLE_GUARD ?? "").trim().toLowerCase());

const BUILDER = "builder";
const TEST_WRITER = "test-writer";

function blockBuilder(reason: string) {
  return {
    block: true,
    reason:
      `Role guard (builder): ${reason}\n` +
      `Test code is owned by the test-writer agent and the builder must not read or change it. ` +
      `Ask the human if you need test information.`,
  };
}

function blockTestWriter(reason: string) {
  return {
    block: true,
    reason:
      `Role guard (test-writer): ${reason}\n` +
      `The test-writer may only create or edit test files. ` +
      `Report the production change you need and leave the code to the builder.`,
  };
}

function hasExplicitPath(value: unknown): boolean {
  return typeof value === "string" && value.trim() !== "";
}

export default function (pi: ExtensionAPI) {
  if (OFF || (ROLE !== BUILDER && ROLE !== TEST_WRITER)) return;

  pi.on("tool_call", async (event) => {
    // The test-writer owns the tests: it may only write test files.
    if (ROLE === TEST_WRITER) {
      if (isToolCallEventType("edit", event) || isToolCallEventType("write", event)) {
        const target = String(event.input.path ?? "");
        if (!isTestPath(target)) return blockTestWriter(`writing non-test file "${target}"`);
      }
      return;
    }

    if (isToolCallEventType("read", event)) {
      if (isTestPath(event.input.path)) return blockBuilder(`reading test file "${event.input.path}"`);
      return;
    }

    if (isToolCallEventType("edit", event) || isToolCallEventType("write", event)) {
      if (isTestPath(event.input.path)) return blockBuilder(`modifying test file "${event.input.path}"`);
      return;
    }

    if (isToolCallEventType("ls", event)) {
      if (isTestPath(event.input.path)) return blockBuilder(`listing test directory "${event.input.path}"`);
      return;
    }

    if (isToolCallEventType("grep", event)) {
      if (isTestPath(event.input.path) || isTestPath(event.input.glob)) {
        return blockBuilder(`searching tests (path="${event.input.path ?? "."}", glob="${event.input.glob ?? ""}")`);
      }
      if (!hasExplicitPath(event.input.path)) {
        return blockBuilder(
          `unscoped grep (no "path"), which searches the whole tree and can surface test code. ` +
            `Pass an explicit "path" that is not a test path.`,
        );
      }
      return;
    }

    if (isToolCallEventType("find", event)) {
      if (isTestPath(event.input.path) || isTestPath(event.input.pattern)) {
        return blockBuilder(`finding in tests (path="${event.input.path ?? "."}", pattern="${event.input.pattern}")`);
      }
      if (!hasExplicitPath(event.input.path)) {
        return blockBuilder(
          `unscoped find (no "path"), which searches the whole tree and can surface test code. ` +
            `Pass an explicit "path" that is not a test path.`,
        );
      }
      return;
    }

    if (isToolCallEventType("bash", event)) {
      if (bashTouchesTests(String(event.input.command ?? ""))) {
        return blockBuilder(`shell access to a test path: ${String(event.input.command).slice(0, 120)}`);
      }
      return;
    }
  });
}
