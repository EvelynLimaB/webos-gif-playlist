#!/bin/sh

set -eu

SELF="$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
APP_DIR="$(dirname "$(dirname "$SELF")")"

# Package installation must never replace the system screensaver implicitly.
# Initialize and migrate local data only; activation remains an explicit action.
exec sh "$APP_DIR/assets/manager.sh" init
