#!/bin/sh
# Use the same direct IPC path as SessionMenu. No compositor shortcut query
# or second dispatch needs to finish before the launcher receives the request.
qs ipc -n -c topbar call launcher toggle >/dev/null 2>&1 && exit 0
sh "$(dirname "$0")/quickshell-start.sh" topbar -n -d || exit 1
i=0
while [ "$i" -lt 60 ]; do
    qs ipc -n -c topbar call launcher open >/dev/null 2>&1 && exit 0
    i=$((i + 1))
    sleep 0.05
done
exit 1
