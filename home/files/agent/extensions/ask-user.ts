import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { matchesKey, Key } from "@earendil-works/pi-tui";

class PasswordInput {
  private value = "";
  private placeholder: string;
  private prompt: string;
  private done: (result: string | null) => void;
  private requestRender: () => void;

  constructor(
    prompt: string,
    placeholder: string | undefined,
    requestRender: () => void,
    done: (result: string | null) => void,
  ) {
    this.prompt = prompt;
    this.placeholder = placeholder ?? "";
    this.requestRender = requestRender;
    this.done = done;
  }

  handleInput(data: string) {
    if (matchesKey(data, Key.enter)) {
      this.done(this.value || this.placeholder || null);
    } else if (matchesKey(data, Key.escape)) {
      this.done(null);
    } else if (matchesKey(data, Key.backspace)) {
      this.value = this.value.slice(0, -1);
      this.requestRender();
    } else if (data.length === 1 && data.charCodeAt(0) >= 32) {
      this.value += data;
      this.requestRender();
    }
  }

  // Wrap text to fit the available width (never emit a line wider than
  // the terminal — over-wide lines crash the TUI renderer).
  private wrap(text: string, width: number): string[] {
    const lines: string[] = [];
    for (const para of text.split("\n")) {
      let rest = para;
      while (rest.length > width) {
        let cut = rest.lastIndexOf(" ", width);
        if (cut <= 0) cut = width; // single unbreakable token
        lines.push(rest.slice(0, cut).trimEnd());
        rest = rest.slice(cut).trimStart();
      }
      lines.push(rest);
    }
    return lines;
  }

  render(width: number): string[] {
    const display = "•".repeat(this.value.length) || this.placeholder;
    const promptLines = this.wrap(this.prompt, width - 1).map((l) => ` ${l}`);
    const valueLines = this.wrap(display, width - 1).map((l) => ` ${l}`);
    return [
      "─".repeat(width),
      ...promptLines,
      "",
      ...valueLines,
      "─".repeat(width),
      " enter: confirm  •  esc: cancel",
    ];
  }

  invalidate() {}
}

/** Never let the captured password leak back through captured command output. */
function scrub(text: string, secret: string): string {
  return secret ? text.split(secret).join("[REDACTED]") : text;
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "ask_user",
    label: "Ask User",
    description:
      "Ask the user for interactive input. Use for confirmations, choices, " +
      "or any value the user must type in. For sudo commands, use run_with_sudo instead.",
    promptSnippet: "Request interactive input from the user",
    promptGuidelines: [
      "Use ask_user when you need a choice, confirmation, or text input from the user.",
      "For running commands as root, use run_with_sudo instead of piping passwords through bash.",
    ],
    parameters: Type.Object({
      prompt: Type.String({
        description: "The prompt to show the user",
      }),
      default: Type.Optional(
        Type.String({
          description: "Optional default value if the user presses Enter",
        }),
      ),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const result = await ctx.ui.input(params.prompt, params.default);

      if (result === null || result === undefined) {
        return {
          content: [{ type: "text", text: "User cancelled the input prompt." }],
          isError: true,
          details: {},
        };
      }

      return {
        content: [{ type: "text", text: `User responded: ${result}` }],
        details: { response: result },
      };
    },
  });

  pi.registerTool({
    name: "run_with_sudo",
    label: "Run with Sudo",
    description:
      "Run a command as root. Asks for the sudo password via a masked prompt, " +
      "writes it to a secure temp file, pipes it to sudo, then wipes the file. " +
      "Use this instead of ask_user + manual echo-to-sudo in bash.",
    promptSnippet: "Execute a command with sudo privileges",
    promptGuidelines: [
      "Use run_with_sudo instead of piping passwords through bash with echo.",
      "This tool handles password capture and cleanup securely.",
      "Pass the full command including any arguments.",
    ],
    parameters: Type.Object({
      command: Type.String({
        description: "The full command to run as root (e.g., 'nixos-rebuild switch --flake .#theConstruct')",
      }),
      cwd: Type.Optional(
        Type.String({
          description: "Working directory to run the command in (defaults to current directory)",
        }),
      ),
      timeout: Type.Optional(
        Type.Number({
          description: "Timeout in seconds (optional)",
        }),
      ),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      // Step 1: Ask for password via masked custom UI
      const password = await ctx.ui.custom<string | null>((tui, _theme, _kb, done) => {
        return new PasswordInput(
          `sudo password required for: ${params.command}`,
          undefined,
          () => tui.requestRender(),
          done,
        );
      });

      if (!password) {
        return {
          content: [{ type: "text", text: "No password provided — command cancelled." }],
          isError: true,
          details: {},
        };
      }

      // Step 2: Write the password to a private temp dir (mkdtemp creates it
      // with mode 0700 and a cryptographically random name, so no other user
      // can guess or read the credential file).
      const fs = await import("node:fs");
      const os = await import("node:os");
      const path = await import("node:path");
      const { execSync } = await import("node:child_process");
      const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "pi-sudo-"));
      const tmpFile = path.join(tmpDir, "password");

      try {
        fs.writeFileSync(tmpFile, password + "\n", { mode: 0o600 });
        fs.chmodSync(tmpFile, 0o600);

        // Step 3: Run the command with sudo -S reading from the temp file
        const output = execSync(
          `sudo -S < '${tmpFile}' ${params.command}`,
          {
            cwd: params.cwd ?? process.cwd(),
            timeout: (params.timeout ?? 120) * 1000,
            maxBuffer: 10 * 1024 * 1024,
          },
        );

        // A command that reads the credential file (or echoes it) would put
        // the password in the captured output, so scrub before returning.
        return {
          content: [{ type: "text", text: scrub(output.toString(), password) }],
          details: { exitCode: 0 },
        };
      } catch (err: unknown) {
        const error = err as { stderr?: Buffer; stdout?: Buffer; message?: string; status?: number };
        const stderr = scrub(error.stderr?.toString() ?? "", password);
        const stdout = scrub(error.stdout?.toString() ?? "", password);
        const message = scrub(error.message ?? "Unknown error", password);

        return {
          content: [
            { type: "text", text: stdout },
            { type: "text", text: stderr || message },
          ],
          isError: true,
          details: { exitCode: error.status ?? 1 },
        };
      } finally {
        // Always wipe and remove the credential file and its private dir.
        try {
          fs.writeFileSync(tmpFile, "0".repeat(password.length) + "\n");
        } catch { /* already gone or unwritable; removal below still runs */ }
        try {
          fs.rmSync(tmpDir, { recursive: true, force: true });
        } catch { /* best effort: the dir is 0700 and holds no other data */ }
      }
    },
  });
}
