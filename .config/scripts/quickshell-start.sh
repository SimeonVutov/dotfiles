#!/bin/sh
case "${1:-}" in
    topbar|wallpaper) ;;
    *) exit 2 ;;
esac
if [ ! -f /usr/share/glvnd/egl_vendor.d/50_mesa.json ]; then
    printf '%s\n' 'Quickshell: Mesa EGL vendor file is missing.' >&2
    exit 1
fi

quickshell_malloc_conf='narenas:2,dirty_decay_ms:1000,muzzy_decay_ms:0'
export MALLOC_CONF="$quickshell_malloc_conf"

if [ "${2:-}" = restart ]; then
    restart_pids=$(qs list -j -c "$1" 2>/dev/null | jq -r '.[] | select(.pid > 0) | .pid' 2>/dev/null)
    for restart_pid in $restart_pids; do
        qs kill --pid "$restart_pid" || exit 1
    done
    restart_attempt=0
    while :; do
        restart_waiting=false
        for restart_pid in $restart_pids; do
            if kill -0 "$restart_pid" 2>/dev/null; then
                restart_waiting=true
            fi
        done
        if [ "$restart_waiting" = false ]; then
            break
        fi
        if [ "$restart_attempt" -ge 100 ]; then
            printf '%s\n' 'Quickshell: the previous instance has not stopped.' >&2
            exit 1
        fi
        restart_attempt=$((restart_attempt + 1))
        sleep 0.02
    done
    exec qs -n -d -c "$1"
fi
config="$1"
shift
exec qs -c "$config" "$@"
