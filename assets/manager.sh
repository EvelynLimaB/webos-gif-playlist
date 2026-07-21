#!/bin/sh

set -e

SELF="$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
APP_DIR="${MEDIA_PLAYLIST_APP_DIR:-${GIF_PLAYLIST_APP_DIR:-$(dirname "$(dirname "$SELF")")}}"
DATA_DIR="${MEDIA_PLAYLIST_DATA_DIR:-${GIF_PLAYLIST_DATA_DIR:-/var/lib/webosbrew/gif-playlist}}"
ITEMS_DIR="$DATA_DIR/items"
PLAYLIST_FILE="$DATA_DIR/playlist.txt"
SETTINGS_FILE="$DATA_DIR/settings.conf"
RUNTIME_QML="$DATA_DIR/screensaver-runtime.qml"
ACTIVE_FILE="$DATA_DIR/active-target"
INIT_DIR="${MEDIA_PLAYLIST_INIT_DIR:-${GIF_PLAYLIST_INIT_DIR:-/var/lib/webosbrew/init.d}}"
INIT_HOOK="$INIT_DIR/55-gif-playlist"
MOUNTS_FILE="${MEDIA_PLAYLIST_MOUNTS_FILE:-${GIF_PLAYLIST_MOUNTS_FILE:-/proc/mounts}}"

SCREENSAVER_BASE="${MEDIA_PLAYLIST_SCREENSAVER_BASE:-${GIF_PLAYLIST_SCREENSAVER_BASE:-/usr/palm/applications/com.webos.app.screensaver}}"
MAIN_TARGET="$SCREENSAVER_BASE/qml/main.qml"
CLOCK_TARGET="$SCREENSAVER_BASE/qml/UserInterfaceLayer/Containers/Clock.qml"

MAX_ITEMS=24
MAX_BYTES=33554432
MAX_TOTAL_BYTES=268435456
MAX_PIXELS=2073600
MAX_DIMENSION=1920
MAX_URL_LENGTH=8192
LOCK_DIR="$DATA_DIR/.manager-lock"
LOCK_PID_FILE="$LOCK_DIR/pid"
LOCK_HELD=no

LIB_DIR="$APP_DIR/assets/lib"

for module in core media batch commands; do
    module_path="$LIB_DIR/$module.sh"
    if [ ! -r "$module_path" ]; then
        echo "ERROR: required manager module is missing: $module_path" >&2
        exit 1
    fi
    case "$module" in
        core) # shellcheck source=assets/lib/core.sh
            . "$module_path" ;;
        media) # shellcheck source=assets/lib/media.sh
            . "$module_path" ;;
        batch) # shellcheck source=assets/lib/batch.sh
            . "$module_path" ;;
        commands) # shellcheck source=assets/lib/commands.sh
            . "$module_path" ;;
    esac
done

command="${1:-status}"
case "$command" in
    init|add|import|remove|move|set|generate|apply|enable|boot|disable|uninstall|reset)
        acquire_lock
        cleanup_temporary_files
        ;;
esac

case "$command" in
    init) ensure_data; generate_qml; show_status ;;
    preflight) preflight ;;
    status) show_status ;;
    list) list_items ;;
    add) add_url "${2:-}" ;;
    import) import_file "${2:-}" ;;
    import-dir) import_directory "${2:-}" ;;
    remove) remove_item "${2:-}" ;;
    move) move_item "${2:-}" "${3:-}" ;;
    set) set_option "${2:-}" "${3:-}" ;;
    generate) generate_qml ;;
    apply) apply_playlist ;;
    enable) enable_playlist ;;
    boot) boot_playlist ;;
    disable) disable_override ;;
    uninstall) uninstall_override ;;
    reset) reset_all ;;
    *) echo "ERROR: unknown command: $command" >&2; exit 1 ;;
esac
