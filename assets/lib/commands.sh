#!/bin/sh
# Sourced by assets/manager.sh. Do not execute directly.

remove_item() {
    ensure_data
    id="${1:-}"
    valid_name "$id" || { echo "ERROR: invalid item id" >&2; exit 1; }
    grep -Fx "$id" "$PLAYLIST_FILE" >/dev/null 2>&1 || {
        echo "ERROR: playlist item was not found" >&2
        exit 1
    }

    playlist_backup="$PLAYLIST_FILE.backup.$$"
    candidate="$PLAYLIST_FILE.tmp.$$"
    cp "$PLAYLIST_FILE" "$playlist_backup"
    grep -Fvx "$id" "$PLAYLIST_FILE" > "$candidate" || true
    mv "$candidate" "$PLAYLIST_FILE"

    if ! generate_qml; then
        mv "$playlist_backup" "$PLAYLIST_FILE" 2>/dev/null || true
        generate_qml >/dev/null 2>&1 || true
        echo "ERROR: could not commit playlist removal" >&2
        exit 1
    fi

    rm -f "$playlist_backup" "$ITEMS_DIR/$id"
    echo "removed=$id"
}

move_item() {
    ensure_data
    id="${1:-}"
    direction="${2:-}"
    valid_name "$id" || { echo "ERROR: invalid item id" >&2; exit 1; }
    case "$direction" in up|down) ;; *) echo "ERROR: direction must be up or down" >&2; exit 1 ;; esac
    grep -Fx "$id" "$PLAYLIST_FILE" >/dev/null 2>&1 || {
        echo "ERROR: playlist item was not found" >&2
        exit 1
    }

    playlist_backup="$PLAYLIST_FILE.backup.$$"
    candidate="$PLAYLIST_FILE.tmp.$$"
    cp "$PLAYLIST_FILE" "$playlist_backup"
    awk -v wanted="$id" -v direction="$direction" '
        { lines[NR] = $0; if ($0 == wanted) position = NR }
        END {
            count = NR
            if (direction == "up" && position > 1) {
                swap = lines[position - 1]; lines[position - 1] = lines[position]; lines[position] = swap
            } else if (direction == "down" && position > 0 && position < count) {
                swap = lines[position + 1]; lines[position + 1] = lines[position]; lines[position] = swap
            }
            for (i = 1; i <= count; i++) print lines[i]
        }
    ' "$PLAYLIST_FILE" > "$candidate"
    mv "$candidate" "$PLAYLIST_FILE"

    if ! generate_qml; then
        mv "$playlist_backup" "$PLAYLIST_FILE" 2>/dev/null || true
        generate_qml >/dev/null 2>&1 || true
        echo "ERROR: could not commit playlist reorder" >&2
        exit 1
    fi

    rm -f "$playlist_backup"
    echo "moved=$id:$direction"
}

set_option() {
    ensure_data
    key="${1:-}"
    value="${2:-}"
    mode="$(read_setting mode ordered)"
    duration="$(read_setting duration 30000)"
    fit="$(read_setting fit crop)"
    filter="$(read_setting filter smooth)"

    case "$key" in
        mode)
            case "$value" in ordered|shuffle) mode="$value" ;; *) echo "ERROR: invalid mode" >&2; exit 1 ;; esac
            ;;
        duration)
            case "$value" in ''|*[!0-9]*) echo "ERROR: invalid duration" >&2; exit 1 ;; esac
            if [ "$value" -lt 10000 ] || [ "$value" -gt 300000 ]; then
                echo "ERROR: duration must be 10000-300000 ms" >&2
                exit 1
            fi
            duration="$value"
            ;;
        fit)
            case "$value" in crop|fit|stretch) fit="$value" ;; *) echo "ERROR: invalid fit mode" >&2; exit 1 ;; esac
            ;;
        filter)
            case "$value" in smooth|pixel) filter="$value" ;; *) echo "ERROR: invalid filter mode" >&2; exit 1 ;; esac
            ;;
        *) echo "ERROR: unknown setting" >&2; exit 1 ;;
    esac

    settings_backup="$SETTINGS_FILE.backup.$$"
    cp "$SETTINGS_FILE" "$settings_backup"
    if ! write_settings "$mode" "$duration" "$fit" "$filter" || ! generate_qml; then
        mv "$settings_backup" "$SETTINGS_FILE" 2>/dev/null || true
        generate_qml >/dev/null 2>&1 || true
        echo "ERROR: could not commit setting update" >&2
        exit 1
    fi
    rm -f "$settings_backup"
    echo "updated=$key:$value"
}

list_items() {
    ensure_data
    while IFS= read -r id; do
        valid_name "$id" || continue
        [ -f "$ITEMS_DIR/$id" ] || continue
        bytes="$(wc -c < "$ITEMS_DIR/$id" | tr -d ' ')"
        format="$(detect_media_format "$ITEMS_DIR/$id" 2>/dev/null || printf unknown)"
        dimensions="$(media_dimensions "$format" "$ITEMS_DIR/$id" 2>/dev/null || printf unknown)"
        printf '%s\t%s\t%s\t%s\n' "$id" "$bytes" "$format" "$dimensions"
    done < "$PLAYLIST_FILE"
}

show_status() {
    ensure_data
    target="$(detect_target 2>/dev/null || true)"
    enabled=no
    if [ -n "$target" ] && is_own_mount "$target"; then
        enabled=yes
    fi

    autostart=no
    [ -x "$INIT_HOOK" ] && autostart=yes

    printf 'enabled=%s\n' "$enabled"
    printf 'autostart=%s\n' "$autostart"
    printf 'target=%s\n' "$target"
    printf 'count=%s\n' "$(playlist_count)"
    printf 'bytes=%s\n' "$(playlist_total_bytes)"
    printf 'mode=%s\n' "$(read_setting mode ordered)"
    printf 'duration=%s\n' "$(read_setting duration 30000)"
    printf 'fit=%s\n' "$(read_setting fit crop)"
    printf 'filter=%s\n' "$(read_setting filter smooth)"
    printf 'maxItems=%s\n' "$MAX_ITEMS"
    printf 'maxBytes=%s\n' "$MAX_BYTES"
    printf 'maxTotalBytes=%s\n' "$MAX_TOTAL_BYTES"
}

preflight() {
    missing=0
    for command_name in mount umount dd od sed awk grep wc tr base64 cp stat chmod mv rm mkdir cat head date sleep kill dirname basename; do
        if command -v "$command_name" >/dev/null 2>&1; then
            printf '%s=ok\n' "$command_name"
        else
            printf '%s=missing\n' "$command_name"
            missing=1
        fi
    done

    if command -v wget >/dev/null 2>&1 || command -v curl >/dev/null 2>&1; then
        printf 'downloader=ok\n'
    else
        printf 'downloader=missing\n'
        missing=1
    fi

    if [ -r "$MOUNTS_FILE" ]; then
        printf 'mountsFile=ok\n'
    else
        printf 'mountsFile=missing\n'
        missing=1
    fi

    target="$(detect_target 2>/dev/null || true)"
    if [ -n "$target" ]; then
        printf 'target=%s\n' "$target"
    else
        printf 'target=missing\n'
        missing=1
    fi

    [ "$missing" -eq 0 ] || exit 1
}

disable_override() {
    disable_own_mounts
    rm -f "$INIT_HOOK"
    echo "disabled"
}

uninstall_override() {
    disable_override
    echo "override removed; playlist data preserved"
}

reset_all() {
    uninstall_override
    rm -rf "$DATA_DIR"
    echo "playlist data removed"
}
