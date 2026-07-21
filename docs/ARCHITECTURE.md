# Architecture

## Components

`index.html`, `css/app.css`, and `js/` form a Chromium 53-compatible TV interface. `js/webos.js` is the browser-to-platform adapter. It invokes `assets/manager.sh` through the Homebrew Channel service.

The manager is split into modules:

- `assets/lib/core.sh`: storage, generated QML, mount ownership, activation, and boot behavior.
- `assets/lib/media.sh`: URL validation, media signatures, dimensions, limits, and single-item imports.
- `assets/lib/batch.sh`: whole-folder and URL-list coordination.
- `assets/lib/commands.sh`: playlist, settings, status, preflight, disable, and reset commands.

`tools/send-media.sh` is an optional PC-side SSH helper. The TV-side manager remains the stable public interface.

## Persistent layout

```text
/var/lib/webosbrew/gif-playlist/
├── items/
├── playlist.txt
├── settings.conf
├── screensaver-runtime.qml
├── active-target
└── .manager-lock/
```

The historical data directory and startup-hook names remain compatibility interfaces for upgrades.

## Manager commands

Read operations:

- `preflight`
- `status`
- `list`

Mutating operations:

- `init`
- `add BASE64_URL`
- `import FILE`
- `import-dir DIRECTORY`
- `remove ID`
- `move ID up|down`
- `set mode|duration|fit|filter VALUE`
- `generate`, `apply`, `enable`, `boot`
- `disable`, `uninstall`, `reset`

`import-dir` scans one directory level. Supported image files are sent through the normal `import` command. Text files are parsed as URL lists and sent through `add`. Each child operation acquires its own manager lock and commits independently. The batch coordinator continues after item-level failures and prints a final `batch_*` summary.

Machine-readable status uses `key=value`. Playlist rows use `id<TAB>bytes<TAB>format<TAB>dimensions`.

## Single-item import pipeline

1. Acquire the atomic manager lock.
2. Copy or download into an app-owned temporary file.
3. Enforce item-count, per-file, and total-storage limits.
4. Detect the format from file bytes.
5. Parse and validate logical dimensions.
6. Move the unchanged source into `items/`.
7. Update the playlist and generated QML.
8. Roll back the playlist and stored file when QML generation fails.

The firmware decoder remains the final authority. A structurally valid WebP or APNG can still fail at playback when the required firmware plugin is absent.

## QML and bind mounts

The generated QML uses a `WebOSWindow` screensaver and Qt Quick `AnimatedImage`. It rotates local `file://` sources and advances after decoder failures.

The manager bind-mounts the generated runtime file over a detected LG screensaver entry point. It does not overwrite the original system QML. Runtime updates preserve the inode used by an active bind mount.

Before applying or disabling, the manager verifies mount ownership through mount-source information and source/target file identity. A mount that cannot be identified as this app's own runtime is treated as foreign and left untouched.

## Boot behavior

`apply` activates temporarily. `enable` also creates an executable Homebrew startup hook. Package installation performs initialization and migration only; it does not activate the override.

## Compatibility constraints

- BusyBox-compatible POSIX `sh`.
- Chromium 53-compatible JavaScript.
- Conservative CSS without Grid, custom properties, or `gap`.
- QtQuick 2.4 and firmware-provided decoder plugins.
- Primary target resolution: 1920×1080.
