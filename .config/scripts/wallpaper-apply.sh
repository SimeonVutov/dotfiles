# ~/.config/scripts/wallpaper-apply.sh
#!/usr/bin/env bash
set -euo pipefail

WALLPAPER="${1:-}"
COLOR="${2:-}"
CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}"
CACHE_FILE="${CACHE_DIR}/current_wallpaper"
BLURRED_WALLPAPER="${CACHE_DIR}/blurred_wallpaper.png"
MATUGEN_CACHE="${CACHE_DIR}/matugen"
FRAME_DIR="${CACHE_DIR}/wallpaper_cache/frames"
BLUR="50x30"
TMP_PNG=""
BLURRED_TEMP=""

log() {
    printf '[wallpaper-apply] %s\n' "$*"
}

warn() {
    printf '[wallpaper-apply] WARNING: %s\n' "$*" >&2
}

[[ -n "$WALLPAPER" ]] || { warn "No wallpaper path provided"; exit 1; }
[[ -f "$WALLPAPER" ]] || { warn "Wallpaper does not exist: $WALLPAPER"; exit 1; }

mkdir -p "$CACHE_DIR" "$MATUGEN_CACHE" "$FRAME_DIR"
TMP_PNG=$(mktemp --suffix=.png)
trap 'rm -f -- "$TMP_PNG" "${BLURRED_TEMP:-}"' EXIT

log "Applying wallpaper: $WALLPAPER"
echo "$WALLPAPER" > "$CACHE_FILE"

ext="${WALLPAPER##*.}"
ext="${ext,,}"

is_video=false
case "$ext" in
    mp4|webm|mkv|mov|avi) is_video=true ;;
esac

pkill mpvpaper 2>/dev/null || true

if $is_video; then
    log "Detected video wallpaper; starting mpvpaper"
    mpvpaper -o "no-audio loop hwdec=auto vo=gpu profile=fast" "*" "$WALLPAPER" &
else
    if ! pgrep -x awww-daemon >/dev/null; then
        log "Starting awww-daemon"
        awww-daemon &
        sleep 0.5
    fi

    log "Setting image wallpaper via awww"
    awww img "$WALLPAPER" \
        --transition-type any \
        --transition-duration 1 \
        --transition-fps 240
fi

key=$(printf '%s' "$WALLPAPER" | sha1sum | awk '{print $1}')
frame="$FRAME_DIR/${key}.png"

if $is_video; then
    if [[ ! -f "$frame" ]]; then
        log "No cached frame found for video; extracting one"
        ffmpeg -loglevel error -y -i "$WALLPAPER" -frames:v 1 "$frame" >/dev/null 2>&1
    fi
    cp "$frame" "$TMP_PNG"
else
    log "Preparing image for blur cache / fallback processing"
    if ! magick -- "$WALLPAPER" "$TMP_PNG"; then
        warn "Direct magick read failed; retrying via temporary copy"
        tmp_img="$(mktemp --suffix=.img)"
        cp -- "$WALLPAPER" "$tmp_img"
        magick -- "$tmp_img" "$TMP_PNG"
        rm -f -- "$tmp_img"
    fi
fi

if [[ -n "$COLOR" ]]; then
    log "Running matugen from selected color: $COLOR"
    matugen color hex "$COLOR" --mode dark
else
    log "Running matugen from wallpaper image"
    matugen image "$TMP_PNG" --mode dark
fi

if [[ -f "${MATUGEN_CACHE}/colors-qs.json" ]]; then
    log "Updating quickshell color cache"
    cp "${MATUGEN_CACHE}/colors-qs.json" /tmp/qs_colors.json
fi

for socket in /tmp/kitty-*; do
    kitty @ --to "unix:$socket" set-colors --all --configured \
        "$MATUGEN_CACHE/colors-kitty.conf" 2>/dev/null || true
done

log "Generating blurred wallpaper cache"
BLURRED_TEMP=$(mktemp "${CACHE_DIR}/.blurred-wallpaper.XXXXXX.png")
magick "$TMP_PNG" -resize 75% "$BLURRED_TEMP"
[[ "$BLUR" != "0x0" ]] && magick "$BLURRED_TEMP" -blur "$BLUR" "$BLURRED_TEMP"
# Publish a complete image so a lock screen never reads a partially written PNG.
mv -f -- "$BLURRED_TEMP" "$BLURRED_WALLPAPER"

rm -f "$TMP_PNG"
log "Done"

# Kill quickshell as it is not needed anymore
# !!! IMPORTANT: If we add more functionality in quickshell like top bar, REMOVE THIS LINE
pkill -f "qs -c wallpaper" 2>/dev/null || true
