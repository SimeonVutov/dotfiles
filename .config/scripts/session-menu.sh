#!/bin/sh
# Toggle the orbital session menu.
#
# The menu lives inside the topbar Quickshell process (always running via
# Hyprland autostart), so the common path here is a bare IPC call and the
# overlay appears at once. If topbar is missing (crashed, or killed by hand),
# start it and retry until it answers.

qs -c topbar ipc call menu toggle >/dev/null 2>&1 && exit 0

qs -n -d -c topbar || exit 1

i=0
while [ "$i" -lt 60 ]; do
    qs -c topbar ipc call menu open >/dev/null 2>&1 && exit 0
    i=$((i + 1))
    sleep 0.05
done

exit 1
