# GIF Playlist for LG webOS

A rooted-TV screensaver that downloads several GIFs, stores them locally, and rotates through them sequentially or randomly.

This fork is being built and tested first for:

- **TV:** LG 43LM6300PSB
- **Firmware:** 05.40.97
- **webOS:** 4.10.2 / webOS 4.x generation
- **System target:** `/usr/palm/applications/com.webos.app.screensaver/qml/main.qml`
- **Root environment:** webOS Homebrew Channel

The project is not considered stable until the package passes physical testing on that exact television.

## Current v0.1 scope

- Add direct `http://` or `https://` GIF URLs.
- Validate the GIF signature before accepting a download.
- Store up to 12 GIFs locally, with a 25 MiB per-file limit.
- Reorder and remove playlist entries.
- Sequential or shuffled playback.
- 10, 20, 30, 60, or 120 second rotation interval.
- Crop, fit, or stretch scaling.
- Apply the override temporarily or at every boot.
- Restore the stock screensaver without deleting the playlist.
- Full reset and SSH recovery commands.
- JavaScript and CSS kept compatible with the Chromium 53-era web engine used by webOS 4.x.

## Safety model

The package requires root because it bind-mounts a generated QML file over the stock screensaver entry point. The original system file is not overwritten.

Runtime files are stored under:

```text
/var/lib/webosbrew/gif-playlist/
```

The boot hook is:

```text
/var/lib/webosbrew/init.d/55-gif-playlist
```

Known competing screensaver hooks from Idlegif and Custom Screensaver are moved into the app data directory while GIF Playlist is active. They are restored by the app's uninstall action.

## Build

Install Node.js and the official webOS `ares-cli`, then run:

```bash
npm install -g @webosose/ares-cli
make package
```

The result is:

```text
com.evelyn.webosgifplaylist_0.1.0_all.ipk
```

## Install on the TV

Configure the TV as the `tv` target in `ares-setup-device`, then:

```bash
make install
make apply
make launch
```

Or install the generated `.ipk` through webOS Dev Manager/Homebrew tooling and open **GIF Playlist** from the launcher.

Before enabling this app, remove or disable any other package that currently replaces the LG screensaver.

## Physical test sequence for the LM6300

1. Open the app and confirm the detected target ends in `/qml/main.qml`.
2. Add one small GIF and test the screensaver.
3. Add a second GIF and set the interval to 10 seconds.
4. Confirm ordered rotation for at least five transitions.
5. Confirm shuffle mode does not immediately repeat the same item.
6. Test crop, fit, and stretch.
7. Enable at boot and fully reboot the TV with Quick Start+ disabled.
8. Trigger the screensaver again after reboot.
9. Leave it running for at least one hour while observing memory stability.
10. Disable the override and verify the stock LG screensaver returns.
11. Re-enable and confirm the playlist is preserved.
12. Reset all data and confirm the stock screensaver and empty state.

## Recovery over SSH or Telnet

Determine the installed application path, commonly:

```text
/media/developer/apps/usr/palm/applications/com.evelyn.webosgifplaylist
```

Disable the override while preserving downloaded GIFs:

```bash
sh /media/developer/apps/usr/palm/applications/com.evelyn.webosgifplaylist/assets/manager.sh disable
```

Remove the override and restore competing boot hooks:

```bash
sh /media/developer/apps/usr/palm/applications/com.evelyn.webosgifplaylist/assets/manager.sh uninstall
```

Remove all playlist data as well:

```bash
sh /media/developer/apps/usr/palm/applications/com.evelyn.webosgifplaylist/assets/manager.sh reset
```

Emergency manual recovery:

```bash
umount /usr/palm/applications/com.webos.app.screensaver/qml/main.qml 2>/dev/null || true
rm -f /var/lib/webosbrew/init.d/55-gif-playlist
reboot
```

## Development commands

```bash
make update   # build, install, apply, and launch
make status   # inspect detected target and playlist settings
make test     # trigger the system screensaver
make disable  # restore stock screensaver, preserve data
make reset    # restore stock screensaver and remove data
make inspect  # open the web inspector
```

## Origin and license

Based on ideas and code from:

- [Oted/idlegif](https://github.com/Oted/idlegif)
- [webosbrew/custom-screensaver](https://github.com/webosbrew/custom-screensaver)

Licensed under the MIT License. The original copyright notices remain in `LICENSE`.
