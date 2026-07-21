#!/bin/sh

set -eu

SELF="$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
APP_DIR="$(dirname "$(dirname "$SELF")")"
exec sh "$APP_DIR/assets/manager.sh" uninstall
