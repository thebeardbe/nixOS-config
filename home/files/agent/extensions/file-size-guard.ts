import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { isTestPath } from "./lib/test-content.ts";

/**
 * file-size-guard: prevents god files from growing.
 *
 * On every `edit`/`write` it projects the resulting line count:
 *   - past the soft limit -> notify a warning (once per file per session)
 *   - past the hard limit -> block, unless the file is already a god file and
 *     the change makes it smaller or keeps it the same size
 * Test/spec files are warned about but never blocked.
 * Shell writes (`>`, `>>`, `tee`) that would grow a large source file trigger a
 * warning (the target is inspected even when it does not exist yet).
 *
 * Config (environment):
 *   PI_FILE_SOFT_LINES  default 600
 *   PI_FILE_HARD_LINES  default 1000
 *   PI_FILE_GUARD=off   disable
 */

function intEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  const n = raw ? Number.parseInt(raw, 10) : Number.NaN;
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

const SOFT = intEnv("PI_FILE_SOFT_LINES", 600);
const HARD = intEnv("PI_FILE_HARD_LINES", 1000);
const OFF = ["off", "0", "false"].includes((process.env.PI_FILE_GUARD ?? "").toLowerCase());

const SRC_EXTS = new Set([
  "py", "pyi", "js", "jsx", "mjs", "cjs", "ts", "tsx", "go", "rb", "rs",
  "java", "kt", "kts", "cs", "php", "swift", "scala", "c", "cc", "cpp", "h",
  "hpp", "vue", "svelte", "dart", "lua", "ex", "exs", "sh", "ps1", "sql",
]);

const SKIP_RE =
  /(^|\/)(node_modules|vendor|dist|build|\.git|\.venv|__pycache__|\.pytest_cache|target|coverage|generated|migrations|__snapshots__|fixtures)(\/|$)|\.min\.|\.lock$|\.d\.ts$|\.generated\.|\.g\.dart$|\.freezed\.dart$|_pb2\.py$|\.pb\.go$/;

const TEST_RE =
  /(^|\/)(test|tests|spec|specs|__tests__)\/|\.(test|spec)\.|(^|\/)test_|_test\.|(^|\/)spec_/;

function stripAt(p: string): string {
  return p.startsWith("@") ? p.slice(1) : p;
}

function countLines(text: string): number {
  if (!text) return 0;
  let n = 0;
  for (let i = 0; i < text.length; i++) if (text.charCodeAt(i) === 10) n++;
  return text.endsWith("\n") ? n : n + 1;
}

/** Project the line count after applying edits; null when an anchor is missing. */
function projectEdits(current: string, edits: { oldText: string; newText: string }[]): number | null {
  let text = current;
  for (const e of edits) {
    const at = text.indexOf(e.oldText);
    if (at === -1) return null; // the real edit will fail; do not block a guess
    text = text.slice(0, at) + e.newText + text.slice(at + e.oldText.length);
  }
  return countLines(text);
}

export default function (pi: ExtensionAPI) {
  const warned = new Set<string>();
  // Human-granted exceptions, set by the approval prompt below.
  const allowedFiles = new Set<string>(); // "allow for the rest of the session"
  const allowOnce = new Set<string>();    // "allow this edit once" (cleared each turn)

  function notifyOnce(ctx: { ui: { notify(m: string, t?: "info" | "warning" | "error"): void }; hasUI: boolean }, key: string, msg: string) {
    if (!ctx.hasUI) return;
    if (warned.has(key)) return;
    warned.add(key);
    ctx.ui.notify(msg, "warning");
  }

  pi.on("session_start", () => {
    // A new session starts fresh: re-prompt for god files instead of reusing
    // an approval or a warning suppression from the previous session.
    warned.clear();
    allowedFiles.clear();
    allowOnce.clear();
  });

  pi.on("turn_end", () => {
    allowOnce.clear();
  });

  pi.on("tool_call", async (event, ctx) => {
    if (OFF) return;

    const fs = await import("node:fs");
    const path = await import("node:path");

    const absOf = (raw: string) => {
      const p = stripAt(raw);
      return path.isAbsolute(p) ? p : path.resolve(ctx.cwd, p);
    };
    const isSource = (abs: string) => SRC_EXTS.has(path.extname(abs).slice(1).toLowerCase());
    const readCurrent = (abs: string): string | null => {
      try {
        return fs.readFileSync(abs, "utf8");
      } catch {
        return null;
      }
    };

    // Shell writes to a source file: warn only (sed/rename/moves are legitimate).
    if (isToolCallEventType("bash", event)) {
      const cmd = String(event.input.command ?? "");
      const m = cmd.match(
        /(>>|>|tee\s+-a\b|tee\b)\s*("[^"]+"|'[^']+'|[^\s;|&<>()]+\.(?:py|pyi|js|jsx|mjs|cjs|ts|tsx|go|rb|rs|java|kt|cs|php|vue|svelte|dart|sh|sql))\b/,
      );
      if (m) {
        const target = absOf(m[2].replace(/^["']|["']$/g, ""));
        if (!isSource(target) || SKIP_RE.test(target)) return;
        // Inspect the target regardless of its current size: an append can only
        // add lines, so warn as soon as the file is already large; an overwrite
        // replaces the content, so warn only when it is already a god file.
        const append = m[1].startsWith(">>") || /\btee\s+-a\b/.test(m[1]);
        const cur = countLines(readCurrent(target) ?? "");
        const rel = path.relative(ctx.cwd, target);
        if (append ? cur >= SOFT : cur > HARD) {
          ctx.ui.notify(
            append
              ? `shell append to large source file ${rel} (${cur} lines; soft limit ${SOFT}). It would grow a file that already needs splitting; edit it normally instead.`
              : `shell overwrite of god file ${rel} (${cur} lines; hard limit ${HARD}). Split it instead of rewriting it via the shell.`,
            "warning",
          );
        }
      }
      return;
    }

    let abs: string;
    let current = 0;
    let projected: number | null = null;

    if (isToolCallEventType("write", event)) {
      abs = absOf(String(event.input.path ?? ""));
      if (!isSource(abs) || SKIP_RE.test(abs)) return;
      current = countLines(readCurrent(abs) ?? "");
      projected = countLines(String(event.input.content ?? ""));
    } else if (isToolCallEventType("edit", event)) {
      abs = absOf(String(event.input.path ?? ""));
      if (!isSource(abs) || SKIP_RE.test(abs)) return;
      const cur = readCurrent(abs);
      if (cur === null) return; // new/untracked file: nothing to project against
      current = countLines(cur);
      projected = projectEdits(cur, (event.input.edits ?? []) as { oldText: string; newText: string }[]);
    } else {
      return;
    }

    if (projected === null) return;
    const rel = path.relative(ctx.cwd, abs) || abs;

    if (projected > HARD) {
      // An existing god file may shrink or stay the same, never grow.
      if (current > HARD && projected <= current) {
        notifyOnce(ctx, `shrink:${abs}`, `${rel} is still a god file (${current} -> ${projected} lines). Keep extracting; do not add new concerns.`);
        return;
      }
      if (TEST_RE.test(abs)) {
        notifyOnce(ctx, `soft:${abs}`, `${rel} is large (${projected} lines) for a test file. Consider splitting by domain.`);
        return;
      }
      if (allowedFiles.has(abs)) {
        notifyOnce(ctx, `allowed:${abs}`, `${rel} append allowed for this session (god file, ${current} -> ${projected} lines). It still needs splitting.`);
        return;
      }
      if (allowOnce.has(abs)) return;

      const splitReason =
        `User chose to split ${rel} first. Stop implementing the current feature and change nothing else.\n` +
        `Produce a short handoff so the split can happen in a NEW session:\n` +
        `  1. The pending feature request and its current state.\n` +
        `  2. A numbered split plan for ${rel}: responsibilities, target modules, extraction order.\n` +
        `  3. Where it is recorded (for example NOTES.md).\n` +
        `Then tell the user to start a new session for the split and to return to the feature afterwards. ` +
        `Do not start the split in this session. See the god-file-guard skill.`;

      if (!ctx.hasUI) {
        return {
          block: true,
          reason:
            `${rel} would reach ${projected} lines (hard limit ${HARD}); it is a god file.\n` +
            `Split it before adding anything (see the god-file-guard skill and /godfiles). ` +
            `If this is genuinely one cohesive unit, move it under an excluded path or set PI_FILE_HARD_LINES deliberately. ` +
            `Do not bypass this with shell redirection.`,
        };
      }

      const choice = await ctx.ui.select(
        `God file: ${rel}\n${current} -> ${projected} lines (hard limit ${HARD}).\n\nWhat should happen?`,
        [
          "Allow this edit once",
          "Allow this file for the rest of the session",
          "Stop and split this file first in a new session (recommended)",
          "Cancel this edit",
        ],
      );

      if (choice && choice.startsWith("Allow this edit once")) {
        allowOnce.add(abs);
        ctx.ui.notify(`Allowed one edit to god file ${rel} (${projected} lines).`, "warning");
        return;
      }
      if (choice && choice.startsWith("Allow this file")) {
        allowedFiles.add(abs);
        ctx.ui.notify(`Appending to god file ${rel} is allowed for this session. It still needs splitting.`, "warning");
        return;
      }
      if (choice && choice.startsWith("Stop and split")) {
        return { block: true, terminate: true, reason: splitReason };
      }
      return {
        block: true,
        terminate: true,
        reason: `User cancelled the edit to god file ${rel}. Do not retry it; ask how they want to proceed.`,
      };
    }

    if (projected > SOFT) {
      notifyOnce(
        ctx,
        `soft:${abs}`,
        `${rel} is getting large (${projected} lines; soft limit ${SOFT}). Plan a split before adding another concern.`,
      );
    }
  });

  pi.registerCommand("godfiles", {
    description: `List source files over the size budget (soft ${SOFT}, hard ${HARD})`,
    handler: async (_args, ctx) => {
      const fs = await import("node:fs");
      const path = await import("node:path");
      const { execSync } = await import("node:child_process");

      let files: string[] = [];
      try {
        const listed = execSync("git ls-files --cached --others --exclude-standard", {
          cwd: ctx.cwd,
          maxBuffer: 16 * 1024 * 1024,
        }).toString();
        files = listed.split("\n").filter(Boolean);
      } catch {
        files = [];
      }
      if (files.length === 0) {
        ctx.ui.notify("godfiles: not a git repo (or no files); run it inside a repo.", "warning");
        return;
      }

      const rows: { n: number; f: string; level: string }[] = [];
      for (const f of files) {
        if (!SRC_EXTS.has(path.extname(f).slice(1).toLowerCase())) continue;
        if (SKIP_RE.test(f)) continue;
        // Test files are reported per the guard's warn-only rule, not as GOD/WARN.
        if (isTestPath(f)) continue;
        try {
          const n = countLines(fs.readFileSync(path.resolve(ctx.cwd, f), "utf8"));
          if (n > HARD) rows.push({ n, f, level: "GOD " });
          else if (n > SOFT) rows.push({ n, f, level: "WARN" });
        } catch {
          /* unreadable */
        }
      }
      rows.sort((a, b) => b.n - a.n);

      if (rows.length === 0) {
        ctx.ui.notify(`godfiles: no source files over ${SOFT} lines.`, "info");
        return;
      }
      const lines = [
        `godfiles - soft ${SOFT} / hard ${HARD} (${rows.length} file${rows.length === 1 ? "" : "s"})`,
        ...rows.slice(0, 20).map((r) => `${r.level} ${String(r.n).padStart(6)}  ${r.f}`),
        rows.length > 20 ? `... and ${rows.length - 20} more` : "",
      ].filter(Boolean);
      try {
        ctx.ui.setWidget("godfiles", lines);
      } catch {
        /* widget unavailable in this mode */
      }
      const gods = rows.filter((r) => r.level === "GOD ").length;
      ctx.ui.notify(`godfiles: ${gods} god file(s), ${rows.length - gods} warning(s).`, gods ? "warning" : "info");
    },
  });
}
