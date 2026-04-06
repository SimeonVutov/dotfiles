#!/bin/bash

CHOICE=$(echo -e "Full Screen\nSelect Region" | rofi -dmenu -p "Screenshot:" -theme ~/.config/rofi/style.rasi)
timestamp=$(date +'%Y-%m-%d_%H-%M-%S')
file="$HOME/Pictures/screenshot-$timestamp.png"

case "$CHOICE" in
  "Full Screen")
    grimblast copysave screen "$file"
    ;;
  "Select Region")
    grimblast copysave area "$file"
    ;;
  *)
    exit 1
    ;;
esac
