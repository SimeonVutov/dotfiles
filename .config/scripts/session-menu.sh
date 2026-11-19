#!/bin/sh
# Open the orbital session menu, or close it when it is already open.
exec sh "$(dirname "$0")/quickshell-overlay.sh" sessionmenu
