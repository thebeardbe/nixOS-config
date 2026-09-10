// Tests for tests/agent-root.mjs, the helper that locates the pi agent
// configuration root from either the repository or the deployed location.

import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import {
  agentRootCandidates,
  resolveAgentRoot,
  TEST_CONTENT_MARKER,
  GODFILES_MARKER,
} from "./agent-root.mjs";

/** Set PI_AGENT_DIR for one test and restore the previous value afterwards. */
function setAgentDir(t, value) {
  const previous = process.env.PI_AGENT_DIR;
  t.after(() => {
    if (previous === undefined) delete process.env.PI_AGENT_DIR;
    else process.env.PI_AGENT_DIR = previous;
  });
  if (value === undefined) delete process.env.PI_AGENT_DIR;
  else process.env.PI_AGENT_DIR = value;
}

/** A throwaway directory with the given marker paths materialised. */
function fixture(t, markers = []) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "agent-root-test-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  for (const marker of markers) {
    const full = path.join(dir, marker);
    fs.mkdirSync(path.dirname(full), { recursive: true });
    fs.writeFileSync(full, "");
  }
  return dir;
}

test("resolves the test-content marker from an available layout", () => {
  const root = resolveAgentRoot([TEST_CONTENT_MARKER]);
  assert.ok(
    fs.existsSync(path.join(root, TEST_CONTENT_MARKER)),
    `${root} should contain ${TEST_CONTENT_MARKER}`,
  );
});

test("resolves the godfiles marker from an available layout", () => {
  const root = resolveAgentRoot([GODFILES_MARKER]);
  assert.ok(
    fs.existsSync(path.join(root, GODFILES_MARKER)),
    `${root} should contain ${GODFILES_MARKER}`,
  );
});

test("PI_AGENT_DIR override takes precedence when it holds the marker", (t) => {
  const dir = fixture(t, [TEST_CONTENT_MARKER]);
  setAgentDir(t, dir);
  assert.equal(resolveAgentRoot([TEST_CONTENT_MARKER]), path.resolve(dir));
});

test("skips a PI_AGENT_DIR override that is missing the marker", (t) => {
  const empty = fixture(t); // no markers at all
  setAgentDir(t, empty);
  const root = resolveAgentRoot([TEST_CONTENT_MARKER]);
  assert.notEqual(root, path.resolve(empty));
  assert.ok(fs.existsSync(path.join(root, TEST_CONTENT_MARKER)));
});

test("ignores an empty PI_AGENT_DIR override", (t) => {
  setAgentDir(t, "");
  const root = resolveAgentRoot([TEST_CONTENT_MARKER]);
  assert.ok(fs.existsSync(path.join(root, TEST_CONTENT_MARKER)));
});

test("lists candidate roots without duplicates of the override", (t) => {
  const dir = fixture(t, [TEST_CONTENT_MARKER]);
  setAgentDir(t, dir);
  const candidates = agentRootCandidates();
  assert.equal(candidates[0], path.resolve(dir));
  for (const candidate of candidates) {
    assert.ok(path.isAbsolute(candidate), `${candidate} should be absolute`);
  }
});

test("throws when no candidate contains the required marker", () => {
  assert.throws(
    () => resolveAgentRoot(["no-such-dir/no-such-marker.xyz"]),
    /Could not locate the pi agent configuration root/,
  );
});
