#!/bin/sh
# Open the wallpaper picker, or close it when it is already open.
exec sh "$(dirname "$0")/quickshell-overlay.sh" wallpaper
