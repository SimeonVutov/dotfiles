#!/bin/bash

CHOICE=$(echo -e "Full Screen\nSelect Region" | rofi -dmenu -p "Screenshot:" -theme ~/.config/rofi/style.rasi)

case "$CHOICE" in
  "Full Screen")
        timestamp=$(date +'%Y-%m-%d_%H-%M-%S') && grim ~/Pictures/screenshot-$timestamp.png && wl-copy --type image/png < ~/Pictures/screenshot-$timestamp.png
    ;;
  "Select Region")
        timestamp=$(date +'%Y-%m-%d_%H-%M-%S') && grim -g "$(slurp)" ~/Pictures/screenshot-$timestamp.png && wl-copy --type image/png < ~/Pictures/screenshot-$timestamp.png
    ;;
  *)
    exit 1
    ;;
esac

