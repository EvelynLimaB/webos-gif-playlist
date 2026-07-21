# Testing

## Local checks

```bash
make check
```

This runs:

- POSIX shell syntax and ShellCheck when installed;
- isolated manager integration tests with fake downloader and mount commands;
- PC upload-helper tests with a fake SSH executable;
- JavaScript syntax checks and a static HTML/JS UI contract test;
- Chromium 53 and conservative CSS source guards.

Build and inspect the exact package:

```bash
make package
make audit-package
sha256sum com.evelyn.webosgifplaylist_*_all.ipk
```

## What automated tests prove

Automated tests cover format signatures/dimensions, storage and URL rejection, transactional list changes, in-place QML updates, settings, ordering, mount ownership, boot-hook lifecycle, reset behavior, helper argument handling, package contents, and source-level compatibility constraints.

They do not prove that a particular firmware can decode or animate every format, that the GPU remains stable, that LG services start in the same order after reboot, or that a one-hour screensaver session is leak-free.

## Physical-TV matrix

Record at minimum:

- TV model, firmware, reported webOS version, Homebrew Channel version;
- compatibility-check output;
- input format, dimensions, file size, animation behavior;
- scaling/filter mode;
- temporary and boot activation results;
- recovery/disable result;
- duration and observed memory/process failures.

Use the release checklist in the README. Keep feature PRs draft until their hardware-dependent rows pass.

## Failure testing

Tests and manual QA should deliberately include malformed base64, HTML masquerading as an image, truncated headers, dimensions above the safe limit, full storage, duplicate/concurrent actions, a foreign bind mount, missing package files, unavailable decoders, and interruption during upload/import.

## Recovery drill

Before enabling at boot on a new firmware, verify that SSH or Telnet recovery is available and rehearse `manager.sh disable`. A recovery path that has not been tested should not be treated as reliable.
