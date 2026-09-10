// Tests for the shared test-detection helpers in
// extensions/lib/test-content.ts.
//
// Run with:  node --test tests/*.test.mjs
// The production module is TypeScript; Node 24 imports it directly via type
// stripping (no flags, no build step).
//
// The module is imported dynamically so its location can be resolved through
// agent-root.mjs, which works both from the repository and from the deployed
// ~/.pi/agent store symlinks.

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { pathToFileURL } from "node:url";

import { resolveAgentRoot, TEST_CONTENT_MARKER } from "./agent-root.mjs";

const AGENT_ROOT = resolveAgentRoot([TEST_CONTENT_MARKER]);

const { RUNNER, isTestPath, looksLikeTestContent, bashTouchesTests } = await import(
  pathToFileURL(path.join(AGENT_ROOT, TEST_CONTENT_MARKER)).href,
);

describe("isTestPath", () => {
  it("recognises the common test directory layouts", () => {
    const paths = [
      "tests/foo.ts",
      "test/foo.py",
      "__tests__/foo.tsx",
      "spec/foo.rb",
      "specs/foo.rb",
      "src/tests/foo.js",
      "./tests/",
    ];
    for (const p of paths) {
      assert.equal(isTestPath(p), true, `${p} should be a test path`);
    }
  });

  it("recognises a bare test directory name", () => {
    // A bare test directory name is still a test path: the role guard relies
    // on this to block `ls tests`. Bare-word suppression for prose lives in
    // the two guard helpers (isPathShaped), not here.
    for (const p of ["test", "tests", "spec", "specs"]) {
      assert.equal(isTestPath(p), true, `${p} should be a test path`);
    }
  });

  it("recognises test file naming conventions", () => {
    const paths = [
      "src/foo.test.ts",
      "src/foo.spec.tsx",
      "src/foo_test.go",
      "src/test_foo.py",
      "src/spec_helper.rb",
    ];
    for (const p of paths) {
      assert.equal(isTestPath(p), true, `${p} should be a test path`);
    }
  });

  it("recognises flat class-file layouts for JVM, .NET, PHP and Scala", () => {
    const paths = [
      "src/FooTest.java",
      "src/FooTest.kt",
      "src/FooTest.kts",
      "src/FooSpec.scala",
      "src/FooSpec.groovy",
      "src/FooTests.cs",
      "src/FooTests.fs",
      "src/FooTest.vb",
      "src/FooIT.php",
    ];
    for (const p of paths) {
      assert.equal(isTestPath(p), true, `${p} should be a test path`);
    }
  });

  it("recognises conftest and feature files", () => {
    const paths = ["conftest.py", "src/conftest.py", "login.feature", "features/login.feature"];
    for (const p of paths) {
      assert.equal(isTestPath(p), true, `${p} should be a test path`);
    }
  });

  it("rejects ordinary source paths", () => {
    const paths = [
      "src/main.ts",
      "src/index.js",
      "lib/util.py",
      "README.md",
      "src/app/controller.rb",
      "src/foo.java",
    ];
    for (const p of paths) {
      assert.equal(isTestPath(p), false, `${p} should not be a test path`);
    }
  });

  it("rejects paths that merely contain the test letters", () => {
    const paths = [
      "src/latest.ts",
      "src/contest.ts",
      "src/protest.py",
      "src/specification.md",
      "src/manifest.json",
      "src/attested.rb",
    ];
    for (const p of paths) {
      assert.equal(isTestPath(p), false, `${p} should not be a test path`);
    }
  });

  it("rejects flat-extension names where Test/IT is only an inner substring", () => {
    // These are ordinary classes whose names happen to contain "test" or "it":
    //   Contest.java, Unit.kt, Audit.cs, Orbit.php, Credit.cs.
    // The flat class-file rule is meant for names that *end* in the test
    // keyword (FooTest.java), not for any name that contains it.
    const paths = [
      "src/contest.java",
      "src/Contest.java",
      "src/unit.kt",
      "src/Unit.java",
      "src/audit.cs",
      "src/credit.cs",
      "src/orbit.php",
      "src/edit.scala",
    ];
    for (const p of paths) {
      assert.equal(isTestPath(p), false, `${p} should not be a test path`);
    }
  });

  it("rejects a bare standalone non-test word", () => {
    for (const p of ["manifest", "readme", "foo", "util"]) {
      assert.equal(isTestPath(p), false, `${p} should not be a test path`);
    }
  });

  it("handles empty and non-string input without throwing", () => {
    for (const v of ["", "   ", null, undefined, 0, false, {}]) {
      assert.equal(isTestPath(v), false, `${JSON.stringify(v)} should not be a test path`);
    }
  });

  it("trims whitespace and strips a leading @", () => {
    assert.equal(isTestPath("  tests/foo.ts  "), true);
    assert.equal(isTestPath("@tests/foo.ts"), true);
    assert.equal(isTestPath("@src/main.ts"), false);
  });
});

describe("looksLikeTestContent", () => {
  it("returns a reason for test source code", () => {
    const samples = [
      "describe('add', () => { it('works', () => expect(add(1, 2)).toBe(3)); });",
      "def test_add():\n    assert add(1, 2) == 3",
      "func TestAdd(t *testing.T) {\n\tt.Fatalf(\"no\")\n}",
      "#[test]\nfn adds() {}",
      "@Test\nvoid works() {}",
      "assertThat(add(1, 2)).isEqualTo(3)",
      "import pytest",
      "require('node:test')",
      "beforeEach(() => {})",
      "EXPECT_EQ(1, 2)",
    ];
    for (const s of samples) {
      const reason = looksLikeTestContent(s);
      assert.ok(reason, `expected a reason for: ${s}`);
      assert.match(reason, /test source code/i);
    }
  });

  it("returns a reason naming the path when it references a test path", () => {
    const reason = looksLikeTestContent("Read src/calc.test.ts and make it pass");
    assert.ok(reason);
    assert.match(reason, /test path/i);
    assert.match(reason, /src\/calc\.test\.ts/);

    assert.ok(looksLikeTestContent("check tests/unit/calc.ts"));
    assert.ok(looksLikeTestContent("delete __tests__/legacy.js"));
  });

  it("returns a reason for a numeric count of failing items", () => {
    for (const s of ["2 failed", "3 failures", "1 error", "10 failing"]) {
      assert.ok(looksLikeTestContent(s), `expected a reason for: ${s}`);
    }
  });

  it("returns a reason for framework summary lines", () => {
    const samples = [
      "Tests: 2 failed, 3 passed",
      "Test Suites: 1 failed, 2 passed",
      "Test Files 1 failed",
      "Tests 3 passed",
      "Ran 5 tests",
      "5 tests completed",
      "Failures: 2",
      "test result: FAILED. 2 passed; 1 failed",
      "Passed! - Failed: 0, Passed: 5",
    ];
    for (const s of samples) {
      assert.ok(looksLikeTestContent(s), `expected a reason for: ${s}`);
    }
  });

  it("returns a reason for raw runner output", () => {
    const samples = [
      "\u2714 add(1, 2) returns 3",
      "\u2717 rejects a string operand",
      "AssertionError: expected 3 to equal 4",
      "Expected: 3",
      "Received: 4",
      "not ok 1 - does the thing",
      "ok 1 - works",
      "--- FAIL: TestParse",
      "PASSED",
      "FAILED",
    ];
    for (const s of samples) {
      assert.ok(looksLikeTestContent(s), `expected a reason for: ${s}`);
    }
  });

  it("returns null for a clean implementation task", () => {
    const samples = [
      "Create src/calc.js exporting add(a, b) that returns a + b.",
      "Update the README to document the new --json flag.",
      "Refactor src/parser.ts to extract a tokenizer module.",
      "Fix the off-by-one error in src/pagination.js.",
    ];
    for (const s of samples) {
      assert.equal(looksLikeTestContent(s), null, `expected null for: ${s}`);
    }
  });

  it("returns null for prose that merely mentions the concept", () => {
    const samples = [
      "The tests will be written separately, do not worry about them.",
      "the word test appears here",
      "We should add coverage later once the API settles.",
      "Do not modify the spec document without review.",
    ];
    for (const s of samples) {
      assert.equal(looksLikeTestContent(s), null, `expected null for: ${s}`);
    }
  });

  it("returns null for empty input", () => {
    assert.equal(looksLikeTestContent(""), null);
    assert.equal(looksLikeTestContent("   \n  "), null);
  });

  // --- Required behaviour that the current source does not meet. ---
  // These are intentionally not weakened; failures are reported as findings.

  it("returns a reason for a failure summary that counts failing tests", () => {
    for (const s of ["2 tests failed", "10 tests failing", "the test-writer says 2 tests failed; make them pass"]) {
      assert.ok(looksLikeTestContent(s), `expected a reason for: ${s}`);
    }
  });

  it("returns null for a task that names an ordinary class with a test-like substring", () => {
    assert.equal(looksLikeTestContent("Refactor src/contest.java to extract a helper"), null);
    assert.equal(looksLikeTestContent("Bump the version in src/unit.kt"), null);
  });
});

describe("bashTouchesTests", () => {
  it("returns true for shell access to a test path", () => {
    const commands = [
      "cat src/calc.test.ts",
      "rm src/foo_test.py",
      "ls tests/unit",
      "find . -name '*.test.ts'",
      "grep -rn foo src/__tests__/",
    ];
    for (const c of commands) {
      assert.equal(bashTouchesTests(c), true, `expected true for: ${c}`);
    }
  });

  it("returns true for removing or copying a test directory", () => {
    const commands = [
      "rm -rf tests/",
      "cp -r tests/ /tmp/backup",
      "mv tests/ /tmp/old",
      "rm -rf ./spec/",
    ];
    for (const c of commands) {
      assert.equal(bashTouchesTests(c), true, `expected true for: ${c}`);
    }
  });

  it("returns false for a standalone singular or plural word used as an argument", () => {
    // Regression: the bare words test/tests/spec/specs in a command used to
    // block legitimate builder shell work.
    const commands = [
      "echo tests",
      "echo test",
      "git commit -m 'add a test'",
      "git commit -m 'add tests for the parser'",
      "grep -rn tests src/",
      "bash -c 'echo tests'",
    ];
    for (const c of commands) {
      assert.equal(bashTouchesTests(c), false, `expected false for: ${c}`);
    }
  });

  it("returns false for unrelated commands", () => {
    const commands = [
      "ls src/",
      "rm -rf build/",
      "cat src/main.ts",
      "git status",
      "nix build",
      "echo 'all tests pass'",
      "cat src/contest.ts",
    ];
    for (const c of commands) {
      assert.equal(bashTouchesTests(c), false, `expected false for: ${c}`);
    }
  });

  it("returns false for test-runner invocations", () => {
    const commands = [
      "npm test",
      "npm run test",
      "pnpm test",
      "yarn test",
      "bun test",
      "pytest -q",
      "python -m pytest",
      "python -m pytest tests/integration/",
      "python3.12 -m unittest",
      "cargo test",
      "go test ./...",
      "node --test",
      "jest",
      "npx vitest run",
      "mocha",
      "bundle exec rspec",
      "dotnet test",
      "mvn test",
      "gradle test",
      "phpunit",
      "make test",
      "ctest",
    ];
    for (const c of commands) {
      assert.equal(bashTouchesTests(c), false, `runner should be allowed: ${c}`);
    }
  });

  it("returns false for an empty command", () => {
    assert.equal(bashTouchesTests(""), false);
    assert.equal(bashTouchesTests("   "), false);
  });

  // --- Required behaviour that the current source does not meet. ---

  it("returns false for an ordinary command touching a test-like class name", () => {
    assert.equal(bashTouchesTests("cat src/contest.java"), false);
  });
});

describe("RUNNER", () => {
  it("matches common test-runner invocations", () => {
    for (const c of ["npm test", "pnpm run test", "pytest", "go test ./...", "node --test", "cargo test"]) {
      assert.equal(RUNNER.test(c), true, `expected RUNNER to match: ${c}`);
    }
  });

  it("does not match an unrelated word that contains test letters", () => {
    assert.equal(RUNNER.test("contest the decision"), false);
    assert.equal(RUNNER.test("latest build"), false);
  });
});
