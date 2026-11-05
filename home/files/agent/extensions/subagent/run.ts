/**
 * Running a subagent child, and the result shape the child produces.
 *
 * One child is spawned per dispatch: a separate `pi` process in JSON mode whose
 * events are collected into a SingleResult. The presentation of those results
 * lives in render.ts; this module only produces them.
 */

import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";
import type { AgentToolResult, ThinkingLevel } from "@earendil-works/pi-agent-core";
import type { Message } from "@earendil-works/pi-ai";
import type { AgentConfig, AgentScope } from "./agents.ts";
import { writeAppendedPrompt } from "./prompt.ts";

const PER_TASK_OUTPUT_CAP = 50 * 1024;

/** Explicit extensions the parent session was started with, forwarded to each child. */
const EXTENSIONS_ENV = "PI_SUBAGENT_EXTENSIONS";

/** Ignored entries already reported, so a dispatch loop names each one once. */
const reportedExtensionEntries = new Set<string>();

export interface UsageStats {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	contextTokens: number;
	turns: number;
}

export interface SingleResult {
	agent: string;
	agentSource: "user" | "project" | "unknown";
	task: string;
	exitCode: number;
	messages: Message[];
	stderr: string;
	usage: UsageStats;
	model?: string;
	stopReason?: string;
	errorMessage?: string;
	step?: number;
}

export interface SubagentDetails {
	mode: "single" | "parallel" | "chain";
	agentScope: AgentScope;
	projectAgentsDir: string | null;
	results: SingleResult[];
}

export function getFinalOutput(messages: Message[]): string {
	for (let i = messages.length - 1; i >= 0; i--) {
		const msg = messages[i];
		if (msg.role === "assistant") {
			for (const part of msg.content) {
				if (part.type === "text") return part.text;
			}
		}
	}
	return "";
}

export function isFailedResult(result: SingleResult): boolean {
	return result.exitCode !== 0 || result.stopReason === "error" || result.stopReason === "aborted";
}

export function getResultOutput(result: SingleResult): string {
	if (isFailedResult(result)) {
		return result.errorMessage || result.stderr || getFinalOutput(result.messages) || "(no output)";
	}
	return getFinalOutput(result.messages) || "(no output)";
}

export function truncateParallelOutput(output: string): string {
	const byteLength = Buffer.byteLength(output, "utf8");
	if (byteLength <= PER_TASK_OUTPUT_CAP) return output;

	let truncated = output.slice(0, PER_TASK_OUTPUT_CAP);
	while (Buffer.byteLength(truncated, "utf8") > PER_TASK_OUTPUT_CAP) {
		truncated = truncated.slice(0, -1);
	}
	return `${truncated}\n\n[Output truncated: ${byteLength - Buffer.byteLength(truncated, "utf8")} bytes omitted. Full output preserved in tool details.]`;
}

function getPiInvocation(args: string[]): { command: string; args: string[] } {
	const currentScript = process.argv[1];
	const isBunVirtualScript = currentScript?.startsWith("/$bunfs/root/");
	if (currentScript && !isBunVirtualScript && fs.existsSync(currentScript)) {
		return { command: process.execPath, args: [currentScript, ...args] };
	}

	const execName = path.basename(process.execPath).toLowerCase();
	const isGenericRuntime = /^(node|bun)(\.exe)?$/.test(execName);
	if (!isGenericRuntime) {
		return { command: process.execPath, args };
	}

	return { command: "pi", args };
}

export interface ForwardedExtensions {
	/** Child arguments, `--extension <path>` per usable entry, in the given order. */
	args: string[];
	/** One message per unusable entry, for the caller to surface. */
	warnings: string[];
}

/**
 * Child arguments for the extensions the parent session was started with.
 *
 * pi offers no way for an extension to learn which extensions the session
 * loaded, so the list is supplied explicitly through PI_SUBAGENT_EXTENSIONS:
 * absolute file paths, separated by the platform path delimiter. Without it a
 * child runs with its own extension discovery only, and the guards that limit
 * what the coordinator may do (role firewall, plan gate, file-size budget) are
 * missing from the process that actually writes files.
 *
 * Entries are validated, not trusted. A relative path resolves against the
 * child's working directory, which is the project being delegated into, so it
 * can silently load a different file than the parent meant; silently loading
 * the wrong guard is worse than skipping it. A path that does not exist is dead
 * weight. Both are skipped and named in a warning. An unset variable, or one
 * with no usable entry, adds nothing at all: forwarding is a no-op for every
 * setup that never exports it.
 */
export function forwardedExtensionArgs(raw: string | undefined): ForwardedExtensions {
	const args: string[] = [];
	const warnings: string[] = [];
	// A trailing or doubled delimiter yields an empty segment, which is not an
	// entry, so it is skipped without a complaint. Whitespace-only segments are
	// the same shape of mistake, while a real path may legitimately contain
	// spaces and is never trimmed.
	for (const entry of (raw ?? "").split(path.delimiter)) {
		if (!entry.trim()) continue;

		if (!path.isAbsolute(entry)) {
			warnings.push(
				`Ignoring ${EXTENSIONS_ENV} entry "${entry}": not an absolute path, so it would resolve differently in the subagent's working directory.`,
			);
			continue;
		}

		if (!fs.existsSync(entry)) {
			warnings.push(`Ignoring ${EXTENSIONS_ENV} entry "${entry}": no such file.`);
			continue;
		}

		args.push("--extension", entry);
	}
	return { args, warnings };
}

export type OnUpdateCallback = (partial: AgentToolResult<SubagentDetails>) => void;

export interface DispatchDefaults {
	model?: string;
	thinkingLevel?: ThinkingLevel;
}

export async function runSingleAgent(
	defaultCwd: string,
	dispatchDefaults: DispatchDefaults,
	agents: AgentConfig[],
	agentName: string,
	task: string,
	cwd: string | undefined,
	step: number | undefined,
	signal: AbortSignal | undefined,
	onUpdate: OnUpdateCallback | undefined,
	makeDetails: (results: SingleResult[]) => SubagentDetails,
	onWarning: ((message: string) => void) | undefined,
): Promise<SingleResult> {
	const agent = agents.find((a) => a.name === agentName);

	if (!agent) {
		const available = agents.map((a) => `"${a.name}"`).join(", ") || "none";
		return {
			agent: agentName,
			agentSource: "unknown",
			task,
			exitCode: 1,
			messages: [],
			stderr: `Unknown agent: "${agentName}". Available agents: ${available}.`,
			usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
			step,
		};
	}

	// A subagent has one fixed job: discovered skills, slash-command templates and
	// the global policy are weight it cannot act on (~4300 of the ~4725 tokens a
	// child used to inherit, measured rather than assumed). Project conventions are
	// kept because that is where a codebase's own rules live: ./prompt.ts appends
	// them, which is what makes --no-context-files safe here.
	const args: string[] = ["--mode", "json", "-p", "--no-session", "--no-skills", "--no-prompt-templates", "--no-context-files"];
	const inheritsDispatchConfig = !agent.model;
	const model = agent.profileModel ?? agent.model ?? dispatchDefaults.model;
	if (model) args.push("--model", model);
	if (inheritsDispatchConfig && dispatchDefaults.thinkingLevel) {
		args.push("--thinking", dispatchDefaults.thinkingLevel);
	}
	if (agent.tools && agent.tools.length > 0) args.push("--tools", agent.tools.join(","));

	// Guards the parent session was started with must reach the child too, or
	// the coordinator is the only process they protect. See
	// forwardedExtensionArgs for the format and why it is an env var.
	const forwardedExtensions = forwardedExtensionArgs(process.env[EXTENSIONS_ENV]);
	for (const warning of forwardedExtensions.warnings) {
		if (reportedExtensionEntries.has(warning)) continue;
		reportedExtensionEntries.add(warning);
		onWarning?.(warning);
	}
	args.push(...forwardedExtensions.args);

	let tmpPromptDir: string | null = null;
	let tmpPromptPath: string | null = null;

	const currentResult: SingleResult = {
		agent: agentName,
		agentSource: agent.source,
		task,
		exitCode: 0,
		messages: [],
		stderr: "",
		usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
		model,
		step,
	};

	const emitUpdate = () => {
		if (onUpdate) {
			onUpdate({
				content: [{ type: "text", text: getFinalOutput(currentResult.messages) || "(running...)" }],
				details: makeDetails([currentResult]),
			});
		}
	};

	try {
		const appended = await writeAppendedPrompt(agent.name, agent.systemPrompt, cwd ?? defaultCwd);
		if (appended?.warning) onWarning?.(appended.warning);
		if (appended) {
			tmpPromptDir = appended.dir;
			tmpPromptPath = appended.filePath;
			args.push("--append-system-prompt", tmpPromptPath);
		}

		args.push(`Task: ${task}`);
		let wasAborted = false;

		const exitCode = await new Promise<number>((resolve) => {
			const invocation = getPiInvocation(args);
			const proc = spawn(invocation.command, invocation.args, {
				cwd: cwd ?? defaultCwd,
				shell: false,
				env: { ...process.env, PI_AGENT_ROLE: agent.name },
				stdio: ["ignore", "pipe", "pipe"],
			});
			let buffer = "";

			const processLine = (line: string) => {
				if (!line.trim()) return;
				let event: any;
				try {
					event = JSON.parse(line);
				} catch {
					return;
				}

				if (event.type === "message_end" && event.message) {
					const msg = event.message as Message;
					currentResult.messages.push(msg);

					if (msg.role === "assistant") {
						currentResult.usage.turns++;
						const usage = msg.usage;
						if (usage) {
							currentResult.usage.input += usage.input || 0;
							currentResult.usage.output += usage.output || 0;
							currentResult.usage.cacheRead += usage.cacheRead || 0;
							currentResult.usage.cacheWrite += usage.cacheWrite || 0;
							currentResult.usage.cost += usage.cost?.total || 0;
							currentResult.usage.contextTokens = usage.totalTokens || 0;
						}
						if (!currentResult.model && msg.model) currentResult.model = msg.model;
						if (msg.stopReason) currentResult.stopReason = msg.stopReason;
						if (msg.errorMessage) currentResult.errorMessage = msg.errorMessage;
					}
					emitUpdate();
				}

				if (event.type === "tool_result_end" && event.message) {
					currentResult.messages.push(event.message as Message);
					emitUpdate();
				}
			};

			proc.stdout.on("data", (data) => {
				buffer += data.toString();
				const lines = buffer.split("\n");
				buffer = lines.pop() || "";
				for (const line of lines) processLine(line);
			});

			proc.stderr.on("data", (data) => {
				currentResult.stderr += data.toString();
			});

			proc.on("close", (code) => {
				if (buffer.trim()) processLine(buffer);
				resolve(code ?? 0);
			});

			proc.on("error", () => {
				resolve(1);
			});

			if (signal) {
				const killProc = () => {
					wasAborted = true;
					proc.kill("SIGTERM");
					setTimeout(() => {
						if (!proc.killed) proc.kill("SIGKILL");
					}, 5000);
				};
				if (signal.aborted) killProc();
				else signal.addEventListener("abort", killProc, { once: true });
			}
		});

		currentResult.exitCode = exitCode;
		if (wasAborted) throw new Error("Subagent was aborted");
		return currentResult;
	} finally {
		if (tmpPromptPath)
			try {
				fs.unlinkSync(tmpPromptPath);
			} catch {
				/* ignore */
			}
		if (tmpPromptDir)
			try {
				fs.rmdirSync(tmpPromptDir);
			} catch {
				/* ignore */
			}
	}
}
