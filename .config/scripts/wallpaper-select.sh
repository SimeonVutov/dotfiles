# ~/.config/scripts/wallpaper-select.sh
#!/usr/bin/env bash
set -euo pipefail

log() {
    printf '[wallpaper-select] %s\n' "$*"
}

toggle_existing() {
    # -n/--newest: without it, "ipc call" targets the OLDEST instance for this
    # config. Quickshell never reaps dead instance records on its own, so a
    # previously killed picker leaves one behind forever — the very next
    # toggle would silently hit that stale husk instead of a live process,
    # fail, and race a second instance into existence from the fallback below.
    qs ipc -n -c wallpaper call wallpaper toggle >/dev/null 2>&1
}

if toggle_existing; then
    log "Toggled existing wallpaper picker"
    exit 0
fi

log "Quickshell wallpaper config not running; starting it"
sh "$(dirname "$0")/quickshell-start.sh" wallpaper >/dev/null 2>&1 &

for _ in $(seq 1 30); do
    if toggle_existing; then
        log "Started quickshell and toggled wallpaper picker"
        exit 0
    fi
    sleep 0.1
done

log "Failed to open wallpaper picker"
exit 1
