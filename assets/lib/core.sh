#!/bin/sh
# Sourced by assets/manager.sh. Do not execute directly.

release_lock() {
    if [ "$LOCK_HELD" = yes ]; then
        rm -rf "$LOCK_DIR"
        LOCK_HELD=no
    fi
}

acquire_lock() {
    mkdir -p "$DATA_DIR"
    attempts=0

    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        owner_pid="$(cat "$LOCK_PID_FILE" 2>/dev/null || true)"
        case "$owner_pid" in ''|*[!0-9]*) owner_pid= ;; esac

        if [ -z "$owner_pid" ] || ! kill -0 "$owner_pid" 2>/dev/null; then
            rm -rf "$LOCK_DIR"
            continue
        fi

        attempts=$((attempts + 1))
        if [ "$attempts" -ge 15 ]; then
            echo "ERROR: another playlist operation is still running" >&2
            exit 1
        fi
        sleep 1
    done

    printf '%s\n' "$$" > "$LOCK_PID_FILE"
    LOCK_HELD=yes
    trap 'release_lock' 0
    trap 'release_lock; exit 129' HUP
    trap 'release_lock; exit 130' INT
    trap 'release_lock; exit 143' TERM
}

cleanup_temporary_files() {
    mkdir -p "$ITEMS_DIR" "$INIT_DIR"
    rm -f "$ITEMS_DIR"/download-*.part "$ITEMS_DIR"/import-*.part
    rm -f "$DATA_DIR"/*.tmp.* "$INIT_DIR"/55-gif-playlist.tmp.*
}

ensure_data() {
    mkdir -p "$ITEMS_DIR" "$INIT_DIR"
    [ -f "$PLAYLIST_FILE" ] || : > "$PLAYLIST_FILE"
    if [ ! -f "$SETTINGS_FILE" ]; then
        cat > "$SETTINGS_FILE" <<'SETTINGS'
mode=ordered
duration=30000
fit=crop
filter=smooth
SETTINGS
    elif ! grep '^filter=' "$SETTINGS_FILE" >/dev/null 2>&1; then
        printf 'filter=smooth\n' >> "$SETTINGS_FILE"
    fi

    legacy_backup="$DATA_DIR/disabled-hooks"
    if [ -d "$legacy_backup" ]; then
        for backup in "$legacy_backup"/*; do
            [ -e "$backup" ] || [ -L "$backup" ] || continue
            destination="$INIT_DIR/$(basename "$backup")"
            if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
                mv "$backup" "$destination"
            fi
        done
        rmdir "$legacy_backup" 2>/dev/null || true
    fi
}

read_setting() {
    key="$1"
    fallback="$2"
    value="$(sed -n "s/^${key}=//p" "$SETTINGS_FILE" 2>/dev/null | head -n 1)"
    [ -n "$value" ] && printf '%s' "$value" || printf '%s' "$fallback"
}

write_settings() {
    mode="$1"
    duration="$2"
    fit="$3"
    filter="$4"
    tmp="$SETTINGS_FILE.tmp.$$"
    {
        printf 'mode=%s\n' "$mode"
        printf 'duration=%s\n' "$duration"
        printf 'fit=%s\n' "$fit"
        printf 'filter=%s\n' "$filter"
    } > "$tmp" || {
        rm -f "$tmp"
        return 1
    }
    mv "$tmp" "$SETTINGS_FILE"
}

valid_name() {
    case "$1" in
        ''|*[!A-Za-z0-9._-]*) return 1 ;;
        *) return 0 ;;
    esac
}

playlist_count() {
    count=0
    while IFS= read -r name; do
        valid_name "$name" || continue
        [ -f "$ITEMS_DIR/$name" ] || continue
        count=$((count + 1))
    done < "$PLAYLIST_FILE"
    printf '%s' "$count"
}

playlist_total_bytes() {
    total=0
    while IFS= read -r name; do
        valid_name "$name" || continue
        [ -f "$ITEMS_DIR/$name" ] || continue
        bytes="$(wc -c < "$ITEMS_DIR/$name" | tr -d ' ')"
        case "$bytes" in ''|*[!0-9]*) bytes=0 ;; esac
        total=$((total + bytes))
    done < "$PLAYLIST_FILE"
    printf '%s' "$total"
}

detect_target() {
    if [ -f "$MAIN_TARGET" ]; then
        printf '%s' "$MAIN_TARGET"
    elif [ -f "$CLOCK_TARGET" ]; then
        printf '%s' "$CLOCK_TARGET"
    else
        return 1
    fi
}

is_target_mounted() {
    checked_target="$1"
    [ -r "$MOUNTS_FILE" ] || return 1
    awk -v target="$checked_target" '$2 == target { found = 1 } END { exit(found ? 0 : 1) }' "$MOUNTS_FILE"
}

mount_source_for_target() {
    checked_target="$1"
    [ -r "$MOUNTS_FILE" ] || return 1
    awk -v target="$checked_target" '$2 == target { source = $1 } END { if (source != "") print source }' "$MOUNTS_FILE"
}

file_identity() {
    stat -c '%d:%i' "$1" 2>/dev/null
}

is_own_mount() {
    checked_target="$1"
    is_target_mounted "$checked_target" || return 1

    mounted_source="$(mount_source_for_target "$checked_target" 2>/dev/null || true)"
    [ "$mounted_source" = "$RUNTIME_QML" ] && return 0

    [ "$(cat "$ACTIVE_FILE" 2>/dev/null || true)" = "$checked_target" ] || return 1
    [ -f "$RUNTIME_QML" ] || return 1
    source_identity="$(file_identity "$RUNTIME_QML" 2>/dev/null || true)"
    target_identity="$(file_identity "$checked_target" 2>/dev/null || true)"
    [ -n "$source_identity" ] && [ "$source_identity" = "$target_identity" ]
}

ensure_target_available() {
    checked_target="$1"
    if is_target_mounted "$checked_target" && ! is_own_mount "$checked_target"; then
        echo "ERROR: another screensaver override is already mounted at $checked_target" >&2
        echo "Disable that override before applying Screensaver Playlist." >&2
        return 1
    fi
}

write_runtime_file() {
    source_file="$1"
    backup_file="$RUNTIME_QML.backup.$$"
    had_runtime=no

    if [ -f "$RUNTIME_QML" ]; then
        had_runtime=yes
        cp "$RUNTIME_QML" "$backup_file" || return 1
        if ! cat "$source_file" > "$RUNTIME_QML"; then
            cat "$backup_file" > "$RUNTIME_QML" 2>/dev/null || true
            rm -f "$source_file" "$backup_file"
            return 1
        fi
        rm -f "$source_file"
    else
        mv "$source_file" "$RUNTIME_QML" || return 1
    fi

    if ! chmod 644 "$RUNTIME_QML"; then
        if [ "$had_runtime" = yes ]; then
            cat "$backup_file" > "$RUNTIME_QML" 2>/dev/null || true
        else
            rm -f "$RUNTIME_QML"
        fi
        rm -f "$backup_file"
        return 1
    fi

    rm -f "$backup_file"
}

generate_qml() {
    ensure_data
    mode="$(read_setting mode ordered)"
    duration="$(read_setting duration 30000)"
    fit="$(read_setting fit crop)"
    filter="$(read_setting filter smooth)"

    case "$mode" in shuffle) shuffle=true ;; *) shuffle=false ;; esac
    case "$duration" in ''|*[!0-9]*) duration=30000 ;; esac
    [ "$duration" -ge 10000 ] 2>/dev/null || duration=30000
    [ "$duration" -le 300000 ] 2>/dev/null || duration=30000
    case "$fit" in
        fit) fill_mode="Image.PreserveAspectFit" ;;
        stretch) fill_mode="Image.Stretch" ;;
        *) fill_mode="Image.PreserveAspectCrop" ;;
    esac
    case "$filter" in pixel) smooth=false ;; *) smooth=true ;; esac

    tmp="$RUNTIME_QML.tmp.$$"
    if ! cat > "$tmp" <<EOF_QML
// Generated by Screensaver Playlist. Manual edits will be overwritten.
import QtQuick 2.4
import Eos.Window 0.1
import QtQuick.Window 2.2

WebOSWindow {
    id: window
    width: 1920
    height: 1080
    windowType: "_WEBOS_WINDOW_TYPE_SCREENSAVER"
    appId: "com.webos.app.screensaver"
    title: "Screensaver Playlist"
    color: "black"
    visible: true

    property var playlist: [
EOF_QML
    then
        rm -f "$tmp"
        return 1
    fi

    first=yes
    while IFS= read -r name; do
        valid_name "$name" || continue
        [ -f "$ITEMS_DIR/$name" ] || continue
        if [ "$first" = yes ]; then
            first=no
        else
            printf ',\n' >> "$tmp" || {
                rm -f "$tmp"
                return 1
            }
        fi
        printf '        "file://%s/%s"' "$ITEMS_DIR" "$name" >> "$tmp" || {
            rm -f "$tmp"
            return 1
        }
    done < "$PLAYLIST_FILE"

    if ! cat >> "$tmp" <<EOF_QML

    ]
    property int currentIndex: 0
    property bool shuffleEnabled: $shuffle
    property int displayDuration: $duration
    property bool imageFailed: false

    function advance() {
        if (playlist.length < 2) return;
        var nextIndex;
        if (shuffleEnabled) {
            nextIndex = currentIndex;
            while (nextIndex === currentIndex) {
                nextIndex = Math.floor(Math.random() * playlist.length);
            }
        } else {
            nextIndex = (currentIndex + 1) % playlist.length;
        }
        currentIndex = nextIndex;
    }

    Component.onCompleted: {
        if (shuffleEnabled && playlist.length > 1) {
            currentIndex = Math.floor(Math.random() * playlist.length);
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    AnimatedImage {
        id: animation
        anchors.fill: parent
        source: window.playlist.length > 0 ? window.playlist[window.currentIndex] : ""
        fillMode: $fill_mode
        cache: false
        smooth: $smooth
        playing: false

        onSourceChanged: {
            window.imageFailed = false;
            errorAdvance.stop();
        }
        onStatusChanged: {
            // AnimatedImage may set playing=false after a still image. Explicitly
            // restore it whenever a new source reaches Ready so later GIFs animate.
            playing = (status === Image.Ready);
            if (status === Image.Ready) {
                paused = false;
                if (frameCount > 1) {
                    currentFrame = 0;
                }
                window.imageFailed = false;
                errorAdvance.stop();
            } else if (status === Image.Error) {
                window.imageFailed = true;
                if (window.playlist.length > 1) {
                    errorAdvance.restart();
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: window.playlist.length === 0 || window.imageFailed
        color: "#888888"
        font.pixelSize: 42
        text: window.playlist.length === 0 ? "Screensaver playlist is empty" : "Unable to decode this image"
    }

    Timer {
        id: rotation
        interval: window.displayDuration
        running: window.playlist.length > 1
        repeat: true
        onTriggered: window.advance()
    }

    Timer {
        id: errorAdvance
        interval: 2000
        repeat: false
        onTriggered: {
            window.advance();
            rotation.restart();
        }
    }
}
EOF_QML
    then
        rm -f "$tmp"
        return 1
    fi

    write_runtime_file "$tmp"
}

disable_own_mounts() {
    for mount_target in "$MAIN_TARGET" "$CLOCK_TARGET"; do
        if is_target_mounted "$mount_target"; then
            if is_own_mount "$mount_target"; then
                umount "$mount_target" || {
                    echo "ERROR: could not unmount Screensaver Playlist from $mount_target" >&2
                    return 1
                }
            else
                echo "WARNING: leaving foreign screensaver mount untouched: $mount_target" >&2
            fi
        fi
    done
    rm -f "$ACTIVE_FILE"
}

apply_playlist() {
    ensure_data
    generate_qml
    target="$(detect_target)" || {
        echo "ERROR: no supported webOS screensaver target found" >&2
        exit 1
    }

    ensure_target_available "$target"
    disable_own_mounts
    if ! mount --bind "$RUNTIME_QML" "$target"; then
        echo "ERROR: could not bind-mount the generated screensaver" >&2
        exit 1
    fi
    if ! printf '%s\n' "$target" > "$ACTIVE_FILE"; then
        umount "$target" 2>/dev/null || true
        echo "ERROR: could not record the active screensaver target" >&2
        exit 1
    fi
    echo "applied=$target"
}

create_boot_hook() {
    mkdir -p "$INIT_DIR"
    tmp="$INIT_HOOK.tmp.$$"
    if ! cat > "$tmp" <<EOF_HOOK
#!/bin/sh
APP_DIR='$APP_DIR'
MANAGER="\$APP_DIR/assets/manager.sh"
if [ ! -f "\$MANAGER" ]; then
    rm -f "\$0"
    exit 0
fi
exec sh "\$MANAGER" boot
EOF_HOOK
    then
        rm -f "$tmp"
        return 1
    fi
    chmod 755 "$tmp" || { rm -f "$tmp"; return 1; }
    mv "$tmp" "$INIT_HOOK"
}

enable_playlist() {
    apply_playlist
    if ! create_boot_hook; then
        disable_own_mounts >/dev/null 2>&1 || true
        echo "ERROR: could not create the Homebrew startup hook" >&2
        exit 1
    fi
    echo "autostart=enabled"
}

boot_playlist() {
    apply_playlist
}
