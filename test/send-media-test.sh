#!/bin/sh
set -eu

REPO_DIR="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' 0 INT TERM
FAKE_BIN="$TMP_ROOT/bin"
LOG="$TMP_ROOT/ssh.log"
UPLOAD="$TMP_ROOT/upload.bin"
LOCAL_FILE="$TMP_ROOT/local image.gif"
mkdir -p "$FAKE_BIN"
printf 'personal-media-bytes' > "$LOCAL_FILE"

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
    *"cat > '/tmp/screensaver-playlist-upload-"*) cat > "$SEND_MEDIA_TEST_UPLOAD" ;;
    *" import "*) printf 'added=test\nformat=gif\n' ;;
    *" add "*) printf 'added=url\nformat=gif\n' ;;
    *"rm -f "*) : ;;
esac
SCRIPT
chmod +x "$FAKE_BIN/ssh"

export PATH="$FAKE_BIN:$PATH"
export SEND_MEDIA_TEST_LOG="$LOG"
export SEND_MEDIA_TEST_UPLOAD="$UPLOAD"

if "$REPO_DIR/tools/send-media.sh" "$LOCAL_FILE" >/dev/null 2>&1; then
    echo 'helper accepted a missing host' >&2
    exit 1
fi

"$REPO_DIR/tools/send-media.sh" \
    --host 192.0.2.10 --user root --port 2222 \
    "$LOCAL_FILE" 'https://example.invalid/direct.gif' >/dev/null

cmp "$LOCAL_FILE" "$UPLOAD"
grep '<-p> <2222> <root@192.0.2.10>' "$LOG" >/dev/null
grep "CMD:<sh '.*/manager.sh' import '/tmp/screensaver-playlist-upload-" "$LOG" >/dev/null
grep "CMD:<sh '.*/manager.sh' add '" "$LOG" >/dev/null
grep "CMD:<rm -f '/tmp/screensaver-playlist-upload-" "$LOG" >/dev/null

echo 'send-media helper test passed'
