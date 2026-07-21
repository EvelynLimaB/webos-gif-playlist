# Changelog

All notable changes are documented here. The project is pre-release and follows semantic versioning for test packages.

## [Unreleased]

- Physical validation of in-app updates, PC-folder imports, PNG, JPEG, WebP, APNG, reboot persistence, and long-running stability.

## [0.2.6] - 2026-07-21

- Replace unreliable native `window.confirm()` dialogs in the updater with visible two-press confirmations designed for TV remotes.
- Require the second press within 15 seconds for both automatic-update opt-in and manual package installation.
- Verify that the automatic-update preference and pending update version were actually persisted before reporting success.
- Handle unavailable packaged-app storage without leaving the UI in a false enabled state.
- Add regression checks that prohibit native updater confirmation dialogs and cover persistence failures.

## [0.2.5] - 2026-07-21

- Treat GitHub's expected `404` response as an empty release channel rather than an update failure.
- Explain that development builds begin checking normally after the first public GitHub Release exists.
- Keep genuine network, server, malformed-manifest, and installation failures visible as errors.
- Add regression coverage so only release-channel `404` responses receive the non-error state.

## [0.2.4] - 2026-07-21

- Check the official latest-release manifest whenever the application opens.
- Add manual **Check now** and **Install update** controls.
- Add persistent, user-opt-in automatic updates; automatic installation remains disabled by default.
- Reject update manifests with an unexpected application ID, source repository, version, IPK URL, or SHA-256.
- Delegate package download, checksum verification, and installation to the Homebrew Channel service.
- Preserve playlist data, settings, mount state, and boot configuration across package replacement.
- Add update-policy, UI-contract, package-content, and Chromium 53 compatibility checks.

## [0.2.3] - 2026-07-21

- Explicitly restore `AnimatedImage.playing` when each playlist source becomes ready.
- Clear paused state and restart animated sources from frame zero when revisited after still images.
- Add the GitHub Release workflow and Homebrew Channel store metadata.

## [0.2.2] - 2026-07-21

- Add the `import-dir` manager command for importing a whole TV-side directory at once.
- Import GIF, PNG/APNG, JPEG, and WebP files from the directory's top level.
- Treat `.txt` files as direct-media URL lists with blank-line and comment support.
- Continue after individual item failures and print a machine-readable batch summary.
- Add isolated batch-import and package-content tests.
- Allow `tools/send-media.sh` to process a complete PC folder directly over SSH.
- Treat PC-side `.txt` files as direct-media URL lists and report per-batch totals.
- Use non-interactive SSH batch mode so authentication failures stop cleanly instead of prompting repeatedly.
- Automatically adapt oversized local GIF, PNG/APNG, JPEG, and WebP files on the PC before upload.
- Preserve source aspect ratio, leave originals untouched, and report `adapted_count` plus final adapted dimensions.
- Keep the TV-side size limits as a defensive validation boundary; `--no-adapt` remains available for raw uploads.

## [0.2.1] - 2026-07-21

### Safety

- Refuse to replace an existing screensaver mount owned by another package.
- Unmount only a bind mount identified as belonging to Screensaver Playlist.
- Serialize mutating operations with a stale-lock recovery mechanism.
- Make imports, removals, reordering, and setting changes transactional around QML regeneration.
- Stop delayed decoder-error advancement after a later image becomes ready.
- Make package installation initialize data without activating the override.

### Validation

- Reject malformed base64, URL control characters, malformed PNG IHDR data, weak JPEG signatures, and unsafe dimensions.
- Add mount-ownership, install-safety, malformed-input, helper, UI-contract, and package-content tests.
- Add `stat` and mounts-file checks to Compatibility check.

### Contribution and maintenance

- Add contributor, architecture, testing, security, changelog, templates, and editor configuration.
- Replace the personal default TV address in the upload helper with explicit configuration.
- Support SSH user, port, and identity options and stream local files without relying on SCP/SFTP behavior.
- Document the unified LG webOS CLI workflow.

## [0.2.0] - 2026-07-21

- Add mixed-media imports for GIF, PNG/APNG containers, JPEG, and WebP.
- Add local PC upload helper, format/dimension reporting, smooth/pixel filtering, larger limits, and decoder-error skipping.

## [0.1.1] - 2026-07-21

- Establish the tested webOS 4 GIF-only candidate, reversible bind mount, executable boot hook, compatibility preflight, validation limits, and isolated integration tests.
