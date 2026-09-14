#!/bin/sh
menu="${1:-monitors}"
case "$menu" in
    monitors) ;;
    *) exit 2 ;;
esac

qs ipc -n -c topbar call settings toggle "$menu" >/dev/null 2>&1 && exit 0
qs -n -d -c topbar || exit 1
attempt=0
while [ "$attempt" -lt 60 ]; do
    qs ipc -n -c topbar call settings open "$menu" >/dev/null 2>&1 && exit 0
    attempt=$((attempt + 1))
    sleep 0.05
done
exit 1
