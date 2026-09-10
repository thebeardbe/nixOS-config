import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { matchesKey, Key } from "@earendil-works/pi-tui";

/**
 * Masked-input tools for secrets.
 *
 * Design rule: the secret is captured masked and is not returned to the model.
 * It is either piped into sudo, injected as an environment variable of a child
 * process, or handed to ssh-add through SSH_ASKPASS. Only command output (with
 * the secret scrubbed) comes back. The one exception is `ask_secret`, the
 * explicit last-resort prompt whose whole purpose is to return the raw value to
 * the model (it warns the user that the value lands in the session log).
 */

function scrub(text: string, secret: string): string {
  if (!text) return "";
  // Never let a captured secret leak back into the transcript.
  return secret ? text.split(secret).join("[REDACTED]") : text;
}

function shellQuote(s: string): string {
  return `'${String(s).replace(/'/g, `'\\''`)}'`;
}

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

  // Wrap to the terminal width; over-wide lines crash the TUI renderer.
  private wrap(text: string, width: number): string[] {
    const lines: string[] = [];
    for (const para of text.split("\n")) {
      let rest = para;
      while (rest.length > width) {
        let cut = rest.lastIndexOf(" ", width);
        if (cut <= 0) cut = width;
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

export default function (pi: ExtensionAPI) {
  // Shared masked prompt. Returns null when the user cancels.
  async function promptSecret(ctx: ExtensionContext, prompt: string): Promise<string | null> {
    if (ctx.hasUI === false) return null;
    return await ctx.ui.custom<string | null>((tui, _theme, _kb, done) =>
      new PasswordInput(prompt, undefined, () => tui.requestRender(), done),
    );
  }

  pi.registerTool({
    name: "ask_secret",
    label: "Ask Secret",
    description:
      "Prompt for a secret value with masked input and return it. LAST RESORT: " +
      "the value becomes visible to the model and is stored in the session log. " +
      "Prefer run_with_secret, ssh_add, or run_with_sudo, which never return the secret.",
    promptSnippet: "Prompt for a secret value (masked); prefer the run_* secret tools",
    promptGuidelines: [
      "Prefer run_with_secret, ssh_add, or run_with_sudo over ask_secret; they never expose the secret to the model or the session log.",
      "Use ask_secret only when the raw secret value itself is required, and warn the user that it will be recorded in the session.",
    ],
    parameters: Type.Object({
      prompt: Type.String({ description: "What to ask for, e.g. 'API token for example.com'" }),
    }),
    async execute(_id, params, _signal, _onUpdate, ctx) {
      const value = await promptSecret(ctx, params.prompt);
      if (value === null) {
        return {
          content: [{ type: "text", text: "User cancelled the secret prompt." }],
          isError: true,
          details: {},
        };
      }
      return {
        content: [
          {
            type: "text",
            text: `Secret captured (recorded in this session log). Prefer a run_* secret tool next time to avoid that.\n${value}`,
          },
        ],
        details: { captured: true },
      };
    },
  });

  pi.registerTool({
    name: "run_with_secret",
    label: "Run with Secret",
    description:
      "Run a shell command with a secret injected as an environment variable. " +
      "The secret is captured with a masked prompt, passed only to the child " +
      "process environment, scrubbed from all output, and never returned to you.",
    promptSnippet: "Run a command with a secret provided via a masked prompt (secret never returned)",
    promptGuidelines: [
      "Use run_with_secret when a single command needs a credential that must not appear in the transcript; name the env var the command expects.",
      "Never put the secret value in the command string yourself; run_with_secret only accepts the command, not the secret.",
    ],
    parameters: Type.Object({
      command: Type.String({
        description: "Command to run. It reads the secret from the environment variable named by envName.",
      }),
      envName: Type.Optional(
        Type.String({ description: "Environment variable to inject the secret into (default PI_SECRET)." }),
      ),
      label: Type.Optional(
        Type.String({ description: "Human label used in the prompt, e.g. 'GitHub token'." }),
      ),
      cwd: Type.Optional(Type.String({ description: "Working directory (defaults to current)." })),
      timeout: Type.Optional(Type.Number({ description: "Timeout in seconds (default 120)." })),
    }),
    async execute(_id, params, _signal, _onUpdate, ctx) {
      const envName = params.envName ?? "PI_SECRET";
      const secret = await promptSecret(
        ctx,
        `${params.label ?? "secret"} required for: ${params.command} (env: ${envName})`,
      );
      if (!secret) {
        return {
          content: [{ type: "text", text: "No secret provided; command cancelled." }],
          isError: true,
          details: {},
        };
      }

      const { execSync } = await import("node:child_process");
      try {
        const output = execSync(params.command, {
          cwd: params.cwd ?? ctx.cwd,
          timeout: (params.timeout ?? 120) * 1000,
          maxBuffer: 10 * 1024 * 1024,
          env: { ...process.env, [envName]: secret },
        });
        return {
          content: [{ type: "text", text: scrub(output.toString(), secret) || "(no output)" }],
          details: { exitCode: 0 },
        };
      } catch (err: unknown) {
        const e = err as { stdout?: Buffer; stderr?: Buffer; message?: string; status?: number };
        const text = [e.stdout?.toString() ?? "", e.stderr?.toString() ?? e.message ?? ""]
          .map((t) => scrub(t, secret))
          .join("\n")
          .trim();
        return {
          content: [{ type: "text", text: text || "command failed (output withheld)" }],
          isError: true,
          details: { exitCode: e.status ?? 1 },
        };
      }
    },
  });

  pi.registerTool({
    name: "ssh_add",
    label: "SSH Add Key",
    description:
      "Load an SSH private key into ssh-agent by prompting for its passphrase with " +
      "masked input. The passphrase is used via SSH_ASKPASS and is never returned to you.",
    promptSnippet: "Add an SSH key to ssh-agent using a masked passphrase prompt",
    promptGuidelines: [
      "Use ssh_add to unlock a passphrase-protected SSH key instead of asking the user to paste the passphrase into chat.",
      "After ssh_add, verify with ssh-add -l before running git push or ssh.",
    ],
    parameters: Type.Object({
      key: Type.Optional(
        Type.String({ description: "Path to the private key (default ~/.ssh/id_ed25519)." }),
      ),
    }),
    async execute(_id, params, _signal, _onUpdate, ctx) {
      const os = await import("node:os");
      const path = await import("node:path");
      const fs = await import("node:fs");

      const keyArg = (params.key ?? "~/.ssh/id_ed25519").replace(/^~(?=$|\/)/, os.homedir());
      const keyPath = path.resolve(keyArg);
      if (!fs.existsSync(keyPath)) {
        return {
          content: [{ type: "text", text: `No such key: ${keyPath}` }],
          isError: true,
          details: {},
        };
      }

      const passphrase = await promptSecret(ctx, `Passphrase for ${keyPath}`);
      if (!passphrase) {
        return {
          content: [{ type: "text", text: "No passphrase provided; ssh-add cancelled." }],
          isError: true,
          details: {},
        };
      }

      const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "pi-askpass-"));
      const askpass = path.join(tmpDir, "askpass.sh");
      const { execSync } = await import("node:child_process");
      try {
        fs.writeFileSync(askpass, `#!/bin/sh\nprintf '%s\\n' ${shellQuote(passphrase)}\n`);
        fs.chmodSync(askpass, 0o700);

        const hasSetsid = (() => {
          try {
            execSync("command -v setsid", { stdio: "ignore" });
            return true;
          } catch {
            return false;
          }
        })();

        const env = {
          ...process.env,
          SSH_ASKPASS: askpass,
          SSH_ASKPASS_REQUIRE: "force",
          DISPLAY: process.env.DISPLAY ?? "pi:none",
        };
        const prefix = hasSetsid ? "setsid -w " : "";
        const output = execSync(`${prefix}ssh-add ${shellQuote(keyPath)} < /dev/null 2>&1`, {
          env,
          timeout: 60 * 1000,
          maxBuffer: 1024 * 1024,
        });

        let loaded = "";
        try {
          loaded = execSync("ssh-add -l 2>&1", { env }).toString().trim();
        } catch {
          loaded = "(ssh-add -l unavailable)";
        }

        return {
          content: [
            {
              type: "text",
              text: `${scrub(output.toString(), passphrase).trim() || "ssh-add ok"}\n${scrub(loaded, passphrase)}`,
            },
          ],
          details: { exitCode: 0 },
        };
      } catch (err: unknown) {
        const e = err as { stdout?: Buffer; stderr?: Buffer; message?: string; status?: number };
        const text = [e.stdout?.toString() ?? "", e.stderr?.toString() ?? e.message ?? ""]
          .map((t) => scrub(t, passphrase))
          .join("\n")
          .trim();
        return {
          content: [{ type: "text", text: text || "ssh-add failed (output withheld)" }],
          isError: true,
          details: { exitCode: e.status ?? 1 },
        };
      } finally {
        // Wipe the askpass helper and its directory.
        try {
          fs.writeFileSync(askpass, "#!/bin/sh\nexit 1\n");
          fs.unlinkSync(askpass);
        } catch {
          /* ignore */
        }
        try {
          fs.rmSync(tmpDir, { recursive: true, force: true });
        } catch {
          /* ignore */
        }
      }
    },
  });

  pi.registerTool({
    name: "run_with_sudo_secret",
    label: "Run with Sudo (Secret)",
    description:
      "Alias of run_with_sudo for environments where the ask-user extension is not loaded: " +
      "run a command as root with a masked password prompt. Prefer run_with_sudo when available.",
    promptSnippet: "Run a command as root with a masked password prompt",
    promptGuidelines: [
      "Prefer the dedicated run_with_sudo tool; use run_with_sudo_secret only if run_with_sudo is not in the tool list.",
    ],
    parameters: Type.Object({
      command: Type.String({ description: "Full command to run as root." }),
      cwd: Type.Optional(Type.String({ description: "Working directory (defaults to current)." })),
      timeout: Type.Optional(Type.Number({ description: "Timeout in seconds (default 120)." })),
    }),
    async execute(_id, params, _signal, _onUpdate, ctx) {
      const password = await promptSecret(ctx, `sudo password required for: ${params.command}`);
      if (!password) {
        return {
          content: [{ type: "text", text: "No password provided; command cancelled." }],
          isError: true,
          details: {},
        };
      }

      const fs = await import("node:fs");
      const os = await import("node:os");
      const path = await import("node:path");
      const { execSync } = await import("node:child_process");
      // mkdtemp gives a private 0700 dir with an unguessable name; a Date.now()
      // plus Math.random() filename could be predicted and raced.
      const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "pi-sudo-"));
      const tmpFile = path.join(tmpDir, "password");
      try {
        fs.writeFileSync(tmpFile, password + "\n");
        fs.chmodSync(tmpFile, 0o600);
        const output = execSync(`sudo -S < ${shellQuote(tmpFile)} ${params.command}`, {
          cwd: params.cwd ?? ctx.cwd,
          timeout: (params.timeout ?? 120) * 1000,
          maxBuffer: 10 * 1024 * 1024,
        });
        return {
          content: [{ type: "text", text: scrub(output.toString(), password) || "(no output)" }],
          details: { exitCode: 0 },
        };
      } catch (err: unknown) {
        const e = err as { stdout?: Buffer; stderr?: Buffer; message?: string; status?: number };
        const text = [e.stdout?.toString() ?? "", e.stderr?.toString() ?? e.message ?? ""]
          .map((t) => scrub(t, password))
          .join("\n")
          .trim();
        return {
          content: [{ type: "text", text: text || "sudo command failed (output withheld)" }],
          isError: true,
          details: { exitCode: e.status ?? 1 },
        };
      } finally {
        try {
          fs.writeFileSync(tmpFile, "0\n");
          fs.unlinkSync(tmpFile);
        } catch {
          /* ignore */
        }
        try {
          fs.rmSync(tmpDir, { recursive: true, force: true });
        } catch {
          /* ignore */
        }
      }
    },
  });
}
