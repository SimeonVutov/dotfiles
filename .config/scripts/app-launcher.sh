#!/bin/sh
# Fast resident path, matching the session menu. Cold start only as fallback.
qs -c topbar ipc call launcher toggle >/dev/null 2>&1 && exit 0
qs -n -d -c topbar || exit 1
i=0
while [ "$i" -lt 60 ]; do
    qs -c topbar ipc call launcher open >/dev/null 2>&1 && exit 0
    i=$((i + 1))
    sleep 0.05
done
exit 1
