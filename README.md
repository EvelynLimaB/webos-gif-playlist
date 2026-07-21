# Screensaver Playlist for rooted LG webOS

A local, rotating screensaver playlist for animated and still images. Media is downloaded or copied to the TV once, preserved byte-for-byte, and displayed sequentially or in shuffle mode.

> **Pre-release:** GIF playback is confirmed on an LG 43LM6300PSB running firmware 05.40.97 / webOS 4.10.2. Every other format and the complete recovery/reboot checklist must still pass on physical hardware before this branch is considered stable.

## Features

- Direct HTTP/HTTPS imports without relying on filename extensions.
- Personal-file upload from Linux, macOS, or WSL over SSH.
- GIF, PNG/APNG containers, JPEG, and WebP signature detection.
- Source bytes are never resized, converted, recompressed, or re-encoded.
- Up to 24 items, 32 MiB per item, and 256 MiB total.
- Maximum logical dimensions: 1920 pixels per axis and 2,073,600 pixels total.
- Sequential or shuffled rotation at 10, 20, 30, 60, 120, or 300 seconds.
- Crop, fit, or stretch scaling, with smooth or pixel filtering.
- Temporary activation, explicit boot activation, safe disable, and complete reset.
- Protection against replacing or unmounting a foreign screensaver override.

The app uses Qt Quick `AnimatedImage`. GIF is confirmed on the target TV. PNG and JPEG still require physical validation. Static/animated WebP and APNG depend on decoder plugins included in a particular firmware; rejected items are skipped rather than leaving the playlist stuck.

## Compatibility target

| Component | Validated target |
|---|---|
| TV | LG 43LM6300PSB |
| Firmware | 05.40.97 |
| webOS | 4.x / reported 4.10.2 |
| Root environment | webOS Homebrew Channel |
| Screensaver entry point | `/usr/palm/applications/com.webos.app.screensaver/qml/main.qml` |
| Browser baseline | Chromium 53 / ES5 |
| Shell baseline | BusyBox-compatible POSIX `sh` |

## Install

Build with the current unified LG CLI:

```bash
npm install -g @webos-tools/cli@3.2.5
make check
make package
```

Install `com.evelyn.webosgifplaylist_0.2.1_all.ipk` with webOS Dev Manager or `ares-install`, then open **Screensaver Playlist** and run **Compatibility check**.

Package installation only initializes/migrates local data. It does **not** activate the override or create a boot hook. Activation is always explicit.

A valid compatibility result must show every dependency as `ok`, including `stat`, `mountsFile=ok`, a downloader, and the expected `/qml/main.qml` target.

## Add media

### Direct URL

Paste a URL that returns the actual media bytes. Redirects are followed and the URL does not need a conventional extension. A normal webpage returning HTML is rejected.

### Personal files from a PC

The TV must accept SSH as `root`:

```bash
chmod +x tools/send-media.sh

tools/send-media.sh --host 192.168.0.13 ~/Pictures/loop.gif
tools/send-media.sh --host 192.168.0.13 photo.png animation.webp
```

Optional SSH configuration:

```bash
export WEBOS_TV_HOST=192.168.0.13
export WEBOS_TV_USER=root
export WEBOS_TV_PORT=22
export WEBOS_TV_IDENTITY="$HOME/.ssh/webos_tv"

tools/send-media.sh ~/Pictures/loop.gif
```

The helper streams each local file over SSH to a private temporary path, imports it, and removes the temporary copy even when import fails.

Manual equivalent:

```bash
cat ~/Pictures/loop.gif | ssh root@192.168.0.13 \
  "umask 077; cat > /tmp/screensaver-upload.bin"

ssh root@192.168.0.13 \
  "sh /media/developer/apps/usr/palm/applications/com.evelyn.webosgifplaylist/assets/manager.sh import /tmp/screensaver-upload.bin; rm -f /tmp/screensaver-upload.bin"
```

## Controls

- **Apply temporarily:** activate until reboot without creating a startup hook.
- **Enable at boot:** activate now and create the Homebrew startup hook.
- **Test screensaver:** apply temporarily and request the system screensaver immediately.
- **Disable override:** unmount only this app's own override and remove its boot hook; media remains.
- **Reset all data:** disable, remove the hook, and delete local media/settings.
- **Filtering: Smooth:** preferred for photos and illustration.
- **Filtering: Pixel:** nearest-neighbor-style scaling for pixel art.

Runtime data intentionally remains at the historical v0.1.x path so upgrades migrate in place:

```text
/var/lib/webosbrew/gif-playlist/
```

Startup hook:

```text
/var/lib/webosbrew/init.d/55-gif-playlist
```

The app bind-mounts a generated QML file over the system entry point; it never overwrites LG's original QML. Generated QML is rewritten in place so active bind mounts retain their inode. Before applying, the manager verifies that any existing mount belongs to this app. Foreign screensaver mounts are refused and left untouched.

## Physical release checklist

1. Run Compatibility check and confirm `/qml/main.qml`, `stat=ok`, and `mountsFile=ok`.
2. Confirm an existing v0.1.x GIF playlist migrates and still plays.
3. Add a direct GIF and a personally uploaded GIF.
4. Test a 1920×1080 JPEG and PNG with Smooth, Fit, and Crop.
5. Test static WebP, animated WebP, and APNG; record full animation, first-frame-only behavior, or decoder failure.
6. Add and remove media while the override is active.
7. Confirm five ordered transitions at 10 seconds and verify shuffle avoids immediate repeats.
8. Confirm malformed/unsupported files are rejected without changing the playlist.
9. Confirm applying while another screensaver override is mounted is refused.
10. Disable and verify the stock LG screensaver returns.
11. Apply temporarily, reboot with Quick Start+ disabled, and verify the override does not persist.
12. Enable at boot, perform a full reboot, and verify persistence.
13. Run for at least one hour while watching for stutter, black frames, restarts, memory pressure, and remote responsiveness.
14. Reset all data and confirm the stock screensaver and empty data state.

## Recovery

Preserve media and restore stock:

```bash
sh /media/developer/apps/usr/palm/applications/com.evelyn.webosgifplaylist/assets/manager.sh disable
```

Remove all app data:

```bash
sh /media/developer/apps/usr/palm/applications/com.evelyn.webosgifplaylist/assets/manager.sh reset
```

Emergency recovery when the package path is unavailable:

```bash
umount /usr/palm/applications/com.webos.app.screensaver/qml/main.qml 2>/dev/null || true
umount /usr/palm/applications/com.webos.app.screensaver/qml/UserInterfaceLayer/Containers/Clock.qml 2>/dev/null || true
rm -f /var/lib/webosbrew/init.d/55-gif-playlist
rm -f /var/lib/webosbrew/gif-playlist/active-target
reboot
```

## Development

```bash
make check            # shell, manager, helper, UI-contract tests
make package          # minimal IPK payload
make audit-package    # inspect the built IPK
make test-tv          # explicitly trigger the TV screensaver
```

See [CONTRIBUTING.md](CONTRIBUTING.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), and [docs/TESTING.md](docs/TESTING.md) before changing the shell/QML boundary.

## License and origin

MIT licensed. The project retains notices for the MIT-licensed work it originated from, including `Oted/idlegif` and `webosbrew/custom-screensaver`. See [LICENSE](LICENSE).
