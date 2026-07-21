#!/bin/sh

set -u

TV_HOST="${WEBOS_TV_HOST:-}"
TV_USER="${WEBOS_TV_USER:-root}"
TV_PORT="${WEBOS_TV_PORT:-22}"
IDENTITY_FILE="${WEBOS_TV_IDENTITY:-}"
APP_ID="com.evelyn.webosgifplaylist"
MANAGER="/media/developer/apps/usr/palm/applications/$APP_ID/assets/manager.sh"
CURRENT_REMOTE_FILE=
ADAPT_DIR=
SEQUENCE=0
SOURCE_COUNT=0
IMPORTED_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0
ADAPTED_COUNT=0
ADAPT_OVERSIZE=yes
ADAPT_WIDTH=1920
ADAPT_HEIGHT=1080
ADAPT_PIXELS=2073600
PREPARED_FILE=
IMAGE_TOOL=

usage() {
    cat <<'USAGE'
Usage:
  tools/send-media.sh --host TV_ADDRESS [options] SOURCE [...]

SOURCE may be:
  - a local GIF, PNG/APNG, JPEG, or WebP file;
  - a local .txt file containing one direct media URL per line;
  - a local directory, processed at its top level in filename order;
  - a direct http:// or https:// media URL.

Oversized local media is adapted on the PC by default. The original file is
left untouched; a temporary, aspect-preserving copy is fitted inside 1920x1080
before upload. ImageMagick is required only when a file needs adaptation.

Options:
  --host ADDRESS       TV hostname or IP address (or WEBOS_TV_HOST)
  --user USER          SSH user; default: root (or WEBOS_TV_USER)
  --port PORT          SSH port; default: 22 (or WEBOS_TV_PORT)
  --identity FILE      SSH private key (or WEBOS_TV_IDENTITY)
  --no-adapt           Upload original local files without PC-side resizing
  --adapt              Enable PC-side resizing (default)
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
        --no-adapt)
            ADAPT_OVERSIZE=no
            shift
            ;;
        --adapt)
            ADAPT_OVERSIZE=yes
            shift
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

cleanup_all() {
    cleanup_remote
    if [ -n "$ADAPT_DIR" ]; then
        rm -rf "$ADAPT_DIR"
        ADAPT_DIR=
    fi
}

trap 'cleanup_all' 0
trap 'cleanup_all; exit 129' HUP
trap 'cleanup_all; exit 130' INT
trap 'cleanup_all; exit 143' TERM

detect_image_tool() {
    [ -n "$IMAGE_TOOL" ] && return 0
    if command -v magick >/dev/null 2>&1; then
        IMAGE_TOOL=magick
        return 0
    fi
    if command -v identify >/dev/null 2>&1 && command -v convert >/dev/null 2>&1; then
        IMAGE_TOOL=legacy
        return 0
    fi
    return 1
}

image_dimensions() {
    image_file="$1"
    detect_image_tool || return 1
    if [ "$IMAGE_TOOL" = magick ]; then
        magick identify -ping -format '%w %h\n' "${image_file}[0]" 2>/dev/null | head -n 1
    else
        identify -ping -format '%w %h\n' "${image_file}[0]" 2>/dev/null | head -n 1
    fi
}

run_image_convert() {
    if [ "$IMAGE_TOOL" = magick ]; then
        magick "$@"
    else
        convert "$@"
    fi
}

ensure_adapt_dir() {
    [ -n "$ADAPT_DIR" ] && return 0
    command -v mktemp >/dev/null 2>&1 || {
        echo "ERROR: mktemp is required to adapt oversized media" >&2
        return 1
    }
    ADAPT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/webos-media-adapt.XXXXXX")" || return 1
}

adapt_media() {
    source_file="$1"
    label="$2"
    width="$3"
    height="$4"
    lower_name="$(basename "$source_file" | tr '[:upper:]' '[:lower:]')"

    ensure_adapt_dir || return 1
    output_file="$ADAPT_DIR/$(printf '%04d' $((ADAPTED_COUNT + 1)))-$(basename "$source_file")"
    geometry="${ADAPT_WIDTH}x${ADAPT_HEIGHT}>"

    echo "Adapting oversized media: $label (${width}x${height} -> fit ${ADAPT_WIDTH}x${ADAPT_HEIGHT})"
    case "$lower_name" in
        *.gif)
            run_image_convert "$source_file" -coalesce -resize "$geometry" -layers Optimize "$output_file"
            ;;
        *.jpg|*.jpeg)
            run_image_convert "$source_file" -auto-orient -resize "$geometry" -strip -quality 92 "$output_file"
            ;;
        *.png|*.apng|*.webp)
            run_image_convert "$source_file" -auto-orient -resize "$geometry" "$output_file"
            ;;
        *)
            echo "ERROR: cannot adapt unsupported local format: $label" >&2
            return 1
            ;;
    esac || {
        rm -f "$output_file"
        echo "ERROR: ImageMagick could not adapt: $label" >&2
        return 1
    }

    [ -s "$output_file" ] || {
        rm -f "$output_file"
        echo "ERROR: adapted output is empty: $label" >&2
        return 1
    }

    adapted_dimensions="$(image_dimensions "$output_file" 2>/dev/null || true)"
    set -- $adapted_dimensions
    if [ "$#" -ne 2 ]; then
        rm -f "$output_file"
        echo "ERROR: could not verify adapted dimensions: $label" >&2
        return 1
    fi

    adapted_width="$1"
    adapted_height="$2"
    case "$adapted_width:$adapted_height" in
        *[!0-9:]*|:*)
            rm -f "$output_file"
            echo "ERROR: invalid adapted dimensions: $label" >&2
            return 1
            ;;
    esac
    adapted_pixels=$((adapted_width * adapted_height))
    if [ "$adapted_width" -gt "$ADAPT_WIDTH" ] || \
       [ "$adapted_height" -gt "$ADAPT_HEIGHT" ] || \
       [ "$adapted_pixels" -gt "$ADAPT_PIXELS" ]; then
        rm -f "$output_file"
        echo "ERROR: adapted file still exceeds TV-safe dimensions: $label" >&2
        return 1
    fi

    ADAPTED_COUNT=$((ADAPTED_COUNT + 1))
    PREPARED_FILE="$output_file"
    echo "adapted_dimensions=${adapted_width}x${adapted_height}"
}

prepare_file() {
    source_file="$1"
    label="$2"
    PREPARED_FILE="$source_file"

    [ "$ADAPT_OVERSIZE" = yes ] || return 0

    dimensions="$(image_dimensions "$source_file" 2>/dev/null || true)"
    if [ -z "$dimensions" ]; then
        if ! detect_image_tool; then
            echo "ERROR: ImageMagick is required to inspect and adapt local media." >&2
            echo "Install it with: sudo apt install imagemagick" >&2
        else
            echo "ERROR: ImageMagick could not read dimensions: $label" >&2
        fi
        return 1
    fi

    set -- $dimensions
    if [ "$#" -ne 2 ]; then
        echo "ERROR: invalid dimensions reported for: $label" >&2
        return 1
    fi
    width="$1"
    height="$2"
    case "$width:$height" in
        *[!0-9:]*|:*)
            echo "ERROR: invalid dimensions reported for: $label" >&2
            return 1
            ;;
    esac

    pixels=$((width * height))
    if [ "$width" -le "$ADAPT_WIDTH" ] && \
       [ "$height" -le "$ADAPT_HEIGHT" ] && \
       [ "$pixels" -le "$ADAPT_PIXELS" ]; then
        return 0
    fi

    adapt_media "$source_file" "$label" "$width" "$height"
}

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

    if ! prepare_file "$file" "$label"; then
        FAILED_COUNT=$((FAILED_COUNT + 1))
        return 1
    fi

    SEQUENCE=$((SEQUENCE + 1))
    CURRENT_REMOTE_FILE="/tmp/screensaver-playlist-upload-$$-$SEQUENCE.bin"
    echo "Uploading: $label"

    if ! ssh_run "umask 077; cat > '$CURRENT_REMOTE_FILE'" < "$PREPARED_FILE"; then
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
    list_name="$(basename "$list_file")"
    line_number=0

    while IFS= read -r raw_line <&3 || [ -n "$raw_line" ]; do
        line_number=$((line_number + 1))
        url="$(printf '%s' "$raw_line" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        case "$url" in
            ''|'#'*) continue ;;
            http://*|https://*)
                SOURCE_COUNT=$((SOURCE_COUNT + 1))
                send_url "$url" "$list_name:$line_number" || true
                ;;
            *)
                echo "ERROR: invalid URL in $list_name:$line_number" >&2
                FAILED_COUNT=$((FAILED_COUNT + 1))
                ;;
        esac
    done 3< "$list_file"
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

cleanup_all
trap - 0 HUP INT TERM

echo "source_count=$SOURCE_COUNT"
echo "imported_count=$IMPORTED_COUNT"
echo "adapted_count=$ADAPTED_COUNT"
echo "failed_count=$FAILED_COUNT"
echo "skipped_count=$SKIPPED_COUNT"

if [ "$FAILED_COUNT" -ne 0 ]; then
    echo "Upload completed with failures. Refresh Screensaver Playlist on the TV." >&2
    exit 1
fi

echo "Upload complete. Refresh Screensaver Playlist on the TV."
