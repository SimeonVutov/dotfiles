# ~/.config/scripts/wallpaper-apply.sh
#!/usr/bin/env bash
set -euo pipefail

WALLPAPER="${1:-}"
COLOR="${2:-}"
CACHE_FILE="${HOME}/.cache/current_wallpaper"
BLURRED_WALLPAPER="${HOME}/.cache/blurred_wallpaper.png"
MATUGEN_CACHE="${HOME}/.cache/matugen"
FRAME_DIR="${HOME}/.cache/wallpaper_cache/frames"
BLUR="50x30"
TMP_PNG="/tmp/matugen_input.png"

log() {
    printf '[wallpaper-apply] %s\n' "$*"
}

warn() {
    printf '[wallpaper-apply] WARNING: %s\n' "$*" >&2
}

[[ -n "$WALLPAPER" ]] || { warn "No wallpaper path provided"; exit 1; }
[[ -f "$WALLPAPER" ]] || { warn "Wallpaper does not exist: $WALLPAPER"; exit 1; }

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
        --transition-type fade \
        --transition-duration 1.5 \
        --transition-fps 60
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

hyprctl reload 2>/dev/null || true
pkill -SIGUSR2 waybar 2>/dev/null || true

log "Generating blurred wallpaper cache"
magick "$TMP_PNG" -resize 75% "$BLURRED_WALLPAPER"
[[ "$BLUR" != "0x0" ]] && magick "$BLURRED_WALLPAPER" -blur "$BLUR" "$BLURRED_WALLPAPER"

rm -f "$TMP_PNG"
log "Done"
