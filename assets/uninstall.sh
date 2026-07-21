#!/bin/sh

set -e

SELF="$(readlink -f "$0" 2>/dev/null || echo "$0")"
APP_DIR="$(dirname "$(dirname "$SELF")")"
exec sh "$APP_DIR/assets/manager.sh" uninstall
