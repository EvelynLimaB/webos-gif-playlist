# Contributing

Screensaver Playlist modifies a privileged system entry point on rooted TVs. Contributions are welcome, but safety, rollback, and compatibility take priority over feature breadth.

## Before opening a change

1. Read `docs/ARCHITECTURE.md` and `docs/TESTING.md`.
2. Keep the working v0.1.x GIF path and data migration intact unless a documented migration is included.
3. Preserve POSIX/BusyBox shell compatibility and Chromium 53-compatible ES5 JavaScript.
4. Do not add automatic activation during installation.
5. Do not overwrite LG system files; the project uses reversible bind mounts only.
6. Do not unmount or modify overrides owned by another package.

## Development setup

```bash
npm install -g @webos-tools/cli@3.2.5
make check
make package
make audit-package
```

`make check` runs syntax checks, isolated manager tests, upload-helper tests, and a UI contract test. Install `shellcheck` locally for the complete shell pass.

## Code conventions

- Shell: POSIX `sh`, four-space indentation, quoted expansions, explicit cleanup, and actionable `ERROR:` messages on stderr. Keep manager responsibilities in the existing `assets/lib/` module boundaries.
- JavaScript: ES5-style constructors/prototypes; no classes, arrow functions, async/await, optional chaining, or APIs newer than Chromium 53.
- CSS: conservative Flexbox; no Grid, custom properties, or `gap`.
- QML: QtQuick 2.4 syntax only unless physical testing proves a broader baseline.
- User-facing state returned by `manager.sh` uses stable `key=value` lines. Playlist rows use tab-separated fields.
- Persistent paths, app ID, startup-hook name, and command names are compatibility interfaces. Document and migrate changes rather than silently renaming them.

## Pull requests

A focused PR should include:

- the problem and safety impact;
- automated tests for success and failure paths;
- exact TV/firmware results when hardware behavior is involved;
- rollback instructions for privileged changes;
- documentation updates for new commands, settings, formats, or persistent files.

Keep hardware-dependent PRs in draft until the relevant physical checklist passes. CI success does not prove decoder, GPU, boot-order, or long-running stability on a TV.

## Commit and review guidance

Use descriptive commits such as `fix: refuse foreign screensaver mounts` or `test: cover malformed PNG headers`. Reviewers should prioritize data loss, system-file safety, command injection, concurrent mutation, migration, rollback, and old-engine compatibility before style concerns.
