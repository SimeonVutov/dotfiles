#!/bin/sh
# Toggle the orbital session menu.
#
# The menu lives inside the topbar Quickshell process (always running via
# Hyprland autostart), so the common path here is a bare IPC call and the
# overlay appears at once. If topbar is missing (crashed, or killed by hand),
# start it and retry until it answers.

# ipc's own -n/--newest targets the most-recently-launched instance; without
# it, a dead record left behind by an earlier restart (Super+Shift+Z) could
# get targeted instead of the live process. Unrelated to qs's top-level -n
# below, which means --no-duplicate there.
qs ipc -n -c topbar call menu toggle >/dev/null 2>&1 && exit 0

sh "$(dirname "$0")/quickshell-start.sh" topbar -n -d || exit 1

i=0
while [ "$i" -lt 60 ]; do
    qs ipc -n -c topbar call menu open >/dev/null 2>&1 && exit 0
    i=$((i + 1))
    sleep 0.05
done

exit 1
