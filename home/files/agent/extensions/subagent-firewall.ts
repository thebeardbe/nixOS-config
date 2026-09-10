import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { looksLikeTestContent } from "./lib/test-content.ts";

/**
 * subagent-firewall: hard-enforce the builder/test boundary.
 *
 * The builder must never receive test code, test paths, test names, or test
 * output. This blocks a `subagent` call before it spawns anything when a
 * builder task:
 *   - contains test source, a test path, or test-runner output, or
 *   - uses the {previous} placeholder, which would forward a prior agent's
 *     output (a test-writer's or reviewer's) straight into the builder.
 *
 * Describe the required behaviour in your own words instead, or let the
 * test-writer own the tests.
 *
 * Config (environment):
 *   PI_SUBAGENT_FIREWALL=off   disable
 */

const OFF = ["off", "0", "false"].includes((process.env.PI_SUBAGENT_FIREWALL ?? "").trim().toLowerCase());

interface TaskItem {
  agent?: unknown;
  task?: unknown;
}

/** Match the agent name the same way agent-role-guard does: trimmed, lower-case. */
function isBuilderName(name: unknown): boolean {
  return String(name ?? "").trim().toLowerCase() === "builder";
}

function collectBuilderTasks(input: Record<string, unknown>): string[] {
  const tasks: string[] = [];
  const consider = (item: TaskItem | undefined) => {
    if (!item) return;
    if (isBuilderName(item.agent) && typeof item.task === "string") tasks.push(item.task);
  };

  if (typeof input.agent === "string" && typeof input.task === "string") {
    consider({ agent: input.agent, task: input.task });
  }
  if (Array.isArray(input.tasks)) for (const t of input.tasks) consider(t as TaskItem);
  if (Array.isArray(input.chain)) for (const t of input.chain) consider(t as TaskItem);

  return tasks;
}

export default function (pi: ExtensionAPI) {
  if (OFF) return;

  pi.on("tool_call", async (event) => {
    if (event.toolName !== "subagent") return;

    const input = event.input as Record<string, unknown>;
    const builderTasks = collectBuilderTasks(input);

    for (const task of builderTasks) {
      if (task.includes("{previous}")) {
        return {
          block: true,
          reason:
            `Subagent firewall: the builder task uses the {previous} placeholder.\n` +
            `That would forward a prior agent's output (which may contain test code, test names or ` +
            `test output) into the builder. Do not chain into the builder with {previous}.\n` +
            `Instead, describe the required behaviour in your own words and give the builder a clean task.`,
        };
      }

      const reason = looksLikeTestContent(task);
      if (reason) {
        return {
          block: true,
          reason:
            `Subagent firewall: the builder task looks unsafe because ${reason}.\n` +
            `The builder must never receive test code, test paths, test names, or test output. ` +
            `Describe the required behaviour in your own words instead; the test-writer owns the tests.`,
        };
      }
    }
  });
}
