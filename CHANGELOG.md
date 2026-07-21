# Changelog

All notable changes are documented here. The project is pre-release and follows semantic versioning for test packages.

## [Unreleased]

- Physical validation of PNG, JPEG, WebP, APNG, reboot persistence, and long-running stability.

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
- Document the unified `@webos-tools/cli` toolchain.

## [0.2.0] - 2026-07-21

- Add mixed-media imports for GIF, PNG/APNG containers, JPEG, and WebP.
- Add local PC upload helper, format/dimension reporting, smooth/pixel filtering, larger limits, and decoder-error skipping.

## [0.1.1] - 2026-07-21

- Establish the tested webOS 4 GIF-only candidate, reversible bind mount, executable boot hook, compatibility preflight, validation limits, and isolated integration tests.
