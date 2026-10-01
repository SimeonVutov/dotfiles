#!/bin/sh
# Hyprland reports success even for an unregistered global shortcut.
if launcher_reply=$(hyprctl --batch 'globalshortcuts; dispatch global quickshell-topbar:launcher' 2>/dev/null) &&
    printf '%s\n' "$launcher_reply" | grep -q '^quickshell-topbar:launcher -> '; then
    exit 0
fi

qs ipc -n -c topbar call launcher toggle >/dev/null 2>&1 && exit 0
sh "$(dirname "$0")/quickshell-start.sh" topbar -n -d || exit 1
i=0
while [ "$i" -lt 60 ]; do
    qs ipc -n -c topbar call launcher open >/dev/null 2>&1 && exit 0
    i=$((i + 1))
    sleep 0.05
done
exit 1
