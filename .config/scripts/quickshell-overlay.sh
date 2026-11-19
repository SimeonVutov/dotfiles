#!/bin/sh
# Open a full-screen overlay, or close it when it is already open.
#
# Usage: quickshell-overlay.sh launcher|sessionmenu
#
# An overlay is a Quickshell process of its own that exists only while it is
# open: a key press starts it from scratch and it exits when it closes, so it
# holds no memory in between. To get its first frame out quickly, the desktop is
# captured here while the process starts, instead of after it is up.

config="${1:-}"
# The name of each overlay's IPC target.
case "$config" in
    launcher) target=launcher ;;
    sessionmenu) target=menu ;;
    *) exit 2 ;;
esac

runtime="${XDG_RUNTIME_DIR:-/tmp}"
lock="$runtime/quickshell-$config.lock"

if [ "${2:-}" = --run ]; then
    # Holds the lock for as long as the overlay lives.
    monitor=$(hyprctl -j activeworkspace 2>/dev/null | sed -n 's/.*"monitor": *"\([^"]*\)".*/\1/p')
    if [ -n "$monitor" ]; then
        capture="$runtime/quickshell-$config-$$.ppm"
        export QS_OVERLAY_MONITOR="$monitor" QS_OVERLAY_CAPTURE="$capture"
        # The marker comes last, so a snapshot is never read half written.
        (grim -t ppm -o "$monitor" "$capture.part" && mv "$capture.part" "$capture" && : >"$capture.ok") >/dev/null 2>&1 &
    fi

    # The bar closes its own overlays and pauses its animation under this one;
    # the other overlay process, if there is one, closes.
    (qs ipc -n -c topbar call overlays begin "$config" >/dev/null 2>&1 &)
    for other in launcher:launcher sessionmenu:menu; do
        [ "${other%%:*}" = "$config" ] && continue
        (qs ipc -n -c "${other%%:*}" call "${other##*:}" close >/dev/null 2>&1 &)
    done

    # Runs when the overlay ends, however this script is stopped.
    cleanup() {
        (qs ipc -n -c topbar call overlays end "$config" >/dev/null 2>&1 &)
        [ -n "$capture" ] && rm -f -- "$capture" "$capture.part" "$capture.ok"

        # Quickshell leaves its runtime directory (log files, in memory) behind
        # when it exits, and this process starts for every use: remove this
        # launch's own.
        instance=$(readlink "$runtime/quickshell/by-pid/$overlay" 2>/dev/null)
        case "$instance" in
            "$runtime"/quickshell/by-id/?*)
                rm -rf -- "$instance"
                rm -f -- "$runtime/quickshell/by-pid/$overlay" "$runtime"/quickshell/by-shell/*/"${instance##*/}"
                ;;
        esac
    }
    trap cleanup EXIT
    trap 'exit 143' TERM INT HUP

    sh "$(dirname "$0")/quickshell-start.sh" "$config" -n &
    overlay=$!
    wait "$overlay"
    exit $?
fi

attempt=0
while [ "$attempt" -lt 3 ]; do
    # -o: the overlay and the apps it starts do not inherit the lock.
    flock -n -E 11 -o "$lock" sh "$0" "$config" --run
    status=$?
    [ "$status" -ne 11 ] && exit "$status"

    # Already running (or still starting): ask it to close. Its IPC comes up a
    # moment after the process, so retry briefly.
    tries=0
    while [ "$tries" -lt 20 ]; do
        qs ipc -n -c "$config" call "$target" toggle >/dev/null 2>&1 && exit 0
        tries=$((tries + 1))
        sleep 0.03
    done
    # It was on its way out: start a new one.
    attempt=$((attempt + 1))
done

exit 1
