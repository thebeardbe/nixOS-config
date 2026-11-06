---
name: agent-notes
description: Look up the owner's private session notes before rediscovering verified findings about 3D printing, Klipper, Orca slicer profiles, USB headsets, PipeWire or ALSA audio, and to record a new finding. Use when a task touches that hardware, or anything the owner says was worked on before.
---

# Agent Notes

`~/Documents/agent-notes` is a private knowledge base of dated, verified findings
from past sessions. It exists so a later session does not pay the same cost twice.
Read it before acting, not after a first attempt fails.

## When to use

- 3D printing: printers, slicer profiles, Orca, Klipper, Moonraker, resonance
  measurement, calibration.
- USB headsets and audio: PipeWire, WirePlumber, ALSA, profiles and sinks.
- Anything the owner says was worked on before, or any device on this LAN whose
  quirks someone else already measured.

## Entry points

1. `README.md` at the repository root: the topic table and a condensed status.
2. `AGENTS.md` at the repository root: the policy for reading and writing notes.
3. `<topic>/README.md`: the topic index, naming which note covers what.
4. The note the index points at, read in full before starting work.

Do not rely on the index alone; it summarizes, the note holds the evidence. If no
index entry fits, search for the device or software name
(`rg -n -i '<term>' ~/Documents/agent-notes`) and read the note it lands in.

## Layout

- `<topic>/README.md`: session id, start date, a table of files and their
  contents, and a `## One-line status` paragraph.
- `<topic>/*.md`: the long-form notes. They are organized as dated sections, for
  example `(2026-10-23)`, each saying what was proven and how it was verified:
  the command, the measurement, the log line, or "user reported".
- A note with a single overall state opens with `Status: **...**` under its H1.
- Subfolders are assets (preset packs, photos) and carry their own README.

## Writing a finding

The repository's `AGENTS.md` is authoritative; the essentials:

- **Add** your finding to the note that covers it, with the date and how you
  verified it. Label anything unverified as such.
- **Correct** what you proved wrong under a heading containing "Correction", and
  name the old belief so the change is readable.
- **Update** the topic index's `## One-line status` when a status changes, plus
  the date line if the session dates moved.
- **Say why** in the note when you change another agent's finding.
- **Never delete history.** Append, and mark superseded text as superseded
  instead of removing it. Do not restructure or reword notes as a side effect.

## Links and privacy

Use relative markdown links, for example
`[note](audio/jbl-quantum-xrun.md)`. They work in Obsidian and in a plain reader.
Do not add `[[wikilinks]]`.

The repository is private and stays local. Treat it as a file on disk that can be
copied: no credentials, tokens, keys or passwords in notes, even in a private
repository. Do not publish it or add a remote without the owner asking.

## Stale summaries

Some notes contain a prose summary written before their own final tables. When
they disagree, a later dated section that reports a verified result wins over an
earlier summary. Follow the dated evidence, and mention the mismatch if it affects
the task.
