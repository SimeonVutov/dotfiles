#!/bin/sh
# Open the app launcher, or close it when it is already open.
#
# The launcher is a Quickshell process of its own that exists only while it is
# open: a key press starts it from scratch and it exits when it closes, so it
# holds no memory in between. To get its first frame out quickly, the desktop is
# captured here while the process starts, instead of after it is up.

runtime="${XDG_RUNTIME_DIR:-/tmp}"
lock="$runtime/quickshell-launcher.lock"

if [ "${1:-}" = --run ]; then
    # Holds the lock for as long as the launcher lives.
    monitor=$(hyprctl -j activeworkspace 2>/dev/null | sed -n 's/.*"monitor": *"\([^"]*\)".*/\1/p')
    if [ -n "$monitor" ]; then
        capture="$runtime/quickshell-launcher-$$.ppm"
        export QS_LAUNCHER_MONITOR="$monitor" QS_LAUNCHER_CAPTURE="$capture"
        # The marker comes last, so a snapshot is never read half written.
        (grim -t ppm -o "$monitor" "$capture.part" && mv "$capture.part" "$capture" && : >"$capture.ok") >/dev/null 2>&1 &
    fi

    # The session menu and settings live in the topbar's process; send them away.
    (qs ipc -n -c topbar call overlays dismiss >/dev/null 2>&1 &)

    sh "$(dirname "$0")/quickshell-start.sh" launcher -n &
    launcher=$!
    wait "$launcher"
    status=$?
    [ -n "$capture" ] && rm -f -- "$capture" "$capture.part" "$capture.ok"

    # Quickshell leaves its runtime directory (log files, in memory) behind when
    # it exits, and this process starts for every use: remove this launch's own.
    instance=$(readlink "$runtime/quickshell/by-pid/$launcher" 2>/dev/null)
    case "$instance" in
        "$runtime"/quickshell/by-id/?*)
            rm -rf -- "$instance"
            rm -f -- "$runtime/quickshell/by-pid/$launcher" "$runtime"/quickshell/by-shell/*/"${instance##*/}"
            ;;
    esac
    exit "$status"
fi

attempt=0
while [ "$attempt" -lt 3 ]; do
    # -o: the launcher and the apps it starts do not inherit the lock.
    flock -n -E 11 -o "$lock" sh "$0" --run
    status=$?
    [ "$status" -ne 11 ] && exit "$status"

    # Already running (or still starting): ask it to close. Its IPC comes up a
    # moment after the process, so retry briefly.
    tries=0
    while [ "$tries" -lt 20 ]; do
        qs ipc -n -c launcher call launcher toggle >/dev/null 2>&1 && exit 0
        tries=$((tries + 1))
        sleep 0.03
    done
    # It was on its way out: start a new one.
    attempt=$((attempt + 1))
done

exit 1
