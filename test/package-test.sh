#!/bin/sh
set -eu

APP="${1:-}"
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
    echo "Usage: test/package-test.sh EXTRACTED_APP_DIRECTORY" >&2
    exit 2
fi

for required in \
    appinfo.json index.html LICENSE \
    assets/manager.sh assets/install.sh assets/uninstall.sh \
    assets/lib/core.sh assets/lib/media.sh assets/lib/batch.sh assets/lib/commands.sh \
    css/app.css js/update.js js/webos.js js/view.js js/app.js; do
    [ -f "$APP/$required" ] || {
        echo "Missing packaged file: $required" >&2
        exit 1
    }
done

grep '"version": "0.2.7"' "$APP/appinfo.json" >/dev/null
grep 'Screensaver Playlist' "$APP/index.html" >/dev/null
grep 'Automatic updates' "$APP/index.html" >/dev/null
grep 'Press again to reset' "$APP/js/app.js" >/dev/null

for excluded in .git .github docs test tools README.md CONTRIBUTING.md SECURITY.md CHANGELOG.md Makefile package.json; do
    [ ! -e "$APP/$excluded" ] || {
        echo "Development-only path leaked into package: $excluded" >&2
        exit 1
    }
done

echo 'package audit passed'
