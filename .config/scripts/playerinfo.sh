#!/bin/sh

# Checking if anything is playing
if playerctl metadata >/dev/null 2>&1; then
# Getting title of the playing content
song_info=$(playerctl metadata --format '{{ title }}' | tr -d '[:punct:]')
else
# Prinitng when nothing is playing
  song_info="No Audio Playing"
fi

# Printing Output
echo "$song_info"
