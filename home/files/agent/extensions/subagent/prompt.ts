/**
 * Appended system prompt for a subagent child.
 *
 * The parent disables pi's context-file discovery (see the flags in index.ts),
 * so the child's system prompt is rebuilt here: the agent's own body plus the
 * project's instruction files, which is where a codebase's own rules live.
 *
 * The files are found the way pi finds them, by walking the working directory
 * and its ancestors. A subdirectory dispatch is the normal case for this tool,
 * and its repository keeps one instruction file at the repository root: reading
 * only the working directory would silently drop every project rule, with no
 * warning and no visible symptom except a child that ignores the conventions.
 */

import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { withFileMutationQueue } from "@earendil-works/pi-coding-agent";

// Pi's own candidate list, in pi's precedence order. Only the first that exists
// in a directory is used, because pi treats a later name as a fallback, not as
// an addition.
const PROJECT_INSTRUCTION_FILES = ["AGENTS.override.md", "AGENTS.md", "AGENTS.MD", "CLAUDE.md", "CLAUDE.MD"] as const;

/**
 * Cap on the instruction text appended to a child's prompt.
 *
 * 32 KiB is roughly 8k tokens: this file exists because the child's prompt was
 * trimmed by about 4k tokens, so a larger instruction file would hand back more
 * than the trim saved. Past the cap the outermost file is dropped first, since
 * the working directory's own file is the specific context the dispatch was
 * asked for and an ancestor's file is the broader one. A single file that is
 * still too large is cut rather than kept whole, so the cap always holds.
 */
const MAX_INSTRUCTION_BYTES = 32 * 1024;

export interface AppendedPrompt {
	dir: string;
	filePath: string;
	/** Set when the cap forced files out; the caller shows it to the operator. */
	warning?: string;
}

interface InstructionFile {
	filePath: string;
	content: string;
}

function byteLength(file: InstructionFile): number {
	return Buffer.byteLength(file.content, "utf8");
}

function findInstructionFile(dir: string): InstructionFile | null {
	for (const name of PROJECT_INSTRUCTION_FILES) {
		const filePath = path.join(dir, name);
		// A directory of that name is skipped, as pi skips it.
		if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
			return { filePath, content: fs.readFileSync(filePath, "utf-8") };
		}
	}
	return null;
}

/**
 * Instruction files that apply to `cwd`, ordered the way pi applies them: the
 * outermost file first, the working directory's own file last, so a more
 * specific file still wins over a broader one.
 *
 * The walk stops at the repository root (the nearest ancestor holding a `.git`
 * entry) or at the filesystem root. Files above a repository root belong to a
 * different project, or to the home directory, and are not this project's rules.
 */
function collectInstructionFiles(cwd: string): InstructionFile[] {
	const files: InstructionFile[] = [];
	let dir = path.resolve(cwd);
	while (true) {
		const file = findInstructionFile(dir);
		if (file) files.unshift(file);
		if (fs.existsSync(path.join(dir, ".git"))) break;
		const parent = path.dirname(dir);
		if (parent === dir) break;
		dir = parent;
	}
	return files;
}

interface Truncation {
	filePath: string;
	omittedBytes: number;
}

/**
 * Bring the files under the cap.
 *
 * Ancestors go first, outermost to innermost, while more than one file is left.
 * A single file that is still too large is cut at a line boundary, because the
 * cap has to hold even when the working directory's own file is the enormous
 * one: keeping it whole would let a project hand back more than the trim saved.
 * The note appended after the cut is not counted; it is the explanation.
 */
function applyByteCap(files: InstructionFile[]): {
	kept: InstructionFile[];
	dropped: InstructionFile[];
	truncated: Truncation | null;
} {
	const kept = [...files];
	const dropped: InstructionFile[] = [];
	let total = kept.reduce((sum, file) => sum + byteLength(file), 0);

	while (kept.length > 1 && total > MAX_INSTRUCTION_BYTES) {
		const outermost = kept.shift() as InstructionFile;
		total -= byteLength(outermost);
		dropped.push(outermost);
	}

	let truncated: Truncation | null = null;
	const last = kept[kept.length - 1];
	if (total > MAX_INSTRUCTION_BYTES && last) {
		const buffer = Buffer.from(last.content, "utf8");
		const newline = buffer.subarray(0, MAX_INSTRUCTION_BYTES).lastIndexOf(0x0a) + 1;
		const cut = newline > 0 ? newline : MAX_INSTRUCTION_BYTES;
		const head = buffer.subarray(0, cut).toString("utf8").trimEnd();
		truncated = { filePath: last.filePath, omittedBytes: buffer.length - Buffer.byteLength(head, "utf8") };
		kept[kept.length - 1] = {
			filePath: last.filePath,
			content: `${head}\n\n[Truncated by the subagent prompt cap: ${truncated.omittedBytes} bytes of this file omitted.]`,
		};
	}

	return { kept, dropped, truncated };
}

function capWarning(dropped: InstructionFile[], truncated: Truncation | null): string {
	const limit = `${MAX_INSTRUCTION_BYTES / 1024} KiB`;
	const parts: string[] = [];
	if (dropped.length > 0) parts.push(`left out ${dropped.map((file) => file.filePath).join(", ")}`);
	if (truncated) parts.push(`truncated ${truncated.filePath} (${truncated.omittedBytes} bytes omitted)`);
	return `Subagent prompt cap (${limit}) exceeded: ${parts.join("; ")}.`;
}

function readProjectInstructions(cwd: string): { text: string; warning?: string } {
	const { kept, dropped, truncated } = applyByteCap(collectInstructionFiles(cwd));
	const text = kept
		.map((file) => file.content)
		.filter(Boolean)
		.join("\n\n");
	const capped = dropped.length > 0 || truncated !== null;
	return { text, warning: capped ? capWarning(dropped, truncated) : undefined };
}

/**
 * Write the child's appended system prompt, or return null when there is
 * nothing to append (no agent body and no project instruction file).
 */
export async function writeAppendedPrompt(
	agentName: string,
	systemPrompt: string,
	cwd: string,
): Promise<AppendedPrompt | null> {
	const instructions = readProjectInstructions(cwd);
	const text = [systemPrompt.trim(), instructions.text].filter(Boolean).join("\n\n");
	if (!text) return null;

	const dir = await fs.promises.mkdtemp(path.join(os.tmpdir(), "pi-subagent-"));
	const safeName = agentName.replace(/[^\w.-]+/g, "_");
	const filePath = path.join(dir, `prompt-${safeName}.md`);
	await withFileMutationQueue(filePath, async () => {
		await fs.promises.writeFile(filePath, text, { encoding: "utf-8", mode: 0o600 });
	});
	return { dir, filePath, warning: instructions.warning };
}
