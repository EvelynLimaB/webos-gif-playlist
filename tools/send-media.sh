#!/bin/sh

set -u

TV_HOST="${WEBOS_TV_HOST:-}"
TV_USER="${WEBOS_TV_USER:-root}"
TV_PORT="${WEBOS_TV_PORT:-22}"
IDENTITY_FILE="${WEBOS_TV_IDENTITY:-}"
APP_ID="com.evelyn.webosgifplaylist"
MANAGER="/media/developer/apps/usr/palm/applications/$APP_ID/assets/manager.sh"
CURRENT_REMOTE_FILE=
SEQUENCE=0
SOURCE_COUNT=0
IMPORTED_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

usage() {
    cat <<'USAGE'
Usage:
  tools/send-media.sh --host TV_ADDRESS [options] SOURCE [...]

SOURCE may be:
  - a local GIF, PNG/APNG, JPEG, or WebP file;
  - a local .txt file containing one direct media URL per line;
  - a local directory, processed at its top level in filename order;
  - a direct http:// or https:// media URL.

Options:
  --host ADDRESS       TV hostname or IP address (or WEBOS_TV_HOST)
  --user USER          SSH user; default: root (or WEBOS_TV_USER)
  --port PORT          SSH port; default: 22 (or WEBOS_TV_PORT)
  --identity FILE      SSH private key (or WEBOS_TV_IDENTITY)
  -h, --help           Show this help

Examples:
  tools/send-media.sh --host 192.168.0.13 ~/Pictures/screensavers
  tools/send-media.sh --host 192.168.0.13 ~/Pictures/loop.gif photo.png
  tools/send-media.sh --host 192.168.0.13 ~/Pictures/giphy.txt
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
[ "$#" -gt 0 ] || fail_usage "provide at least one local file, directory, URL list, or direct URL"

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
        ssh \
            -o BatchMode=yes \
            -o ConnectTimeout=10 \
            -o IdentitiesOnly=yes \
            -i "$IDENTITY_FILE" \
            -p "$TV_PORT" \
            "$REMOTE" "$@"
    else
        ssh \
            -o BatchMode=yes \
            -o ConnectTimeout=10 \
            -p "$TV_PORT" \
            "$REMOTE" "$@"
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

send_url() {
    url="$1"
    label="$2"
    encoded="$(printf '%s' "$url" | base64 | tr -d '\r\n')"
    echo "Adding URL: $label"
    if ssh_run "sh '$MANAGER' add '$encoded'"; then
        IMPORTED_COUNT=$((IMPORTED_COUNT + 1))
        return 0
    fi
    FAILED_COUNT=$((FAILED_COUNT + 1))
    return 1
}

send_file() {
    file="$1"
    label="$2"
    SEQUENCE=$((SEQUENCE + 1))
    CURRENT_REMOTE_FILE="/tmp/screensaver-playlist-upload-$$-$SEQUENCE.bin"
    echo "Uploading: $label"

    if ! ssh_run "umask 077; cat > '$CURRENT_REMOTE_FILE'" < "$file"; then
        echo "ERROR: upload failed: $label" >&2
        cleanup_remote
        FAILED_COUNT=$((FAILED_COUNT + 1))
        return 1
    fi

    if ssh_run "sh '$MANAGER' import '$CURRENT_REMOTE_FILE'"; then
        cleanup_remote
        IMPORTED_COUNT=$((IMPORTED_COUNT + 1))
        return 0
    fi

    cleanup_remote
    FAILED_COUNT=$((FAILED_COUNT + 1))
    return 1
}

process_url_list() {
    list_file="$1"
    line_number=0
    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
        line_number=$((line_number + 1))
        url="$(printf '%s' "$raw_line" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        case "$url" in
            ''|'#'*) continue ;;
            http://*|https://*)
                SOURCE_COUNT=$((SOURCE_COUNT + 1))
                send_url "$url" "$(basename "$list_file"):$line_number" || true
                ;;
            *)
                echo "ERROR: invalid URL in $(basename "$list_file"):$line_number" >&2
                FAILED_COUNT=$((FAILED_COUNT + 1))
                ;;
        esac
    done < "$list_file"
}

process_directory() {
    directory="$1"
    found=no

    for entry in "$directory"/*; do
        [ -e "$entry" ] || continue
        found=yes
        if [ -d "$entry" ]; then
            echo "Skipping subdirectory: $(basename "$entry")"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            continue
        fi
        [ -f "$entry" ] || {
            echo "Skipping non-regular entry: $(basename "$entry")"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            continue
        }

        lower_name="$(basename "$entry" | tr '[:upper:]' '[:lower:]')"
        case "$lower_name" in
            *.gif|*.png|*.apng|*.jpg|*.jpeg|*.webp)
                SOURCE_COUNT=$((SOURCE_COUNT + 1))
                send_file "$entry" "$(basename "$entry")" || true
                ;;
            *.txt)
                process_url_list "$entry"
                ;;
            *)
                echo "Skipping unsupported file: $(basename "$entry")"
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                ;;
        esac
    done

    if [ "$found" = no ]; then
        echo "ERROR: directory is empty: $directory" >&2
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
}

for source in "$@"; do
    case "$source" in
        http://*|https://*)
            SOURCE_COUNT=$((SOURCE_COUNT + 1))
            send_url "$source" "$source" || true
            ;;
        *)
            if [ -d "$source" ]; then
                echo "Processing directory: $source"
                process_directory "$source"
            elif [ -f "$source" ]; then
                lower_name="$(basename "$source" | tr '[:upper:]' '[:lower:]')"
                case "$lower_name" in
                    *.txt) process_url_list "$source" ;;
                    *)
                        SOURCE_COUNT=$((SOURCE_COUNT + 1))
                        send_file "$source" "$source" || true
                        ;;
                esac
            else
                echo "ERROR: source not found: $source" >&2
                FAILED_COUNT=$((FAILED_COUNT + 1))
            fi
            ;;
    esac
done

cleanup_remote
trap - 0 HUP INT TERM

echo "source_count=$SOURCE_COUNT"
echo "imported_count=$IMPORTED_COUNT"
echo "failed_count=$FAILED_COUNT"
echo "skipped_count=$SKIPPED_COUNT"

if [ "$FAILED_COUNT" -ne 0 ]; then
    echo "Upload completed with failures. Refresh Screensaver Playlist on the TV." >&2
    exit 1
fi

echo "Upload complete. Refresh Screensaver Playlist on the TV."
