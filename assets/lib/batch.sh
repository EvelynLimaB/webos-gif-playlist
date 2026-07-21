#!/bin/sh
# Sourced by assets/manager.sh. Do not execute directly.

batch_import_file() {
    source_file="$1"
    label="$2"
    echo "batch_source=$label"
    if sh "$SELF" import "$source_file"; then
        BATCH_IMPORTED=$((BATCH_IMPORTED + 1))
    else
        BATCH_FAILED=$((BATCH_FAILED + 1))
    fi
}

batch_import_url() {
    url="$1"
    label="$2"
    encoded="$(printf '%s' "$url" | base64 | tr -d '\r\n')"
    echo "batch_source=$label"
    if sh "$SELF" add "$encoded"; then
        BATCH_IMPORTED=$((BATCH_IMPORTED + 1))
    else
        BATCH_FAILED=$((BATCH_FAILED + 1))
    fi
}

batch_import_url_list() {
    list_file="$1"
    line_number=0

    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
        line_number=$((line_number + 1))
        url="$(printf '%s' "$raw_line" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        case "$url" in
            ''|'#'*) continue ;;
            http://*|https://*)
                BATCH_URLS=$((BATCH_URLS + 1))
                batch_import_url "$url" "$(basename "$list_file"):$line_number"
                ;;
            *)
                echo "ERROR: invalid URL in $(basename "$list_file"):$line_number" >&2
                BATCH_FAILED=$((BATCH_FAILED + 1))
                ;;
        esac
    done < "$list_file"
}

import_directory() {
    source_dir="${1:-}"
    [ -n "$source_dir" ] || { echo "ERROR: missing directory path" >&2; return 1; }
    [ -d "$source_dir" ] || { echo "ERROR: directory was not found: $source_dir" >&2; return 1; }

    BATCH_FILES=0
    BATCH_URLS=0
    BATCH_IMPORTED=0
    BATCH_FAILED=0
    BATCH_SKIPPED=0
    BATCH_SEEN=0

    for source_file in "$source_dir"/*; do
        [ -e "$source_file" ] || continue
        [ -f "$source_file" ] || {
            BATCH_SKIPPED=$((BATCH_SKIPPED + 1))
            continue
        }

        BATCH_SEEN=$((BATCH_SEEN + 1))
        lower_name="$(basename "$source_file" | tr '[:upper:]' '[:lower:]')"
        case "$lower_name" in
            *.gif|*.png|*.apng|*.jpg|*.jpeg|*.webp)
                BATCH_FILES=$((BATCH_FILES + 1))
                batch_import_file "$source_file" "$(basename "$source_file")"
                ;;
            *.txt)
                batch_import_url_list "$source_file"
                ;;
            *)
                BATCH_SKIPPED=$((BATCH_SKIPPED + 1))
                echo "batch_skipped=$(basename "$source_file")"
                ;;
        esac
    done

    if [ "$BATCH_SEEN" -eq 0 ]; then
        echo "ERROR: directory is empty: $source_dir" >&2
        return 1
    fi

    echo "batch_files=$BATCH_FILES"
    echo "batch_urls=$BATCH_URLS"
    echo "batch_imported=$BATCH_IMPORTED"
    echo "batch_failed=$BATCH_FAILED"
    echo "batch_skipped=$BATCH_SKIPPED"

    [ "$BATCH_FAILED" -eq 0 ]
}
