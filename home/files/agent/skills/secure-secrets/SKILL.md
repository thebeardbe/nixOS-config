---
name: secure-secrets
description: Handle passwords, passphrases, tokens and sudo safely by prompting for them interactively instead of hardcoding, echoing or persisting them. Use whenever a task needs sudo, an SSH key passphrase, a git credential, or any credential value.
---

# Secure Secrets

The user deliberately keeps interactive password entry. **Always ask; never
hardcode, echo, or store.** Prefer the dedicated tools over putting secrets in
`bash` commands.

## Which tool for what

| Need | Tool | Notes |
|---|---|---|
| Run anything as root / sudo | `run_with_sudo` | Masked prompt, temp file chmod 600, wiped. Never `echo pw \| sudo -S`. |
| SSH key passphrase | `ssh_add` | Masked prompt; only success/failure is returned. Needs a running `ssh-agent`. |
| Secret needed by one command | `run_with_secret` | Injected as an env var into the child process; only output is returned. |
| Choice / confirmation (no secret) | `ask_user` | Plain interactive input. |
| Raw secret value must reach you | `ask_secret` | Last resort. Warn the user it will appear in the session log. |

If a tool above is missing from the tool list, fall back to `ask_user` only for
non-secret values, and tell the user which secret tool you need.

## Rules

1. **Prompt at the moment of use.** One prompt per credential, not upfront.
2. **Never put a secret in a command string.** No `echo '…' | sudo -S`, no
   `-p<pass>`, no inline `TOKEN=…` in a shell command that gets logged.
3. **Never write secrets to disk** except via the tools (which chmod 600 and
   wipe). Do not create scripts containing passphrases that outlive the tool.
4. **Never repeat a secret** in your reply, in a commit message, in a file, or
   in a summary. If output contains one, redact it.
5. **Prefer non-secret alternatives** when they exist and the user agrees:
   passwordless sudo for a specific command, an ssh-agent, a scoped deploy key.
   Suggest them, do not silently switch.
6. **Report leakage.** If you find a secret committed, logged, or in a command
   history, flag it and recommend rotating it.

## SSH passphrase flow

```
1. ssh_add(key="~/.ssh/id_ed25519")        # masked prompt handled by the tool
2. git push / git fetch                    # agent now holds the key
3. ssh-add -l                              # verify the key is loaded
```

Do not run `eval "$(ssh-agent -s)"` and then ask for the passphrase in chat.
`ssh_add` only loads the key into an already-running agent; it does not start
one, so a running `ssh-agent` is required. Verify the loaded key with
`ssh-add -l`.

## sudo flow

```
run_with_sudo(command="nixos-rebuild switch --flake .#host", cwd="/path/to/repo")
```

If the command fails, read stderr. Never retry by pasting the password into a
plain `bash` call.

## After an exposure

If a secret was ever placed in a `bash` argument, a file, or a session log:
say so immediately, name the location, and recommend rotation. Do not try to
quietly clean it up and move on.
