#!/bin/sh
set -eu

REPO_DIR="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' 0 INT TERM

DATA_DIR="$TMP_ROOT/data"
INIT_DIR="$TMP_ROOT/init.d"
SCREENSAVER_BASE="$TMP_ROOT/screensaver"
MOUNTS_FILE="$TMP_ROOT/mounts"
BATCH_DIR="$TMP_ROOT/batch"
BAD_DIR="$TMP_ROOT/bad"
FAKE_BIN="$TMP_ROOT/bin"
MANAGER="$REPO_DIR/assets/manager.sh"

mkdir -p "$SCREENSAVER_BASE/qml" "$INIT_DIR" "$BATCH_DIR" "$BAD_DIR" "$FAKE_BIN"
: > "$SCREENSAVER_BASE/qml/main.qml"
: > "$MOUNTS_FILE"

printf 'R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==' | base64 -d > "$BATCH_DIR/local one.gif"
printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=' | base64 -d > "$BATCH_DIR/local-two.PNG"
printf 'ignore me\n' > "$BATCH_DIR/notes.md"
cat > "$BATCH_DIR/urls.txt" <<'URLS'
# Giphy-style URL list
https://example.invalid/remote-one.gif

https://example.invalid/remote-two.png?token=test
URLS
printf 'not-a-url\n' > "$BAD_DIR/urls.txt"

cat > "$FAKE_BIN/wget" <<'SCRIPT'
#!/bin/sh
destination=
url=
while [ "$#" -gt 0 ]; do
    case "$1" in
        -O) destination="$2"; shift 2 ;;
        -q) shift ;;
        *) url="$1"; shift ;;
    esac
done
case "$url" in
    *remote-one.gif*) cp "$BATCH_TEST_GIF" "$destination" ;;
    *remote-two.png*) cp "$BATCH_TEST_PNG" "$destination" ;;
    *) exit 1 ;;
esac
SCRIPT
chmod +x "$FAKE_BIN/wget"

export PATH="$FAKE_BIN:$PATH"
export BATCH_TEST_GIF="$BATCH_DIR/local one.gif"
export BATCH_TEST_PNG="$BATCH_DIR/local-two.PNG"
export MEDIA_PLAYLIST_APP_DIR="$REPO_DIR"
export MEDIA_PLAYLIST_DATA_DIR="$DATA_DIR"
export MEDIA_PLAYLIST_INIT_DIR="$INIT_DIR"
export MEDIA_PLAYLIST_SCREENSAVER_BASE="$SCREENSAVER_BASE"
export MEDIA_PLAYLIST_MOUNTS_FILE="$MOUNTS_FILE"

OUTPUT="$(sh "$MANAGER" import-dir "$BATCH_DIR")"
printf '%s\n' "$OUTPUT" | grep 'batch_files=2' >/dev/null
printf '%s\n' "$OUTPUT" | grep 'batch_urls=2' >/dev/null
printf '%s\n' "$OUTPUT" | grep 'batch_imported=4' >/dev/null
printf '%s\n' "$OUTPUT" | grep 'batch_failed=0' >/dev/null
printf '%s\n' "$OUTPUT" | grep 'batch_skipped=1' >/dev/null
sh "$MANAGER" status | grep 'count=4' >/dev/null
[ "$(sh "$MANAGER" list | wc -l | tr -d ' ')" -eq 4 ]

if sh "$MANAGER" import-dir "$BAD_DIR" >"$TMP_ROOT/bad.out" 2>"$TMP_ROOT/bad.err"; then
    echo 'invalid URL list unexpectedly succeeded' >&2
    exit 1
fi
grep 'batch_failed=1' "$TMP_ROOT/bad.out" >/dev/null
sh "$MANAGER" status | grep 'count=4' >/dev/null

if sh "$MANAGER" import-dir "$TMP_ROOT/missing" >/dev/null 2>&1; then
    echo 'missing directory unexpectedly succeeded' >&2
    exit 1
fi

echo 'batch import test passed'
