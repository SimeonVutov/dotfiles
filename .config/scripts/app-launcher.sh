#!/bin/sh
# Open the app launcher, or close it when it is already open.
exec sh "$(dirname "$0")/quickshell-overlay.sh" launcher
