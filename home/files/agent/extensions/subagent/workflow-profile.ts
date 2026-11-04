/**
 * Machine-level model profile
 *
 * Reads `<agent-dir>/workflow.json`, the operator's switch for moving the whole
 * agent roster between model sets (local and cloud, for example) without
 * editing agent files, which are read-only store symlinks on this machine.
 *
 *     {
 *       "version": 1,
 *       "profile": "backup",
 *       "profiles": {
 *         "primary": { "builder": "provider/model" },
 *         "backup": { "builder": "provider/model" }
 *       }
 *     }
 *
 * Role keys are agent names and values use the same `provider/model` form as
 * agent frontmatter. The profile is advisory: a role it does not name keeps the
 * model from its agent file, and that falls back to the dispatch defaults.
 *
 * A filename that exists but cannot be used is reported once per process, and
 * that distinction is the point: silently running the wrong model is worse than
 * running no override at all, so a broken file has to be visible. A missing
 * file, or one that names no active profile, is a normal state and stays quiet.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { getAgentDir } from "@earendil-works/pi-coding-agent";

/** Bump when the file's shape changes; anything else is an unknown version. */
const SUPPORTED_VERSION = 1;

const PROFILE_FILE = "workflow.json";

export interface ModelProfile {
	/** Agent name -> `provider/model`, for the roles the active profile names. */
	models: Map<string, string>;
	/** Why the file was ignored. Set at most once per process, then undefined. */
	warning?: string;
}

/** At most one notice per process: a dispatch loop must not repeat the complaint. */
let warned = false;

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function reasonOf(error: unknown): string {
	return error instanceof Error ? error.message : String(error);
}

/**
 * Report a file that exists but cannot be trusted, and use no override at all.
 *
 * All-or-nothing on purpose: keeping the roles that happen to parse would allow
 * a half-applied profile, which is the hardest failure for an operator to spot.
 */
function unusable(filePath: string, reason: string): ModelProfile {
	if (warned) return { models: new Map() };
	warned = true;
	return { models: new Map(), warning: `model profile ${filePath} ignored: ${reason}` };
}

/**
 * Read and validate the profile for one dispatch. Never throws: every failure
 * degrades to an empty profile, so dispatch keeps the agent and default models.
 */
export function loadModelProfile(): ModelProfile {
	const filePath = path.join(getAgentDir(), PROFILE_FILE);

	let raw: string;
	try {
		raw = fs.readFileSync(filePath, "utf-8");
	} catch (error) {
		// No file means no profile is configured anywhere: not an error.
		if ((error as NodeJS.ErrnoException).code === "ENOENT") return { models: new Map() };
		return unusable(filePath, `unreadable (${reasonOf(error)})`);
	}

	let parsed: unknown;
	try {
		parsed = JSON.parse(raw);
	} catch (error) {
		return unusable(filePath, `not valid JSON (${reasonOf(error)})`);
	}

	if (!isRecord(parsed)) return unusable(filePath, "top level is not a JSON object");
	if (parsed.version !== SUPPORTED_VERSION) {
		const found = JSON.stringify(parsed.version);
		return unusable(filePath, `unsupported version ${found} (expected ${SUPPORTED_VERSION})`);
	}

	const profiles = parsed.profiles;
	if (!isRecord(profiles)) return unusable(filePath, '"profiles" is not a JSON object');

	// A file that only stores profiles selects none: the roster stays as it is.
	if (parsed.profile === undefined) return { models: new Map() };
	if (typeof parsed.profile !== "string" || !parsed.profile.trim()) {
		return unusable(filePath, '"profile" is not a non-empty string');
	}

	const activeName = parsed.profile.trim();
	const roles = profiles[activeName];
	if (roles === undefined) return unusable(filePath, `active profile "${activeName}" is not defined in "profiles"`);
	if (!isRecord(roles)) return unusable(filePath, `profile "${activeName}" is not a JSON object`);

	const models = new Map<string, string>();
	for (const [role, value] of Object.entries(roles)) {
		if (typeof value !== "string" || !value.trim()) {
			return unusable(filePath, `role "${role}" in profile "${activeName}" is not a "provider/model" string`);
		}
		models.set(role, value.trim());
	}

	return { models };
}
