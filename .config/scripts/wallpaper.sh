#!/bin/bash
# ----------------------------------------------------- 
# Set defaults
# ----------------------------------------------------- 
wallpapers_dir="$HOME/Wallpapers"
cache_file="$HOME/.cache/current_wallpaper"
generated_versions="$HOME/.cache/generated_versions"
blurred_wallpaper="$HOME/.cache/blurred_wallpaper.png"
default_wallpaper="$HOME/Wallpapers/default.jpg"
blur="50x30"

if [ ! -f $cache_file ] ;then
    touch $cache_file
fi

if [ ! -f $generated_versions ] ;then
    touch $generated_versions
fi

# Read all wallpapers into an array
mapfile -t wallpapers < <(find "$wallpapers_dir" -type f)

# Check the number of wallpapers
num_wallpapers=${#wallpapers[@]}

# If there's only one wallpaper, return it
if [ "$num_wallpapers" -eq 1 ]; then
    wallpaper="${wallpapers[0]}"
    echo "Selected wallpaper: $wallpaper"
else

# Read the current wallpaper
CURRENT_WALLPAPER=$(cat "$cache_file")

# Find the next wallpaper that is not the current one
for WALLPAPER in "${wallpapers[@]}"; do
    if [ "$WALLPAPER" != "$CURRENT_WALLPAPER" ]; then
        wallpaper="$WALLPAPER"
        break
    fi
done

fi

# # Output the selected wallpaper
echo "Selected wallpaper: $wallpaper"

# ----------------------------------------------------- 
# Copy path of current wallpaper to cache file
# ----------------------------------------------------- 

echo "$wallpaper" > $cache_file
echo ":: Path of current wallpaper copied to $cache_file"

# ----------------------------------------------------- 
# Get wallpaper filename
# ----------------------------------------------------- 
wallpaper_filename=$(echo $wallpaper | awk -F/ '{print $NF}')
echo ":: Wallpaper Filename: $wallpaper_filename"


# ----------------------------------------------------- 
# Execute pywal
# ----------------------------------------------------- 

echo ":: Execute pywal with $wallpaper"
wal -i "$wallpaper"

# ----------------------------------------------------- 
# Write hyprpaper.conf
# -----------------------------------------------------

echo ":: Setting wallpaper with $cache_file"
killall -e hyprpaper & 
sleep 1; 
wal_tpl=$(cat $HOME/dotfiles/.settings/hyprpaper.tpl)
output=${wal_tpl//WALLPAPER/$wallpaper}
echo "$output" > $HOME/.config/hypr/hyprpaper.conf
hyprpaper & > /dev/null 2>&1

# ----------------------------------------------------- 
# Created blurred wallpaper
# -----------------------------------------------------

echo ":: Generate new cached wallpaper blur-$blur-$wallpaper_filename with blur $blur"
magick "$wallpaper" -resize 75% $blurred_wallpaper
echo ":: Resized to 75%"
if [ ! "$blur" == "0x0" ] ;then
    magick $blurred_wallpaper -blur $blur $blurred_wallpaper
    echo ":: Blurred"
fi
