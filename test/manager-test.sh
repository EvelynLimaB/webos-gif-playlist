#!/bin/sh
set -eu

REPO_DIR="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' 0 INT TERM

DATA_DIR="$TMP_ROOT/data"
INIT_DIR="$TMP_ROOT/init.d"
SCREENSAVER_BASE="$TMP_ROOT/screensaver"
MOUNTS_FILE="$TMP_ROOT/mounts"
FAKE_BIN="$TMP_ROOT/bin"
GIF_FIXTURE="$TMP_ROOT/tiny.gif"
PNG_FIXTURE="$TMP_ROOT/tiny.png"
JPEG_FIXTURE="$TMP_ROOT/tiny.jpg"
WEBP_FIXTURE="$TMP_ROOT/tiny.webp"
BAD_FIXTURE="$TMP_ROOT/not-image.txt"
BAD_PNG_FIXTURE="$TMP_ROOT/bad-ihdr.png"
OVERSIZE_GIF="$TMP_ROOT/oversize.gif"
MANAGER="$REPO_DIR/assets/manager.sh"
TARGET="$SCREENSAVER_BASE/qml/main.qml"

mkdir -p "$SCREENSAVER_BASE/qml" "$INIT_DIR" "$FAKE_BIN"
: > "$TARGET"
: > "$MOUNTS_FILE"

printf 'R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==' | base64 -d > "$GIF_FIXTURE"
printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=' | base64 -d > "$PNG_FIXTURE"

{
    printf '\377\330'
    printf '\377\340\000\020'
    printf 'JFIF\000\001\001\000\000\001\000\001\000\000'
    printf '\377\300\000\021\010\000\001\000\001\003\001\021\000\002\021\000\003\021\000'
    printf '\377\331'
} > "$JPEG_FIXTURE"

{
    printf 'RIFF'
    printf '\022\000\000\000'
    printf 'WEBP'
    printf 'VP8X'
    printf '\012\000\000\000'
    printf '\000\000\000\000'
    printf '\000\000\000\000\000\000'
} > "$WEBP_FIXTURE"

printf 'not an image\n' > "$BAD_FIXTURE"
{
    printf '\211PNG\015\012\032\012'
    printf '\000\000\000\015NOPE'
    printf '\000\000\000\001\000\000\000\001'
} > "$BAD_PNG_FIXTURE"
{
    printf 'GIF89a'
    printf '\201\007\001\000'
    printf '\000\000\000\000'
} > "$OVERSIZE_GIF"

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
    *tiny.gif) cp "$MEDIA_TEST_GIF" "$destination" ;;
    *tiny.png) cp "$MEDIA_TEST_PNG" "$destination" ;;
    *) exit 1 ;;
esac
SCRIPT

cat > "$FAKE_BIN/mount" <<'SCRIPT'
#!/bin/sh
[ "$1" = "--bind" ] || exit 1
printf '%s %s none bind 0 0\n' "$2" "$3" >> "$MEDIA_PLAYLIST_MOUNTS_FILE"
SCRIPT

cat > "$FAKE_BIN/umount" <<'SCRIPT'
#!/bin/sh
target="$1"
tmp="$MEDIA_PLAYLIST_MOUNTS_FILE.tmp.$$"
awk -v target="$target" '$2 != target { print }' "$MEDIA_PLAYLIST_MOUNTS_FILE" > "$tmp"
mv "$tmp" "$MEDIA_PLAYLIST_MOUNTS_FILE"
SCRIPT

cat > "$FAKE_BIN/chmod" <<'SCRIPT'
#!/bin/sh
last=
for argument in "$@"; do
    last="$argument"
done
if [ -n "${MEDIA_TEST_FAIL_CHMOD_PATH:-}" ] && [ "$last" = "$MEDIA_TEST_FAIL_CHMOD_PATH" ]; then
    exit 1
fi
exec /bin/chmod "$@"
SCRIPT
chmod 755 "$FAKE_BIN/wget" "$FAKE_BIN/mount" "$FAKE_BIN/umount" "$FAKE_BIN/chmod"

export PATH="$FAKE_BIN:$PATH"
export MEDIA_TEST_GIF="$GIF_FIXTURE"
export MEDIA_TEST_PNG="$PNG_FIXTURE"
export MEDIA_PLAYLIST_APP_DIR="$REPO_DIR"
export MEDIA_PLAYLIST_DATA_DIR="$DATA_DIR"
export MEDIA_PLAYLIST_INIT_DIR="$INIT_DIR"
export MEDIA_PLAYLIST_SCREENSAVER_BASE="$SCREENSAVER_BASE"
export MEDIA_PLAYLIST_MOUNTS_FILE="$MOUNTS_FILE"

run_manager() {
    sh "$MANAGER" "$@"
}

expect_failure() {
    description="$1"
    shift
    if "$@" >"$TMP_ROOT/failure.out" 2>"$TMP_ROOT/failure.err"; then
        echo "Expected failure: $description" >&2
        exit 1
    fi
}

# Installation initializes data but must not activate or persist the override.
sh "$REPO_DIR/assets/install.sh" >/dev/null
run_manager status | grep 'enabled=no' >/dev/null
run_manager status | grep 'autostart=no' >/dev/null
[ ! -s "$MOUNTS_FILE" ]
[ ! -e "$INIT_DIR/55-gif-playlist" ]

run_manager preflight | grep 'stat=ok' >/dev/null
run_manager preflight | grep 'chmod=ok' >/dev/null
run_manager preflight | grep 'mountsFile=ok' >/dev/null
run_manager preflight | grep 'target=.*qml/main.qml' >/dev/null
run_manager status | grep 'count=0' >/dev/null
run_manager status | grep 'filter=smooth' >/dev/null
run_manager status | grep 'maxItems=24' >/dev/null

# A stale lock must be recoverable.
mkdir -p "$DATA_DIR/.manager-lock"
printf '999999\n' > "$DATA_DIR/.manager-lock/pid"
run_manager generate >/dev/null
[ ! -e "$DATA_DIR/.manager-lock" ]

GIF_URL_B64="$(printf '%s' 'https://example.invalid/tiny.gif' | base64 | tr -d '\r\n')"
PNG_URL_B64="$(printf '%s' 'https://example.invalid/tiny.png' | base64 | tr -d '\r\n')"
run_manager add "$GIF_URL_B64" | grep 'format=gif' >/dev/null
run_manager add "$PNG_URL_B64" | grep 'format=png' >/dev/null
run_manager import "$JPEG_FIXTURE" | grep 'format=jpg' >/dev/null
run_manager import "$WEBP_FIXTURE" | grep 'format=webp' >/dev/null
run_manager status | grep 'count=4' >/dev/null

LIST_OUTPUT="$(run_manager list)"
printf '%s\n' "$LIST_OUTPUT" | grep 'gif' >/dev/null
printf '%s\n' "$LIST_OUTPUT" | grep 'png' >/dev/null
printf '%s\n' "$LIST_OUTPUT" | grep 'jpg' >/dev/null
printf '%s\n' "$LIST_OUTPUT" | grep 'webp' >/dev/null
printf '%s\n' "$LIST_OUTPUT" | grep '1x1' >/dev/null

expect_failure 'unsupported file accepted' run_manager import "$BAD_FIXTURE"
expect_failure 'malformed PNG accepted' run_manager import "$BAD_PNG_FIXTURE"
expect_failure 'oversize GIF accepted' run_manager import "$OVERSIZE_GIF"
expect_failure 'malformed base64 accepted' run_manager add '%%%not-base64%%%'
CONTROL_URL_B64="$(printf 'https://example.invalid/tiny.gif\nextra' | base64 | tr -d '\r\n')"
expect_failure 'URL control character accepted' run_manager add "$CONTROL_URL_B64"
run_manager status | grep 'count=4' >/dev/null

# Failed QML writes must roll back an otherwise valid import.
export MEDIA_TEST_FAIL_CHMOD_PATH="$DATA_DIR/screensaver-runtime.qml"
expect_failure 'failed QML update changed the playlist' run_manager import "$GIF_FIXTURE"
unset MEDIA_TEST_FAIL_CHMOD_PATH
run_manager status | grep 'count=4' >/dev/null
[ "$(run_manager list | wc -l | tr -d ' ')" -eq 4 ]
run_manager generate >/dev/null

run_manager apply | grep 'applied=.*qml/main.qml' >/dev/null
run_manager status | grep 'enabled=yes' >/dev/null
run_manager status | grep 'autostart=no' >/dev/null

RUNTIME="$DATA_DIR/screensaver-runtime.qml"
INODE_BEFORE="$(stat -c '%i' "$RUNTIME")"
run_manager set mode shuffle >/dev/null
run_manager set filter pixel >/dev/null
INODE_AFTER="$(stat -c '%i' "$RUNTIME")"
[ "$INODE_BEFORE" = "$INODE_AFTER" ]
grep 'property bool shuffleEnabled: true' "$RUNTIME" >/dev/null
grep 'smooth: false' "$RUNTIME" >/dev/null
[ "$(grep -c 'errorAdvance.stop();' "$RUNTIME")" -eq 2 ]
grep 'Unable to decode this image' "$RUNTIME" >/dev/null

run_manager enable | grep 'autostart=enabled' >/dev/null
[ -x "$INIT_DIR/55-gif-playlist" ]
if command -v run-parts >/dev/null 2>&1; then
    run-parts --test "$INIT_DIR" | grep '55-gif-playlist' >/dev/null
fi
"$INIT_DIR/55-gif-playlist" >/dev/null
run_manager status | grep 'autostart=yes' >/dev/null

FIRST_ID="$(run_manager list | head -n 1 | cut -f1)"
SECOND_ID="$(run_manager list | sed -n '2p' | cut -f1)"
run_manager move "$SECOND_ID" up >/dev/null
[ "$(run_manager list | head -n 1 | cut -f1)" = "$SECOND_ID" ]
run_manager remove "$FIRST_ID" >/dev/null
run_manager set fit fit >/dev/null
grep 'fillMode: Image.PreserveAspectFit' "$RUNTIME" >/dev/null

run_manager disable | grep disabled >/dev/null
run_manager status | grep 'enabled=no' >/dev/null
[ ! -e "$INIT_DIR/55-gif-playlist" ]

# Foreign bind mounts must never be unmounted or replaced.
printf '/foreign/screensaver.qml %s none bind 0 0\n' "$TARGET" > "$MOUNTS_FILE"
expect_failure 'foreign screensaver mount was replaced' run_manager apply
run_manager disable >/dev/null 2>&1
[ "$(awk 'END { print NR }' "$MOUNTS_FILE")" -eq 1 ]
grep '^/foreign/screensaver.qml ' "$MOUNTS_FILE" >/dev/null
: > "$MOUNTS_FILE"

run_manager reset | grep 'playlist data removed' >/dev/null
[ ! -e "$DATA_DIR" ]

echo 'manager integration test passed'
