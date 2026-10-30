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

// An instruction to go read test code: a read verb followed by a pointer to the
// verification area on the same line.
const READ_VERB = /\b(read|open|cat|show|paste|look at|check|inspect|review)\b/gi;
const TEST_REFERENCE = /\b(test file|test suite|test case|test source|test code|tests\/|\.test\.|\.spec\.)/i;

/** How far after a verb a pointer to the verification area still counts. */
const REFERENCE_WINDOW = 60;

/** Characters inspected before a read verb when looking for a prohibition. */
const PROHIBITION_LOOKBEHIND = 40;

/** A prohibition that reaches the verb inside the same clause, with no sentence break. */
const PROHIBITION = /\b(?:do not|don't|dont|never|must not|should not|avoid|without|not)\b[^.;:\n]*$/i;

/**
 * True when the text tells an agent to go and read test code.
 *
 * A prohibition is not an instruction: "do not read the suite here" names a
 * location in order to forbid it, and refusing that wording would push the
 * author towards a vaguer constraint. Only the verb's own clause is consulted,
 * so a later sentence that really does instruct is still caught.
 */
function asksToReadTests(s: string): boolean {
  for (const verb of s.matchAll(READ_VERB)) {
    const at = verb.index ?? 0;
    const verbEnd = at + verb[0].length;
    const lineEnd = s.indexOf("\n", verbEnd);
    const stop = Math.min(lineEnd === -1 ? s.length : lineEnd, verbEnd + REFERENCE_WINDOW);
    if (!TEST_REFERENCE.test(s.slice(verbEnd, stop))) continue;

    const before = s.slice(Math.max(0, at - PROHIBITION_LOOKBEHIND), at);
    if (!PROHIBITION.test(before)) return true;
  }
  return false;
}

/**
 * Heuristic: does this text hand test source, a test name, or test output to an
 * agent that must not see tests? Returns a short reason, or null when clean.
 *
 * Two dimensions are kept apart on purpose, because they are different risks:
 *
 *   - content (this function): test source, a case identifier, runner output.
 *     Text that carries any of them is a leak and must be refused.
 *   - location (`isTestPath`): whether a path names test code. Only tool access
 *     to that path is a problem, which is what the role guard blocks. Naming a
 *     location in prose leaks nothing, and a prohibition that names it is
 *     stricter rather than looser, so it must not be refused for saying so.
 *
 * So this function does not consult `isTestPath`. Do not re-add a bare path
 * scan here: it pushes callers towards vaguer instructions.
 */
export function looksLikeTestContent(text: string): string | null {
  const s = String(text ?? "");
  if (!s.trim()) return null;

  if (TEST_CODE.test(s)) return "it contains test source code";
  if (TEST_OUTPUT.test(s)) return "it contains test-runner output";
  if (asksToReadTests(s)) return "it asks the agent to read test code";

  return null;
}
