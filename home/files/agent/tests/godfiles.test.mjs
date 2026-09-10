// Tests for skills/god-file-guard/scripts/godfiles.sh.
//
// Each test builds a throwaway git repo under the OS temp dir, writes source
// files with a known line count, runs the script against it and inspects the
// report. All fixtures are removed afterwards.

import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import { resolveAgentRoot, GODFILES_MARKER } from "./agent-root.mjs";

const SCRIPT = path.join(resolveAgentRoot([GODFILES_MARKER]), GODFILES_MARKER);

/** Create a git repo in a fresh temp dir with the given files. */
function makeRepo(files) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "godfiles-test-"));
  execFileSync("git", ["init", "-q"], { cwd: dir, stdio: "ignore" });
  for (const [rel, lines] of Object.entries(files)) {
    const full = path.join(dir, rel);
    fs.mkdirSync(path.dirname(full), { recursive: true });
    fs.writeFileSync(full, "const value = 1;\n".repeat(lines));
  }
  return dir;
}

/** Create a repo and register its cleanup on the test context. */
function fixture(t, files) {
  const dir = makeRepo(files);
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  return dir;
}

/** Run the script, always with the size env vars cleared unless overridden. */
function runScript(root, env = {}) {
  const base = { ...process.env };
  delete base.PI_FILE_SOFT_LINES;
  delete base.PI_FILE_HARD_LINES;
  return spawnSync("bash", [SCRIPT, root], {
    encoding: "utf8",
    env: { ...base, ...env },
  });
}

const SMALL = { PI_FILE_SOFT_LINES: "10", PI_FILE_HARD_LINES: "50" };

test("exits 0 and reports its thresholds", (t) => {
  const dir = fixture(t, { "src/small.ts": 5 });
  const res = runScript(dir, SMALL);
  assert.equal(res.status, 0, res.stderr);
  assert.match(res.stdout, /soft=10 hard=50/);
});

test("does not report a small source file", (t) => {
  const dir = fixture(t, { "src/small.ts": 5, "src/tiny.py": 1 });
  const res = runScript(dir, SMALL);
  assert.equal(res.status, 0, res.stderr);
  assert.doesNotMatch(res.stdout, /src\/small\.ts/);
  assert.doesNotMatch(res.stdout, /src\/tiny\.py/);
});

test("reports a source file over the hard limit as a god file", (t) => {
  const dir = fixture(t, { "src/big.ts": 60 });
  const res = runScript(dir, SMALL);
  assert.equal(res.status, 0, res.stderr);
  assert.match(res.stdout, /^GOD\s+60\s+src\/big\.ts$/m);
});

test("treats the hard limit as exclusive: exactly hard is WARN, one over is GOD", (t) => {
  const dir = fixture(t, { "src/exact.ts": 50, "src/over.ts": 51 });
  const res = runScript(dir, SMALL);
  assert.equal(res.status, 0, res.stderr);
  assert.match(res.stdout, /^WARN\s+50\s+src\/exact\.ts$/m);
  assert.doesNotMatch(res.stdout, /^GOD\s+50\s+src\/exact\.ts$/m);
  assert.match(res.stdout, /^GOD\s+51\s+src\/over\.ts$/m);
});

test("reports a file between soft and hard as WARN", (t) => {
  const dir = fixture(t, { "src/mid.ts": 20 });
  const res = runScript(dir, SMALL);
  assert.equal(res.status, 0, res.stderr);
  assert.match(res.stdout, /^WARN\s+20\s+src\/mid\.ts$/m);
  assert.doesNotMatch(res.stdout, /^GOD\s+\d+\s/m);
});

test("honours PI_FILE_SOFT_LINES and PI_FILE_HARD_LINES", (t) => {
  const dir = fixture(t, { "src/mid.ts": 20 });

  // Above soft but below hard -> WARN.
  assert.match(runScript(dir, SMALL).stdout, /^WARN\s+20\s+src\/mid\.ts$/m);

  // Soft raised above the file -> not reported at all.
  const quiet = runScript(dir, { PI_FILE_SOFT_LINES: "50", PI_FILE_HARD_LINES: "100" });
  assert.equal(quiet.status, 0, quiet.stderr);
  assert.doesNotMatch(quiet.stdout, /src\/mid\.ts/);

  // Hard lowered below the file -> GOD.
  const strict = runScript(dir, { PI_FILE_SOFT_LINES: "5", PI_FILE_HARD_LINES: "15" });
  assert.equal(strict.status, 0, strict.stderr);
  assert.match(strict.stdout, /^GOD\s+20\s+src\/mid\.ts$/m);
});

test("does not report test files that are over the hard limit", (t) => {
  const testFiles = {
    "tests/big.test.ts": 60,
    "src/FooTest.java": 60,
    "test_big.py": 60,
    "src/foo_test.go": 60,
    "conftest.py": 60,
    "__tests__/legacy.ts": 60,
  };
  // A control file proves the run was not simply empty.
  const dir = fixture(t, { ...testFiles, "src/real.ts": 60 });
  const res = runScript(dir, SMALL);
  assert.equal(res.status, 0, res.stderr);
  assert.match(res.stdout, /^GOD\s+60\s+src\/real\.ts$/m);
  for (const rel of Object.keys(testFiles)) {
    assert.doesNotMatch(res.stdout, new RegExp(rel.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  }
});

test("applies the default thresholds when the env vars are unset", (t) => {
  const dir = fixture(t, { "src/huge.ts": 1001, "src/exact.ts": 1000 });
  const res = runScript(dir); // no overrides, clears any inherited values
  assert.equal(res.status, 0, res.stderr);
  assert.match(res.stdout, /soft=600 hard=1000/);
  assert.match(res.stdout, /^GOD\s+1001\s+src\/huge\.ts$/m);
  assert.match(res.stdout, /^WARN\s+1000\s+src\/exact\.ts$/m);
});

test("exits 0 for a root that does not exist", () => {
  const missing = path.join(os.tmpdir(), "godfiles-missing-root-does-not-exist");
  const res = runScript(missing);
  assert.equal(res.status, 0, res.stderr);
  assert.match(res.stdout, /cannot cd to/);
});
