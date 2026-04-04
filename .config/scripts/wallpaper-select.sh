#!/bin/bash
WALLPAPERS_DIR="$HOME/Wallpapers"
THUMB_DIR="$HOME/.cache/wallpaper-thumbs"
SWATCH_DIR="$HOME/.cache/wallpaper-swatches"
APPLY_SCRIPT="$HOME/.config/scripts/wallpaper-apply.sh"
ROFI_THEME="$HOME/.config/rofi/style.rasi"

mkdir -p "$THUMB_DIR" "$SWATCH_DIR"

# -------------------------------------------------------
# Step 1: Generate thumbnails for all wallpapers
# -------------------------------------------------------
while IFS= read -r -d '' img; do
    name=$(basename "$img")
    thumb="$THUMB_DIR/${name}.png"
    [[ ! -f "$thumb" ]] && magick "$img" -resize 128x128^ -gravity center -extent 128x128 "$thumb"
done < <(find "$WALLPAPERS_DIR" -type f \( \
    -iname "*.jpg" -o -iname "*.jpeg" -o \
    -iname "*.png" -o -iname "*.gif" \) -print0)

# -------------------------------------------------------
# Step 2: Pick wallpaper via rofi
# -------------------------------------------------------
entries=""
while IFS= read -r -d '' img; do
    name=$(basename "$img")
    thumb="$THUMB_DIR/${name}.png"
    entries+="${name}\x00icon\x1f${thumb}\n"
done < <(find "$WALLPAPERS_DIR" -type f \( \
    -iname "*.jpg" -o -iname "*.jpeg" -o \
    -iname "*.png" -o -iname "*.gif" \) -print0 | sort -z)

selected=$(printf "%b" "$entries" | rofi \
    -dmenu \
    -i \
    -p "Wallpaper" \
    -show-icons \
    -theme "$ROFI_THEME" \
    -theme-str 'entry { placeholder: "Search Wallpapers"; }')

[[ -z "$selected" ]] && exit 0
WALLPAPER="$WALLPAPERS_DIR/$selected"

# -------------------------------------------------------
# Step 3: Extract dominant colors
# -------------------------------------------------------
mapfile -t colors < <(magick "$WALLPAPER" \
    -resize 150x150 \
    -colors 8 \
    -format "%c" histogram:info: \
    | sort -rn \
    | grep -oP '#[0-9a-fA-F]{6}' \
    | head -8)

# -------------------------------------------------------
# Step 3.5: Build swatch entries for rofi
# -------------------------------------------------------
color_entries=""
for hex in "${colors[@]}"; do
    swatch="$SWATCH_DIR/${hex//\#/}.png"
    [[ ! -f "$swatch" ]] && magick -size 64x64 xc:"$hex" "$swatch"
    color_entries+="${hex}\x00icon\x1f${swatch}\n"
done

# -------------------------------------------------------
# Step 4: Pick accent color via rofi
# -------------------------------------------------------
selected_color=$(printf "%b" "$color_entries" | rofi \
    -dmenu \
    -i \
    -p "Accent" \
    -show-icons \
    -theme "$ROFI_THEME" \
    -theme-str 'entry { placeholder: "Pick accent color"; } listview { columns: 4; lines: 2; }')

[[ -z "$selected_color" ]] && exit 0

# -------------------------------------------------------
# Step 5: Apply
# -------------------------------------------------------
bash "$APPLY_SCRIPT" "$WALLPAPER" "$selected_color"
