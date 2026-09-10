/**
 * Shared test-detection helpers for the agent extensions.
 *
 * Not an extension: pi only auto-discovers `extensions/*.ts` and
 * `extensions/--/index.ts`, so a file under `extensions/lib/` is inert and is
 * only loaded by the extensions that import it.
 */

/** Test-runner invocations, which are allowed (the test may be run). */
export const RUNNER =
  /\b(npm|pnpm|yarn|bun)\s+(run\s+)?test\b|\bpytest\b|python[0-9.]*\s+-m\s+(pytest|unittest)|\bcargo\s+test\b|\bgo\s+test\b|\bnode\s+--test\b|\bjest\b|\bvitest\b|\bmocha\b|\brspec\b|bundle\s+exec\s+rspec|\bdotnet\s+test\b|\bmvn\s+test\b|\bgradle\w*\s+test\b|\bphpunit\b|\bmake\s+test\b|\bctest\b/i;

const TEST_PATTERNS: RegExp[] = [
  /(^|\/)(test|tests|__tests__|spec|specs)\//i,
  /(^|\/)(test|tests|__tests__|spec|specs)$/i,
  /(^|\/)(test_|spec_)[^/]*$/i,
  /(^|\/)[^/]*\.(test|spec)\.[a-z0-9]+$/i,
  /(^|\/)[^/]*_test\.[a-z0-9]+$/i,
  /(^|\/)conftest\.py$/i,
  /(^|\/)__mocks__\//i,
  /\.feature$/i,
  // Flat class-file layouts: FooTest.java, FooTests.cs, FooSpec.scala, FooIT.php.
  // The suffix is case-sensitive and must be a whole trailing unit, so ordinary
  // words that merely end in the letters (latest, unit, audit, credit, orbit,
  // edit) are not restricted. `IT` additionally needs a non-uppercase boundary
  // so it is not the tail of an all-caps word. The extension stays
  // case-insensitive; explicit classes avoid the `i` flag that would make the
  // suffix case-insensitive too.
  /(^|\/)[^/]*(?:Tests|Test|Spec|(?<![A-Z])IT)\.(?:[jJ][aA][vV][aA]|[kK][tT][sS]?|[sS][cC][aA][lL][aA]|[gG][rR][oO][oO][vV][yY]|[cC][sS]|[fF][sS]|[vV][bB]|[pP][hH][pP])$/,
];

/** A token is path-shaped when it names a file/dir, not a bare word. */
function isPathShaped(token: string): boolean {
  return token.includes("/") || /\.[a-z0-9]{1,6}$/i.test(token);
}

/** True when a path/glob names test code. */
export function isTestPath(value: unknown): boolean {
  const s = String(value ?? "").replace(/^@/, "").trim();
  if (!s) return false;
  return TEST_PATTERNS.some((re) => re.test(s));
}

/** True when a shell command reaches into test paths (runners excepted). */
export function bashTouchesTests(command: string): boolean {
  const cmd = String(command ?? "");
  if (!cmd) return false;
  if (RUNNER.test(cmd)) return false;
  const tokens = cmd.match(/[^\s;|&()<>'"]+/g) ?? [];
  // Only path-shaped tokens count: a bare word like "tests" in prose (or in a
  // commit message) must not trip the guard.
  return tokens.some((t) => isPathShaped(t) && isTestPath(t));
}

// Test source in any common language.
const TEST_CODE =
  /(^|\n)\s*(describe|it|test|expect)\s*\(|\brequire\(\s*['"]node:test|from\s+['"]node:test|\bassert\s*\(|\bassert\.\w|\bdef\s+test_|\bclass\s+Test[A-Za-z0-9_]*\s*\(|\bimport\s+pytest\b|@pytest\.|\bunittest\.|\bfunc\s+Test[A-Z]\w*\s*\(|\bt\.Run\(|#\[test\]|#\[tokio::test\]|@Test\b|\bassertThat\s*\(|\bEXPECT_[A-Z]|\bASSERT_[A-Z]|\.should\.|\bbeforeEach\s*\(|\bafterEach\s*\(/;

// Test-runner output.
const TEST_OUTPUT =
  /(^|\n)\s*[✔✓✗✘]|\bAssertionError\b|\bExpected:\s|\bReceived:\s|\bnot ok\b|(^|\n)\s*ok\s+\d+|\b\d+\s+(?:passed|failed|failing|passing|[Ff]ailures?|[Ee]rrors?|broken)\b|\b\d+\s+tests?\s+(?:failed|failing)\b|Test Suites?:\s|\bTests?:\s+\d|\bPASSED\b|\bFAILED\b|\bTests?\s+run:\s*\d|[Ff]ailures?:\s*\d|[Ee]rrors?:\s*\d|\btest result:\s*(?:ok|FAILED)\b|\b(?:Passed|Failed)!\s*[-–]|\bTest Files\b|(^|\n)\s*---?\s*FAIL\b|\bRan\s+\d+\s+tests?\b|\b\d+\s+tests?\s+(?:complete|completed)\b/;

// An instruction to go read test code.
const TEST_READ_INSTRUCTION =
  /\b(read|open|cat|show|paste|look at|check|inspect|review)\b[^\n]{0,60}?\b(test file|test suite|test case|test source|test code|tests\/|\.test\.|\.spec\.)/i;

/**
 * Heuristic: does this text hand test code, a test path, or test output to an
 * agent that must not see tests? Returns a short reason, or null when clean.
 */
export function looksLikeTestContent(text: string): string | null {
  const s = String(text ?? "");
  if (!s.trim()) return null;

  if (TEST_CODE.test(s)) return "it contains test source code";

  // Only path-shaped tokens: a bare word like "tests" in prose must not trip it.
  const tokens = s.match(/[^\s;|&()<>'"`]+/g) ?? [];
  const pathHit = tokens.find((t) => isPathShaped(t) && isTestPath(t));
  if (pathHit) return `it references a test path ("${pathHit}")`;

  if (TEST_OUTPUT.test(s)) return "it contains test-runner output";
  if (TEST_READ_INSTRUCTION.test(s)) return "it asks the agent to read test code";

  return null;
}
