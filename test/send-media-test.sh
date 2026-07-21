#!/bin/sh
set -eu

REPO_DIR="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' 0 INT TERM
FAKE_BIN="$TMP_ROOT/bin"
LOG="$TMP_ROOT/ssh.log"
UPLOAD_LOG="$TMP_ROOT/upload.bin"
LOCAL_FILE="$TMP_ROOT/local image.gif"
MEDIA_DIR="$TMP_ROOT/screensaver folder"
mkdir -p "$FAKE_BIN" "$MEDIA_DIR/subdirectory"
printf 'personal-media-bytes' > "$LOCAL_FILE"
printf 'folder-gif-bytes' > "$MEDIA_DIR/01 first.gif"
printf 'folder-png-bytes' > "$MEDIA_DIR/02-second.png"
printf 'oversized-original-bytes' > "$MEDIA_DIR/03-oversized.jpg"
printf 'ignored' > "$MEDIA_DIR/readme.md"
cat > "$MEDIA_DIR/giphy.txt" <<'URLS'
# favorites
https://example.invalid/one.gif

https://example.invalid/two.gif
URLS

cat > "$FAKE_BIN/ssh" <<'SCRIPT'
#!/bin/sh
printf 'ARGS:' >> "$SEND_MEDIA_TEST_LOG"
while [ "$#" -gt 2 ]; do
    printf ' <%s>' "$1" >> "$SEND_MEDIA_TEST_LOG"
    shift
done
remote="$1"
command="$2"
printf ' <%s> CMD:<%s>\n' "$remote" "$command" >> "$SEND_MEDIA_TEST_LOG"
case "$command" in
    *"cat > '/tmp/screensaver-playlist-upload-"*)
        cat >> "$SEND_MEDIA_TEST_UPLOAD"
        printf '\n--UPLOAD--\n' >> "$SEND_MEDIA_TEST_UPLOAD"
        ;;
    *" import "*) printf 'added=test\nformat=gif\n' ;;
    *" add "*) printf 'added=url\nformat=gif\n' ;;
    *"rm -f "*) : ;;
esac
SCRIPT

cat > "$FAKE_BIN/magick" <<'SCRIPT'
#!/bin/sh
if [ "$1" = identify ]; then
    last=
    for argument in "$@"; do
        last="$argument"
    done
    case "$last" in
        *03-oversized.jpg\[0\]) printf '3840 2160\n' ;;
        *webos-media-adapt*\[0\]) printf '1920 1080\n' ;;
        *) printf '100 100\n' ;;
    esac
    exit 0
fi

input="$1"
output=
for argument in "$@"; do
    output="$argument"
done
printf 'adapted-from=%s\n' "$(basename "$input")" > "$output"
SCRIPT
chmod +x "$FAKE_BIN/ssh" "$FAKE_BIN/magick"

export PATH="$FAKE_BIN:$PATH"
export SEND_MEDIA_TEST_LOG="$LOG"
export SEND_MEDIA_TEST_UPLOAD="$UPLOAD_LOG"

if "$REPO_DIR/tools/send-media.sh" "$LOCAL_FILE" >/dev/null 2>&1; then
    echo 'helper accepted a missing host' >&2
    exit 1
fi

SINGLE_OUTPUT="$TMP_ROOT/single.out"
"$REPO_DIR/tools/send-media.sh" \
    --host 192.0.2.10 --user root --port 2222 \
    "$LOCAL_FILE" 'https://example.invalid/direct.gif' > "$SINGLE_OUTPUT"

grep 'source_count=2' "$SINGLE_OUTPUT" >/dev/null
grep 'imported_count=2' "$SINGLE_OUTPUT" >/dev/null
grep 'adapted_count=0' "$SINGLE_OUTPUT" >/dev/null
grep 'failed_count=0' "$SINGLE_OUTPUT" >/dev/null
grep 'personal-media-bytes' "$UPLOAD_LOG" >/dev/null
grep '<-o> <BatchMode=yes>' "$LOG" >/dev/null
grep '<-o> <ConnectTimeout=10>' "$LOG" >/dev/null
grep '<-p> <2222> <root@192.0.2.10>' "$LOG" >/dev/null
grep "CMD:<sh '.*/manager.sh' import '/tmp/screensaver-playlist-upload-" "$LOG" >/dev/null
grep "CMD:<sh '.*/manager.sh' add '" "$LOG" >/dev/null
grep "CMD:<rm -f '/tmp/screensaver-playlist-upload-" "$LOG" >/dev/null

FOLDER_OUTPUT="$TMP_ROOT/folder.out"
"$REPO_DIR/tools/send-media.sh" \
    --host 192.0.2.10 "$MEDIA_DIR" > "$FOLDER_OUTPUT"

grep 'source_count=5' "$FOLDER_OUTPUT" >/dev/null
grep 'imported_count=5' "$FOLDER_OUTPUT" >/dev/null
grep 'adapted_count=1' "$FOLDER_OUTPUT" >/dev/null
grep 'failed_count=0' "$FOLDER_OUTPUT" >/dev/null
grep 'skipped_count=2' "$FOLDER_OUTPUT" >/dev/null
grep 'folder-gif-bytes' "$UPLOAD_LOG" >/dev/null
grep 'folder-png-bytes' "$UPLOAD_LOG" >/dev/null
grep 'adapted-from=03-oversized.jpg' "$UPLOAD_LOG" >/dev/null
if grep 'oversized-original-bytes' "$UPLOAD_LOG" >/dev/null; then
    echo 'helper uploaded the oversized original instead of its adapted copy' >&2
    exit 1
fi
grep 'Adapting oversized media: 03-oversized.jpg (3840x2160 -> fit 1920x1080)' "$FOLDER_OUTPUT" >/dev/null
grep 'adapted_dimensions=1920x1080' "$FOLDER_OUTPUT" >/dev/null
[ "$(grep -c 'Adding URL: giphy.txt:' "$FOLDER_OUTPUT")" -eq 2 ]
[ "$(grep -c "CMD:<sh '.*/manager.sh' add '" "$LOG")" -eq 3 ]

BAD_LIST="$TMP_ROOT/bad.txt"
printf 'not-a-url\n' > "$BAD_LIST"
if "$REPO_DIR/tools/send-media.sh" --host 192.0.2.10 "$BAD_LIST" >/dev/null 2>&1; then
    echo 'helper accepted an invalid URL list' >&2
    exit 1
fi

echo 'send-media helper test passed'
