# GIF Playlist for rooted LG webOS

A local screensaver playlist that downloads several GIFs and rotates through them sequentially or randomly.

Primary validation target:

- **TV:** LG 43LM6300PSB
- **Firmware:** 05.40.97
- **webOS generation:** 4.x / reported 4.10.2
- **Expected target:** `/usr/palm/applications/com.webos.app.screensaver/qml/main.qml`
- **Root environment:** webOS Homebrew Channel

The project remains pre-release until the package passes the complete physical checklist on that exact television.

## v0.1.1 scope

- Add direct `http://` or `https://` GIF URLs.
- Verify GIF87a/GIF89a signature and logical dimensions.
- Store up to 12 GIFs locally.
- Per-file limit: 15 MiB.
- Total playlist limit: 96 MiB.
- Safe image limits: at most 1920 pixels on either axis and 2,073,600 logical pixels.
- Reorder and remove entries.
- Sequential or shuffled playback.
- 10, 20, 30, 60, or 120 second switching.
- Crop, fit, or stretch scaling.
- Temporary application, persistent boot application, test, disable, and reset.
- Chromium 53-compatible ES5-style JavaScript and conservative Flexbox CSS.

## Safety model

The package requires root because it bind-mounts a generated QML file over the LG screensaver entry point. It does **not** overwrite the original system QML file.

Runtime data:

```text
/var/lib/webosbrew/gif-playlist/
```

Executable Homebrew startup hook:

```text
/var/lib/webosbrew/init.d/55-gif-playlist
```

Homebrew Channel starts user hooks with `run-parts`, so this app creates its own executable hook instead of relying on the package preserving shell-script executable bits.

Other screensaver packages and their startup hooks are left untouched. This app runs as hook `55`, after common `50-*` screensaver hooks, and reapplies its own bind mount last. Disabling or manually uninstalling this app does not strand another package's hook inside its data directory.

Playlist updates rewrite the generated QML **in place**. This preserves the source inode used by an active file bind mount, so newly added GIFs and settings take effect without requiring a reboot.

## Build

Install Node.js and `ares-cli`, then run:

```bash
npm install -g @webosose/ares-cli
make package
```

Output:

```text
com.evelyn.webosgifplaylist_0.1.1_all.ipk
```

## Install and first check

Install the `.ipk` with webOS Dev Manager or `ares-install`, launch **GIF Playlist**, and run **Compatibility check** before applying anything.

Equivalent terminal command:

```bash
sh /media/developer/apps/usr/palm/applications/com.evelyn.webosgifplaylist/assets/manager.sh preflight
```

A valid result must show every required command as `ok`, a working downloader, and a target ending in `/qml/main.qml` on the LM6300.

### Buttons

- **Apply temporarily:** use the playlist now, but do not create a boot hook.
- **Enable at boot:** apply now and create the executable Homebrew startup hook.
- **Test screensaver:** apply temporarily first, then trigger the system screensaver.
- **Disable override:** unmount the custom QML and remove this app's boot hook while preserving GIFs.
- **Reset all data:** disable, remove the boot hook, and delete downloaded GIFs/settings.

Before removing the application package through Homebrew Channel, use **Disable override** or **Reset all data**. If the package is removed first, its self-cleaning boot hook exits and deletes itself on the next reboot, but the current-session bind mount remains until reboot.

## Physical checklist for LG 43LM6300PSB

1. Run Compatibility check and confirm `/qml/main.qml`.
2. Add one small GIF and use Test screensaver.
3. Confirm that the custom GIF appears rather than LG's stock screensaver.
4. Add a second GIF while the override is already active.
5. Set 10 seconds and confirm five ordered transitions without rebooting or reapplying.
6. Confirm shuffle does not immediately repeat the same item.
7. Test Crop, Fit, and Stretch while the override remains mounted.
8. Disable and verify the stock LG screensaver returns.
9. Apply temporarily and verify no `55-gif-playlist` hook remains after reboot.
10. Enable at boot, disable Quick Start+, and perform a complete reboot.
11. Confirm the custom screensaver still works after reboot.
12. Run it for at least one hour and watch for stutter, black frames, process restarts, or memory instability.
13. Remove a GIF while active and confirm it disappears from the next screensaver launch.
14. Reset all data and confirm the stock screensaver and empty local data state.

## Recovery over SSH or Telnet

Common sideload path:

```text
/media/developer/apps/usr/palm/applications/com.evelyn.webosgifplaylist
```

Preserve GIFs and restore stock:

```bash
sh /media/developer/apps/usr/palm/applications/com.evelyn.webosgifplaylist/assets/manager.sh disable
```

Remove all playlist data:

```bash
sh /media/developer/apps/usr/palm/applications/com.evelyn.webosgifplaylist/assets/manager.sh reset
```

Emergency recovery when the app path is unavailable:

```bash
umount /usr/palm/applications/com.webos.app.screensaver/qml/main.qml 2>/dev/null || true
umount /usr/palm/applications/com.webos.app.screensaver/qml/UserInterfaceLayer/Containers/Clock.qml 2>/dev/null || true
rm -f /var/lib/webosbrew/init.d/55-gif-playlist
rm -f /var/lib/webosbrew/gif-playlist/active-target
reboot
```

## Development checks

```bash
sh test/manager-test.sh
make package
make preflight
make apply
make enable
make status
make test
make disable
make reset
```

The integration test uses isolated temporary directories and fake mount commands to verify add, apply, in-place QML updates, executable `run-parts` boot hook creation, reorder, settings, disable, and reset.

## Origin and license

Based on ideas and MIT-licensed code from:

- `Oted/idlegif`
- `webosbrew/custom-screensaver`

The original notices remain in `LICENSE`.
