#!/bin/sh
set -eu

REPO_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT INT TERM

DATA_DIR="$TMP_ROOT/data"
INIT_DIR="$TMP_ROOT/init.d"
SCREENSAVER_BASE="$TMP_ROOT/screensaver"
MOUNTS_FILE="$TMP_ROOT/mounts"
FAKE_BIN="$TMP_ROOT/bin"
FIXTURE="$TMP_ROOT/tiny.gif"
MANAGER="$REPO_DIR/assets/manager.sh"

mkdir -p "$SCREENSAVER_BASE/qml" "$INIT_DIR" "$FAKE_BIN"
: > "$SCREENSAVER_BASE/qml/main.qml"
: > "$MOUNTS_FILE"
printf 'R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==' | base64 -d > "$FIXTURE"

cat > "$FAKE_BIN/wget" <<'SCRIPT'
#!/bin/sh
while [ "$#" -gt 0 ]; do
    case "$1" in
        -O) destination="$2"; shift 2 ;;
        *) shift ;;
    esac
done
cp "$GIF_TEST_FIXTURE" "$destination"
SCRIPT

cat > "$FAKE_BIN/mount" <<'SCRIPT'
#!/bin/sh
[ "$1" = "--bind" ] || exit 1
printf '%s %s none bind 0 0\n' "$2" "$3" >> "$GIF_PLAYLIST_MOUNTS_FILE"
SCRIPT

cat > "$FAKE_BIN/umount" <<'SCRIPT'
#!/bin/sh
target="$1"
tmp="$GIF_PLAYLIST_MOUNTS_FILE.tmp.$$"
awk -v target="$target" '$2 != target { print }' "$GIF_PLAYLIST_MOUNTS_FILE" > "$tmp"
mv "$tmp" "$GIF_PLAYLIST_MOUNTS_FILE"
SCRIPT
chmod 755 "$FAKE_BIN/wget" "$FAKE_BIN/mount" "$FAKE_BIN/umount"

export PATH="$FAKE_BIN:$PATH"
export GIF_TEST_FIXTURE="$FIXTURE"
export GIF_PLAYLIST_APP_DIR="$REPO_DIR"
export GIF_PLAYLIST_DATA_DIR="$DATA_DIR"
export GIF_PLAYLIST_INIT_DIR="$INIT_DIR"
export GIF_PLAYLIST_SCREENSAVER_BASE="$SCREENSAVER_BASE"
export GIF_PLAYLIST_MOUNTS_FILE="$MOUNTS_FILE"

run_manager() {
    sh "$MANAGER" "$@"
}

run_manager preflight | grep 'target=.*qml/main.qml' >/dev/null
run_manager init | grep 'count=0' >/dev/null

URL_B64="$(printf '%s' 'https://example.invalid/tiny.gif' | base64 | tr -d '\n')"
run_manager add "$URL_B64" | grep 'dimensions=1x1' >/dev/null
run_manager status | grep 'count=1' >/dev/null

run_manager apply | grep 'applied=.*qml/main.qml' >/dev/null
run_manager status | grep 'enabled=yes' >/dev/null
run_manager status | grep 'autostart=no' >/dev/null

RUNTIME="$DATA_DIR/screensaver-runtime.qml"
INODE_BEFORE="$(stat -c '%i' "$RUNTIME")"
run_manager set mode shuffle >/dev/null
INODE_AFTER="$(stat -c '%i' "$RUNTIME")"
[ "$INODE_BEFORE" = "$INODE_AFTER" ]
grep 'property bool shuffleEnabled: true' "$RUNTIME" >/dev/null

run_manager enable | grep 'autostart=enabled' >/dev/null
[ -x "$INIT_DIR/55-gif-playlist" ]
if command -v run-parts >/dev/null 2>&1; then
    run-parts --test "$INIT_DIR" | grep '55-gif-playlist' >/dev/null
fi
"$INIT_DIR/55-gif-playlist" >/dev/null
run_manager status | grep 'autostart=yes' >/dev/null

sleep 1
run_manager add "$URL_B64" >/dev/null
[ "$(run_manager list | wc -l | tr -d ' ')" -eq 2 ]
SECOND_ID="$(run_manager list | tail -n 1 | cut -f1)"
run_manager move "$SECOND_ID" up >/dev/null
[ "$(run_manager list | head -n 1 | cut -f1)" = "$SECOND_ID" ]
run_manager set fit fit >/dev/null
grep 'fillMode: Image.PreserveAspectFit' "$RUNTIME" >/dev/null

run_manager disable | grep disabled >/dev/null
run_manager status | grep 'enabled=no' >/dev/null
[ ! -e "$INIT_DIR/55-gif-playlist" ]

run_manager reset | grep 'playlist data removed' >/dev/null
[ ! -e "$DATA_DIR" ]

echo 'manager integration test passed'
