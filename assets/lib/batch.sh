#!/bin/sh
# Sourced by assets/manager.sh. Do not execute directly.

batch_import_file() {
    batch_file_path="$1"
    batch_file_label="$2"
    echo "batch_source=$batch_file_label"
    if sh "$SELF" import "$batch_file_path"; then
        BATCH_IMPORTED=$((BATCH_IMPORTED + 1))
    else
        BATCH_FAILED=$((BATCH_FAILED + 1))
    fi
}

batch_import_url() {
    batch_url_value="$1"
    batch_url_label="$2"
    batch_url_encoded="$(printf '%s' "$batch_url_value" | base64 | tr -d '\r\n')"
    echo "batch_source=$batch_url_label"
    if sh "$SELF" add "$batch_url_encoded"; then
        BATCH_IMPORTED=$((BATCH_IMPORTED + 1))
    else
        BATCH_FAILED=$((BATCH_FAILED + 1))
    fi
}

batch_import_url_list() {
    batch_list_file="$1"
    batch_list_name="$(basename "$batch_list_file")"
    batch_line_number=0
    exec 3< "$batch_list_file"

    while IFS= read -r batch_raw_line <&3 || [ -n "$batch_raw_line" ]; do
        batch_line_number=$((batch_line_number + 1))
        batch_url="$(printf '%s' "$batch_raw_line" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        case "$batch_url" in
            ''|'#'*) continue ;;
            http://*|https://*)
                BATCH_URLS=$((BATCH_URLS + 1))
                batch_import_url "$batch_url" "$batch_list_name:$batch_line_number"
                ;;
            *)
                echo "ERROR: invalid URL in $batch_list_name:$batch_line_number" >&2
                BATCH_FAILED=$((BATCH_FAILED + 1))
                ;;
        esac
    done
    exec 3<&-
}

import_directory() {
    batch_source_dir="${1:-}"
    [ -n "$batch_source_dir" ] || { echo "ERROR: missing directory path" >&2; return 1; }
    [ -d "$batch_source_dir" ] || { echo "ERROR: directory was not found: $batch_source_dir" >&2; return 1; }

    BATCH_FILES=0
    BATCH_URLS=0
    BATCH_IMPORTED=0
    BATCH_FAILED=0
    BATCH_SKIPPED=0
    BATCH_SEEN=0

    for batch_source_file in "$batch_source_dir"/*; do
        [ -e "$batch_source_file" ] || continue
        [ -f "$batch_source_file" ] || {
            BATCH_SKIPPED=$((BATCH_SKIPPED + 1))
            continue
        }

        BATCH_SEEN=$((BATCH_SEEN + 1))
        batch_lower_name="$(basename "$batch_source_file" | tr '[:upper:]' '[:lower:]')"
        case "$batch_lower_name" in
            *.gif|*.png|*.apng|*.jpg|*.jpeg|*.webp)
                BATCH_FILES=$((BATCH_FILES + 1))
                batch_import_file "$batch_source_file" "$(basename "$batch_source_file")"
                ;;
            *.txt)
                batch_import_url_list "$batch_source_file"
                ;;
            *)
                BATCH_SKIPPED=$((BATCH_SKIPPED + 1))
                echo "batch_skipped=$(basename "$batch_source_file")"
                ;;
        esac
    done

    if [ "$BATCH_SEEN" -eq 0 ]; then
        echo "ERROR: directory is empty: $batch_source_dir" >&2
        return 1
    fi

    echo "batch_files=$BATCH_FILES"
    echo "batch_urls=$BATCH_URLS"
    echo "batch_imported=$BATCH_IMPORTED"
    echo "batch_failed=$BATCH_FAILED"
    echo "batch_skipped=$BATCH_SKIPPED"

    [ "$BATCH_FAILED" -eq 0 ]
}
