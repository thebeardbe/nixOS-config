/**
 * Appended system prompt for a subagent child.
 *
 * The parent disables pi's context-file discovery (see the flags in index.ts),
 * so the child's system prompt is rebuilt here: the agent's own body plus the
 * project's instruction file, which is where a codebase's own rules live.
 */

import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { withFileMutationQueue } from "@earendil-works/pi-coding-agent";

// Pi's own precedence order for context files. Only the first that exists is
// used, because pi treats a later name as a fallback, not as an addition.
const PROJECT_INSTRUCTION_FILES = ["AGENTS.md", "CLAUDE.md"] as const;

export interface AppendedPrompt {
	dir: string;
	filePath: string;
}

function readProjectInstructions(cwd: string): string {
	for (const name of PROJECT_INSTRUCTION_FILES) {
		const filePath = path.join(cwd, name);
		if (fs.existsSync(filePath)) return fs.readFileSync(filePath, "utf-8");
	}
	return "";
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
	const text = [systemPrompt.trim(), readProjectInstructions(cwd)].filter(Boolean).join("\n\n");
	if (!text) return null;

	const dir = await fs.promises.mkdtemp(path.join(os.tmpdir(), "pi-subagent-"));
	const safeName = agentName.replace(/[^\w.-]+/g, "_");
	const filePath = path.join(dir, `prompt-${safeName}.md`);
	await withFileMutationQueue(filePath, async () => {
		await fs.promises.writeFile(filePath, text, { encoding: "utf-8", mode: 0o600 });
	});
	return { dir, filePath };
}
