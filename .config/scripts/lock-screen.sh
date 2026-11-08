#!/bin/sh
# Request the independent locker and return only after every output is covered.
if [ "$(qs ipc -n -c lockscreen call lockscreen status 2>/dev/null)" = locked ]; then
    exit 0
fi

sh "$(dirname "$0")/quickshell-start.sh" lockscreen -n -d || exit 1

attempt=0
while [ "$attempt" -lt 100 ]; do
    if qs ipc -n -c lockscreen call lockscreen lock >/dev/null 2>&1; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 0.05
done

attempt=0
while [ "$attempt" -lt 100 ]; do
    if [ "$(qs ipc -n -c lockscreen call lockscreen status 2>/dev/null)" = locked ]; then
        exit 0
    fi
    attempt=$((attempt + 1))
    sleep 0.05
done

printf '%s\n' 'Quickshell: could not confirm that the session is locked.' >&2
exit 1
