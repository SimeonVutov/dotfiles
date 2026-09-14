#!/bin/sh
# Fast resident path, matching the session menu. Cold start only as fallback.
# ipc's own -n/--newest targets the most-recently-launched instance; without
# it, a dead record left behind by an earlier restart (Super+Shift+Z) could
# get targeted instead of the live process. Unrelated to qs's top-level -n
# below, which means --no-duplicate there.
qs ipc -n -c topbar call launcher toggle >/dev/null 2>&1 && exit 0
qs -n -d -c topbar || exit 1
i=0
while [ "$i" -lt 60 ]; do
    qs ipc -n -c topbar call launcher open >/dev/null 2>&1 && exit 0
    i=$((i + 1))
    sleep 0.05
done
exit 1
