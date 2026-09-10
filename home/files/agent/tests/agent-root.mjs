// Resolve the pi agent configuration root independently of where the tests
// are run from.
//
// The configuration lives in the repository under home/files/agent, but
// home-manager deploys it to ~/.pi/agent as read-only store symlinks. Each
// directory becomes its own store path, so after deployment the tests/
// directory is no longer a sibling of extensions/ and skills/ and the usual
// `path.resolve(import.meta.dirname, "..")` trick breaks.
//
// Candidates are tried in order and the first one that actually contains the
// marker(s) the caller needs wins:
//
//   1. $PI_AGENT_DIR, an explicit override (empty values are ignored)
//   2. the repository layout, the parent of this tests/ directory
//   3. the deployed location, $HOME/.pi/agent
//
// Import this from a test file, then resolve paths below the returned root.

import fs from "node:fs";
import os from "node:os";
import path from "node:path";

/** Marker for the shared test-detection helpers. */
export const TEST_CONTENT_MARKER = path.join("extensions", "lib", "test-content.ts");

/** Marker for the god-file size report script. */
export const GODFILES_MARKER = path.join("skills", "god-file-guard", "scripts", "godfiles.sh");

const REPO_LAYOUT_ROOT = path.resolve(import.meta.dirname, "..");
const DEPLOYED_ROOT = path.join(os.homedir(), ".pi", "agent");

/**
 * The candidate roots in preference order, as absolute paths.
 *
 * @returns {string[]}
 */
export function agentRootCandidates() {
  return [process.env.PI_AGENT_DIR, REPO_LAYOUT_ROOT, DEPLOYED_ROOT]
    .filter((candidate) => typeof candidate === "string" && candidate.trim() !== "")
    .map((candidate) => path.resolve(candidate));
}

/**
 * Return the first candidate root that contains every required marker path.
 *
 * @param {string | string[]} required relative marker path(s)
 * @returns {string} absolute configuration root
 */
export function resolveAgentRoot(required) {
  const markers = Array.isArray(required) ? required : [required];
  const candidates = agentRootCandidates();

  for (const root of candidates) {
    if (markers.every((marker) => fs.existsSync(path.join(root, marker)))) {
      return root;
    }
  }

  throw new Error(
    "Could not locate the pi agent configuration root. " +
      `Tried: ${candidates.join(", ")}. ` +
      `None contains: ${markers.join(", ")}. ` +
      "Set PI_AGENT_DIR to the directory holding the agent configuration.",
  );
}
