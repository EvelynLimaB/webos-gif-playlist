#!/bin/sh

set -eu

TV_HOST="${WEBOS_TV_HOST:-}"
TV_USER="${WEBOS_TV_USER:-root}"
TV_PORT="${WEBOS_TV_PORT:-22}"
IDENTITY_FILE="${WEBOS_TV_IDENTITY:-}"
APP_ID="com.evelyn.webosgifplaylist"
MANAGER="/media/developer/apps/usr/palm/applications/$APP_ID/assets/manager.sh"
CURRENT_REMOTE_FILE=

usage() {
    cat <<'USAGE'
Usage:
  tools/send-media.sh --host TV_ADDRESS [options] FILE_OR_URL [...]

Options:
  --host ADDRESS       TV hostname or IP address (or WEBOS_TV_HOST)
  --user USER          SSH user; default: root (or WEBOS_TV_USER)
  --port PORT          SSH port; default: 22 (or WEBOS_TV_PORT)
  --identity FILE      SSH private key (or WEBOS_TV_IDENTITY)
  -h, --help           Show this help

Examples:
  tools/send-media.sh --host 192.168.0.13 ~/Pictures/loop.gif
  tools/send-media.sh --host 192.168.0.13 photo.png animation.webp
  tools/send-media.sh --host 192.168.0.13 https://example.com/direct-image.gif
USAGE
}

fail_usage() {
    echo "ERROR: $1" >&2
    usage >&2
    exit 2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --host)
            [ "$#" -ge 2 ] || fail_usage "--host requires a value"
            TV_HOST="$2"
            shift 2
            ;;
        --user)
            [ "$#" -ge 2 ] || fail_usage "--user requires a value"
            TV_USER="$2"
            shift 2
            ;;
        --port)
            [ "$#" -ge 2 ] || fail_usage "--port requires a value"
            TV_PORT="$2"
            shift 2
            ;;
        --identity)
            [ "$#" -ge 2 ] || fail_usage "--identity requires a value"
            IDENTITY_FILE="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*) fail_usage "unknown option: $1" ;;
        *) break ;;
    esac
done

[ -n "$TV_HOST" ] || fail_usage "provide --host or WEBOS_TV_HOST"
[ "$#" -gt 0 ] || fail_usage "provide at least one local file or direct URL"

case "$TV_HOST" in -*|*' '*|*'	'*|*'
'*) fail_usage "invalid TV address" ;; esac
case "$TV_USER" in ''|*[!A-Za-z0-9._-]*) fail_usage "invalid SSH user" ;; esac
case "$TV_PORT" in ''|*[!0-9]*) fail_usage "invalid SSH port" ;; esac
if [ "$TV_PORT" -lt 1 ] || [ "$TV_PORT" -gt 65535 ]; then
    fail_usage "SSH port must be 1-65535"
fi

if [ -n "$IDENTITY_FILE" ] && [ ! -f "$IDENTITY_FILE" ]; then
    echo "ERROR: SSH identity file not found: $IDENTITY_FILE" >&2
    exit 1
fi

command -v ssh >/dev/null 2>&1 || {
    echo "ERROR: ssh is required." >&2
    exit 1
}
command -v base64 >/dev/null 2>&1 || {
    echo "ERROR: base64 is required." >&2
    exit 1
}

REMOTE="$TV_USER@$TV_HOST"

ssh_run() {
    if [ -n "$IDENTITY_FILE" ]; then
        ssh -i "$IDENTITY_FILE" -p "$TV_PORT" "$REMOTE" "$@"
    else
        ssh -p "$TV_PORT" "$REMOTE" "$@"
    fi
}

cleanup_remote() {
    if [ -n "$CURRENT_REMOTE_FILE" ]; then
        ssh_run "rm -f '$CURRENT_REMOTE_FILE'" >/dev/null 2>&1 || true
        CURRENT_REMOTE_FILE=
    fi
}

trap 'cleanup_remote' 0
trap 'cleanup_remote; exit 129' HUP
trap 'cleanup_remote; exit 130' INT
trap 'cleanup_remote; exit 143' TERM

index=0
for source in "$@"; do
    index=$((index + 1))
    case "$source" in
        http://*|https://*)
            encoded="$(printf '%s' "$source" | base64 | tr -d '\r\n')"
            echo "Adding URL: $source"
            ssh_run "sh '$MANAGER' add '$encoded'"
            ;;
        *)
            [ -f "$source" ] || {
                echo "ERROR: file not found: $source" >&2
                exit 1
            }
            CURRENT_REMOTE_FILE="/tmp/screensaver-playlist-upload-$$-$index.bin"
            echo "Uploading: $source"
            ssh_run "umask 077; cat > '$CURRENT_REMOTE_FILE'" < "$source"
            ssh_run "sh '$MANAGER' import '$CURRENT_REMOTE_FILE'"
            cleanup_remote
            ;;
    esac
done

trap - 0 HUP INT TERM
echo "Upload complete. Refresh Screensaver Playlist on the TV."
