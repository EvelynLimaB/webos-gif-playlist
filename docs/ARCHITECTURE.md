# Architecture

## Components

`index.html`, `css/app.css`, and `js/` form a Chromium 53-compatible TV interface. `js/webos.js` is the only browser-to-platform adapter: it calls the Homebrew Channel root execution service and invokes `assets/manager.sh`.

`assets/manager.sh` is the stable command entry point. Its sourced modules separate lifecycle/QML (`assets/lib/core.sh`), media validation/import (`assets/lib/media.sh`), and playlist/status commands (`assets/lib/commands.sh`). Together they are the source of truth for persistent state, validation, activation, boot persistence, and recovery. `tools/send-media.sh` is an unprivileged PC-side convenience wrapper around SSH and the manager's public commands.

## Persistent layout

```text
/var/lib/webosbrew/gif-playlist/
├── items/                   imported source files
├── playlist.txt             ordered item identifiers
├── settings.conf            playback settings
├── screensaver-runtime.qml  generated bind-mount source
├── active-target            diagnostic record
└── .manager-lock/           transient mutation lock
```

The `gif-playlist` directory and `55-gif-playlist` hook names are historical compatibility interfaces retained from v0.1.x.

## Manager command contract

Read operations:

- `preflight`
- `status`
- `list`

Mutating operations:

- `init`, `add BASE64_URL`, `import FILE`
- `remove ID`, `move ID up|down`
- `set mode|duration|fit|filter VALUE`
- `generate`, `apply`, `enable`, `boot`
- `disable`, `uninstall`, `reset`

Machine-readable output uses `key=value`. `list` emits `id<TAB>bytes<TAB>format<TAB>dimensions`. New fields may be appended; existing meanings should not change without migration and a versioned interface plan.

## Import pipeline

1. Serialize the operation with an atomic directory lock.
2. Download or copy into an app-owned `.part` file.
3. Enforce per-item, total-storage, and item-count limits.
4. Detect GIF, PNG, JPEG, or WebP from its signature.
5. Parse and validate logical dimensions without decoding the full image.
6. Move the unchanged source bytes into `items/`.
7. Update `playlist.txt` and regenerate QML as one logical transaction.
8. Roll back the index and media file if QML regeneration fails.

The firmware decoder remains the final authority. A structurally accepted WebP/APNG can still fail during QML playback when the TV lacks the relevant plugin.

## QML and bind mounts

The generated file uses `WebOSWindow` with `_WEBOS_WINDOW_TYPE_SCREENSAVER` and a single Qt Quick `AnimatedImage`. It rotates local `file://` URLs and skips decoder failures after a short delay.

The manager detects the supported LG entry point, then bind-mounts `screensaver-runtime.qml` over it. It never writes to the original LG file. Updates rewrite the runtime file in place to preserve the inode referenced by an active bind mount.

Before apply/disable, mount ownership is checked in two ways:

1. compare the `/proc/mounts` source path when available;
2. compare source and target device/inode identities using `stat`.

A mounted target that cannot be identified as this project's runtime is treated as foreign and is never replaced or unmounted.

## Boot behavior

`enable` applies the override and writes an executable Homebrew `run-parts` hook. `apply` does not create the hook. Package installation calls only `init`; users must activate explicitly. The hook removes itself when the application package is gone.

## Compatibility constraints

- The TV shell is treated as BusyBox/POSIX `sh`, not Bash.
- The web app targets Chromium 53 and avoids modern syntax and APIs.
- QML targets QtQuick 2.4 and firmware-provided image plugins.
- The primary validated screen is 1920×1080.
