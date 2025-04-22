#!/bin/bash

# Check if playerctl is available
if command -v playerctl &>/dev/null; then
    # Get the current status of the media player, suppressing error messages
    status=$(playerctl status 2>/dev/null)

    # If something is playing, return "ok", otherwise return an empty string
    if [ "$status" == "Playing" ]; then
        printf "ok"  # Music is playing
        exit 0
    else
        printf ""  # Nothing is playing, return empty string
        exit 1
    fi
else
    printf ""  # No media player detected, return empty string
    exit 1
fi
