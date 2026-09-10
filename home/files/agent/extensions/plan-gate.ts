import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

/**
 * plan-gate: make the agent propose before it builds.
 *
 * On the first file-changing action of a session it stops and asks the human
 * to confirm that a plan was presented and approved. Once approved, the gate
 * stays open for the rest of the session.
 *
 * Config (environment):
 *   PI_PLAN_GATE=off   disable
 *
 * Non-interactive modes (no UI) are never gated, so scripts keep working.
 */

const OFF = ["off", "0", "false"].includes((process.env.PI_PLAN_GATE ?? "").toLowerCase());

// Output redirection to a file is a mutation. `2>&1`, process substitution
// `>(...)`, and the comparison operators inside `[[ ]]`, `(( ))` and `[ ]` are
// not, so strip those first and reject a `>` followed by `&`, `(` or `=`.
const REDIRECT = /(^|[\s\w])>>?\s*(?!&)(?![<(=])/;

// Verbs that create, remove, copy or move files.
const FILE_VERBS = new Set(["rm", "rmdir", "cp", "mv", "mkdir", "touch", "tee"]);
// `git` subcommands that change the index, working tree or repo state.
const GIT_VERBS = new Set(["add", "stage", "commit", "init", "rm", "mv"]);
// Package-manager subcommands that change installed packages (not `run`/`test`).
const PKG_VERBS = new Set(["i", "ci", "install", "add", "init", "create"]);
const PKG_MANAGERS = new Set(["npm", "pnpm", "yarn", "bun"]);
// Wrappers and shell keywords that run the real command that follows them.
const WRAPPERS = new Set([
  "sudo", "doas", "command", "env", "nohup", "time", "nice", "xargs",
  "if", "then", "elif", "else", "while", "until", "do", "!", "{",
]);

/** First real command word of a simple command, skipping `VAR=x` and wrappers. */
function firstVerb(part: string): { verb: string; rest: string[] } {
  const tokens = part.trim().split(/\s+/).filter(Boolean);
  let i = 0;
  while (
    i < tokens.length &&
    (WRAPPERS.has(tokens[i]) || /^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[i]))
  ) {
    i++;
  }
  return { verb: tokens[i] ?? "", rest: tokens.slice(i + 1) };
}

/** True when the shell command would change files or repo state. */
function isMutatingBash(command: string): boolean {
  const cmd = String(command ?? "");
  if (!cmd.trim()) return false;

  const withoutComparisons = cmd
    .replace(/\[\[[\s\S]*?\]\]/g, " ")
    .replace(/\(\([\s\S]*?\)\)/g, " ")
    .replace(/\[[^\]]*\]/g, " ");
  if (REDIRECT.test(withoutComparisons)) return true;

  for (const part of cmd.split(/[;&|\n]+/)) {
    const { verb, rest } = firstVerb(part);
    if (!verb) continue;
    const sub = rest[0] ?? "";
    if (FILE_VERBS.has(verb)) return true;
    if (verb === "git" && GIT_VERBS.has(sub)) return true;
    if (PKG_MANAGERS.has(verb) && PKG_VERBS.has(sub)) return true;
    if ((verb === "pip" || /^pip[0-9.]+$/.test(verb)) && sub === "install") return true;
    if (verb === "poetry" && sub === "add") return true;
    if (verb === "cargo" && (sub === "new" || sub === "add")) return true;
    if (verb === "go" && sub === "mod" && rest[1] === "init") return true;
    if (verb === "npx" && (sub === "create" || sub.startsWith("create-"))) return true;
  }
  return false;
}

function actionLabel(event: { toolName: string; input: Record<string, unknown> }): string {
  if (event.toolName === "edit" || event.toolName === "write") {
    const p = String(event.input.path ?? "?");
    return `${event.toolName} ${p}`;
  }
  if (event.toolName === "bash") {
    const c = String(event.input.command ?? "").replace(/\s+/g, " ").trim();
    return `bash: ${c.length > 100 ? c.slice(0, 100) + "..." : c}`;
  }
  return event.toolName;
}

export default function (pi: ExtensionAPI) {
  let approved = false;

  pi.on("session_start", () => {
    approved = false;
  });

  pi.on("tool_call", async (event, ctx) => {
    if (OFF || approved) return;
    if (!ctx.hasUI) return; // never break non-interactive runs

    let mutating = false;
    if (isToolCallEventType("edit", event) || isToolCallEventType("write", event)) {
      mutating = true;
    } else if (isToolCallEventType("bash", event)) {
      mutating = isMutatingBash(String(event.input.command ?? ""));
    }
    if (!mutating) return;

    const label = actionLabel(event as unknown as { toolName: string; input: Record<string, unknown> });
    const choice = await ctx.ui.select(
      `Implementation about to start\n${label}\n\nDid the agent present a plan you approve?`,
      ["Proceed - the plan was approved", "Stop - present a numbered plan first"],
    );

    if (choice && choice.startsWith("Proceed")) {
      approved = true;
      ctx.ui.notify("plan-gate open: proceeding with implementation for this session.", "info");
      return;
    }

    return {
      block: true,
      terminate: true,
      reason:
        "The user wants a plan before any changes. Stop now and change nothing.\n" +
        "Present a short numbered plan in this shape: Goal, Steps (each with the files it touches), " +
        "Approach and rejected alternatives, Verification (automated gates plus the manual test the user will run), Open questions. " +
        "Then ask the user to Proceed, Adjust, or Cancel. Only implement after they approve. " +
        "See the plan-first skill.",
    };
  });
}
