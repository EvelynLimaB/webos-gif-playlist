#!/bin/sh
# Sourced by assets/manager.sh. Do not execute directly.

# shellcheck disable=SC2046 # Intentional splitting of numeric byte streams from od.

decode_base64() {
    encoded="$1"
    command -v base64 >/dev/null 2>&1 || {
        echo "ERROR: base64 command is unavailable on this TV" >&2
        return 1
    }

    decoded="$(printf '%s' "$encoded" | base64 -d 2>/dev/null)" || {
        echo "ERROR: malformed base64 input" >&2
        return 1
    }
    printf '%s' "$decoded"
}

validate_url() {
    url="$1"
    case "$url" in
        http://*|https://*) ;;
        *) echo "ERROR: only direct http/https media URLs are allowed" >&2; return 1 ;;
    esac

    [ "${#url}" -le "$MAX_URL_LENGTH" ] || {
        echo "ERROR: URL is longer than $MAX_URL_LENGTH characters" >&2
        return 1
    }

    if printf '%s' "$url" | LC_ALL=C grep '[[:cntrl:]]' >/dev/null 2>&1; then
        echo "ERROR: URL contains control characters" >&2
        return 1
    fi
}

download_file() {
    url="$1"
    destination="$2"
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$destination" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -f -s -S -o "$destination" "$url"
    else
        echo "ERROR: neither wget nor curl is available" >&2
        return 1
    fi
}

read_byte_values() {
    file="$1"
    offset="$2"
    count="$3"
    dd if="$file" bs=1 skip="$offset" count="$count" 2>/dev/null | od -An -tu1 2>/dev/null
}

detect_media_format() {
    file="$1"
    set -- $(read_byte_values "$file" 0 12)
    [ "$#" -ge 2 ] || return 1

    if [ "$#" -ge 6 ] && \
       [ "$1" -eq 71 ] && [ "$2" -eq 73 ] && [ "$3" -eq 70 ] && \
       { [ "$4" -eq 56 ] && { [ "$5" -eq 55 ] || [ "$5" -eq 57 ]; } && [ "$6" -eq 97 ]; }; then
        printf 'gif'
        return 0
    fi

    if [ "$#" -ge 8 ] && \
       [ "$1" -eq 137 ] && [ "$2" -eq 80 ] && [ "$3" -eq 78 ] && [ "$4" -eq 71 ] && \
       [ "$5" -eq 13 ] && [ "$6" -eq 10 ] && [ "$7" -eq 26 ] && [ "$8" -eq 10 ]; then
        printf 'png'
        return 0
    fi

    if [ "$#" -ge 3 ] && [ "$1" -eq 255 ] && [ "$2" -eq 216 ] && [ "$3" -eq 255 ]; then
        printf 'jpg'
        return 0
    fi

    if [ "$#" -ge 12 ] && \
       [ "$1" -eq 82 ] && [ "$2" -eq 73 ] && [ "$3" -eq 70 ] && [ "$4" -eq 70 ] && \
       [ "$9" -eq 87 ] && [ "${10}" -eq 69 ] && [ "${11}" -eq 66 ] && [ "${12}" -eq 80 ]; then
        printf 'webp'
        return 0
    fi

    return 1
}

validate_dimensions() {
    width="$1"
    height="$2"
    format="$3"

    case "$width" in ''|*[!0-9]*) echo "ERROR: could not read $format width" >&2; return 1 ;; esac
    case "$height" in ''|*[!0-9]*) echo "ERROR: could not read $format height" >&2; return 1 ;; esac

    if [ "$width" -le 0 ] || [ "$height" -le 0 ] || \
       [ "$width" -gt "$MAX_DIMENSION" ] || [ "$height" -gt "$MAX_DIMENSION" ]; then
        echo "ERROR: $format dimensions ${width}x${height} exceed the safe TV limit" >&2
        return 1
    fi

    pixels=$((width * height))
    if [ "$pixels" -gt "$MAX_PIXELS" ]; then
        echo "ERROR: $format dimensions ${width}x${height} exceed the safe TV limit" >&2
        return 1
    fi
    printf '%sx%s' "$width" "$height"
}

dimensions_gif() {
    file="$1"
    set -- $(read_byte_values "$file" 6 4)
    [ "$#" -eq 4 ] || { echo "ERROR: could not read GIF dimensions" >&2; return 1; }
    width=$(($1 + ($2 * 256)))
    height=$(($3 + ($4 * 256)))
    validate_dimensions "$width" "$height" GIF
}

dimensions_png() {
    file="$1"
    set -- $(read_byte_values "$file" 8 16)
    [ "$#" -eq 16 ] || { echo "ERROR: could not read PNG IHDR" >&2; return 1; }
    if [ "$1" -ne 0 ] || [ "$2" -ne 0 ] || [ "$3" -ne 0 ] || [ "$4" -ne 13 ] || \
       [ "$5" -ne 73 ] || [ "$6" -ne 72 ] || [ "$7" -ne 68 ] || [ "$8" -ne 82 ]; then
        echo "ERROR: PNG does not begin with a valid IHDR chunk" >&2
        return 1
    fi
    width=$((($9 * 16777216) + (${10} * 65536) + (${11} * 256) + ${12}))
    height=$(((${13} * 16777216) + (${14} * 65536) + (${15} * 256) + ${16}))
    validate_dimensions "$width" "$height" PNG
}

dimensions_jpeg() {
    file="$1"
    file_bytes="$(wc -c < "$file" | tr -d ' ')"
    case "$file_bytes" in ''|*[!0-9]*) file_bytes=0 ;; esac
    offset=2
    marker_loops=0

    while [ "$offset" -lt "$file_bytes" ] && [ "$marker_loops" -lt 256 ]; do
        marker_loops=$((marker_loops + 1))
        set -- $(read_byte_values "$file" "$offset" 2)
        [ "$#" -eq 2 ] || break

        if [ "$1" -ne 255 ]; then
            offset=$((offset + 1))
            continue
        fi

        marker="$2"
        if [ "$marker" -eq 255 ]; then
            offset=$((offset + 1))
            continue
        fi

        case "$marker" in
            192|193|194|195|197|198|199|201|202|203|205|206|207)
                set -- $(read_byte_values "$file" $((offset + 2)) 7)
                [ "$#" -eq 7 ] || break
                height=$(($4 * 256 + $5))
                width=$(($6 * 256 + $7))
                validate_dimensions "$width" "$height" JPEG
                return $?
                ;;
            1|208|209|210|211|212|213|214|215|216|217)
                offset=$((offset + 2))
                ;;
            218)
                break
                ;;
            *)
                set -- $(read_byte_values "$file" $((offset + 2)) 2)
                [ "$#" -eq 2 ] || break
                segment_length=$(($1 * 256 + $2))
                [ "$segment_length" -ge 2 ] || break
                offset=$((offset + 2 + segment_length))
                ;;
        esac
    done

    echo "ERROR: could not read JPEG dimensions" >&2
    return 1
}

dimensions_webp() {
    file="$1"
    set -- $(read_byte_values "$file" 12 4)
    [ "$#" -eq 4 ] || { echo "ERROR: could not read WebP chunk header" >&2; return 1; }

    if [ "$1" -eq 86 ] && [ "$2" -eq 80 ] && [ "$3" -eq 56 ] && [ "$4" -eq 88 ]; then
        set -- $(read_byte_values "$file" 24 6)
        [ "$#" -eq 6 ] || { echo "ERROR: could not read WebP VP8X dimensions" >&2; return 1; }
        width=$((1 + $1 + ($2 * 256) + ($3 * 65536)))
        height=$((1 + $4 + ($5 * 256) + ($6 * 65536)))
    elif [ "$1" -eq 86 ] && [ "$2" -eq 80 ] && [ "$3" -eq 56 ] && [ "$4" -eq 76 ]; then
        set -- $(read_byte_values "$file" 20 5)
        [ "$#" -eq 5 ] || { echo "ERROR: could not read WebP VP8L dimensions" >&2; return 1; }
        [ "$1" -eq 47 ] || { echo "ERROR: invalid WebP VP8L signature" >&2; return 1; }
        width=$((1 + $2 + (($3 & 63) * 256)))
        height=$((1 + (($3 & 192) / 64) + ($4 * 4) + (($5 & 15) * 1024)))
    elif [ "$1" -eq 86 ] && [ "$2" -eq 80 ] && [ "$3" -eq 56 ] && [ "$4" -eq 32 ]; then
        set -- $(read_byte_values "$file" 23 7)
        [ "$#" -eq 7 ] || { echo "ERROR: could not read WebP VP8 dimensions" >&2; return 1; }
        if [ "$1" -ne 157 ] || [ "$2" -ne 1 ] || [ "$3" -ne 42 ]; then
            echo "ERROR: invalid WebP VP8 frame header" >&2
            return 1
        fi
        width=$((($4 + ($5 * 256)) & 16383))
        height=$((($6 + ($7 * 256)) & 16383))
    else
        echo "ERROR: unsupported WebP bitstream" >&2
        return 1
    fi

    validate_dimensions "$width" "$height" WebP
}

media_dimensions() {
    format="$1"
    file="$2"
    case "$format" in
        gif) dimensions_gif "$file" ;;
        png) dimensions_png "$file" ;;
        jpg) dimensions_jpeg "$file" ;;
        webp) dimensions_webp "$file" ;;
        *) echo "ERROR: unsupported image format" >&2; return 1 ;;
    esac
}

check_item_slot() {
    [ "$(playlist_count)" -lt "$MAX_ITEMS" ] || {
        echo "ERROR: playlist limit is $MAX_ITEMS images" >&2
        return 1
    }
}

check_capacity() {
    bytes="$1"
    check_item_slot || return 1

    if [ "$bytes" -le 0 ] || [ "$bytes" -gt "$MAX_BYTES" ]; then
        echo "ERROR: image must be between 1 byte and 32 MiB" >&2
        return 1
    fi

    total_after=$(( $(playlist_total_bytes) + bytes ))
    if [ "$total_after" -gt "$MAX_TOTAL_BYTES" ]; then
        echo "ERROR: playlist storage would exceed 256 MiB" >&2
        return 1
    fi
}

finalize_media() {
    tmp="$1"
    bytes="$(wc -c < "$tmp" | tr -d ' ')"
    case "$bytes" in ''|*[!0-9]*) bytes=0 ;; esac

    check_capacity "$bytes" || {
        rm -f "$tmp"
        exit 1
    }

    format="$(detect_media_format "$tmp" 2>/dev/null || true)"
    [ -n "$format" ] || {
        rm -f "$tmp"
        echo "ERROR: unsupported file. Use GIF, PNG/APNG, JPEG, or WebP." >&2
        exit 1
    }

    dimensions="$(media_dimensions "$format" "$tmp")" || {
        rm -f "$tmp"
        exit 1
    }

    id="media-$(date +%s)-$$.$format"
    dest="$ITEMS_DIR/$id"
    [ ! -e "$dest" ] || {
        rm -f "$tmp"
        echo "ERROR: generated media id already exists" >&2
        exit 1
    }

    playlist_backup="$PLAYLIST_FILE.backup.$$"
    cp "$PLAYLIST_FILE" "$playlist_backup" || {
        rm -f "$tmp"
        echo "ERROR: could not create a playlist transaction backup" >&2
        exit 1
    }

    mv "$tmp" "$dest" || {
        rm -f "$playlist_backup"
        echo "ERROR: could not store the imported image" >&2
        exit 1
    }
    chmod 644 "$dest" || {
        rm -f "$dest" "$playlist_backup"
        echo "ERROR: could not set imported image permissions" >&2
        exit 1
    }

    if ! printf '%s\n' "$id" >> "$PLAYLIST_FILE" || ! generate_qml; then
        mv "$playlist_backup" "$PLAYLIST_FILE" 2>/dev/null || true
        rm -f "$dest"
        generate_qml >/dev/null 2>&1 || true
        echo "ERROR: could not commit the imported image" >&2
        exit 1
    fi
    rm -f "$playlist_backup"
    echo "added=$id"
    echo "format=$format"
    echo "dimensions=$dimensions"
    echo "bytes=$bytes"
}

add_url() {
    ensure_data
    encoded="${1:-}"
    [ -n "$encoded" ] || { echo "ERROR: missing URL" >&2; exit 1; }
    check_item_slot
    url="$(decode_base64 "$encoded")" || exit 1
    validate_url "$url"

    tmp="$ITEMS_DIR/download-$(date +%s)-$$.part"
    rm -f "$tmp"
    download_file "$url" "$tmp" || {
        rm -f "$tmp"
        echo "ERROR: download failed" >&2
        exit 1
    }
    finalize_media "$tmp"
}

import_file() {
    ensure_data
    source_file="${1:-}"
    [ -n "$source_file" ] || { echo "ERROR: missing local file path" >&2; exit 1; }
    [ -f "$source_file" ] || { echo "ERROR: local file was not found" >&2; exit 1; }
    check_item_slot

    tmp="$ITEMS_DIR/import-$(date +%s)-$$.part"
    rm -f "$tmp"
    cp "$source_file" "$tmp" || {
        rm -f "$tmp"
        echo "ERROR: could not copy local file" >&2
        exit 1
    }
    finalize_media "$tmp"
}
