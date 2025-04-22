#!/bin/bash

# Set a constant for the max length of the song name
MAX_LENGTH=44

# Initialize variables
shortSong=""
fullSong=""

# Function to replace '&' with 'and'
sanitize_input() {
    echo "$1" | sed 's/&/and/g'  # Replace '&' with 'and'
}

if [[ $(playerctl -l) ]]; then
    fullSong=$(playerctl metadata -f '{{title}} - {{artist}}')

    # Sanitize the fullSong by replacing '&' with 'and'
    fullSong=$(sanitize_input "$fullSong")

    # Truncate the song title for shortSong
    shortSong="$fullSong"
    if [ ${#shortSong} -gt $MAX_LENGTH ]; then
        shortSong=$(echo "$shortSong" | cut -c 1-"$((MAX_LENGTH-3))")"..."  # 3 characters for "..."
    fi
fi

# Output JSON for Waybar (no escaping)
echo "{\"text\":\"$shortSong\", \"tooltip\":\"$fullSong\"}"

