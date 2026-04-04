#!/bin/bash
# Usage: wallpaper-apply.sh <wallpaper> [#hexcolor]
WALLPAPER="$1"
COLOR="$2"
CACHE_FILE="$HOME/.cache/current_wallpaper"
BLURRED_WALLPAPER="$HOME/.cache/blurred_wallpaper.png"
MATUGEN_CACHE="$HOME/.cache/matugen"
BLUR="50x30"
TMP_PNG="/tmp/matugen_input.png"

[[ -z "$WALLPAPER" ]] && { echo "Usage: $0 <wallpaper> [color]"; exit 1; }
[[ ! -f "$WALLPAPER" ]] && { echo "File not found: $WALLPAPER"; exit 1; }

mkdir -p "$MATUGEN_CACHE"
echo "$WALLPAPER" > "$CACHE_FILE"

# -------------------------------------------------------
# Set wallpaper with awww
# -------------------------------------------------------
if ! pgrep -x awww-daemon > /dev/null; then
    awww-daemon &
    sleep 0.5
fi

awww img "$WALLPAPER" \
    --transition-type fade \
    --transition-duration 1.5 \
    --transition-fps 60

# -------------------------------------------------------
# Convert to PNG for matugen (avoids JPEG decode errors)
# -------------------------------------------------------
magick "$WALLPAPER" "$TMP_PNG"

# -------------------------------------------------------
# Generate palette with matugen
# -------------------------------------------------------
echo ":: Running matugen..."
if [[ -n "$COLOR" ]]; then
    sat=$(magick xc:"$COLOR" -colorspace HSL \
        -format "%[fx:p{0,0}.g]" info:)
    scheme=$(awk "BEGIN { print ($sat < 0.2) ? \"scheme-neutral\" : \"scheme-vibrant\" }")

    matugen image "$TMP_PNG" --mode dark \
        --type "$scheme" \
        --fallback-color "$COLOR" \
        --prefer closest-to-fallback
else
    matugen image "$TMP_PNG" --mode dark \
        --type scheme-vibrant \
        --source-color-index 0
fi

# -------------------------------------------------------
# Reload apps
# -------------------------------------------------------
for socket in /tmp/kitty-*; do
    kitty @ --to "unix:$socket" set-colors --all --configured "$MATUGEN_CACHE/colors-kitty.conf" 2>/dev/null
done
hyprctl reload 2>/dev/null
pkill -SIGUSR2 waybar 2>/dev/null

# -------------------------------------------------------
# Blurred wallpaper for hyprlock
# -------------------------------------------------------
echo ":: Generating blurred wallpaper..."
magick "$WALLPAPER" -resize 75% "$BLURRED_WALLPAPER"
[[ "$BLUR" != "0x0" ]] && magick "$BLURRED_WALLPAPER" -blur "$BLUR" "$BLURRED_WALLPAPER"

rm -f "$TMP_PNG"


echo ":: Done — $WALLPAPER applied"
