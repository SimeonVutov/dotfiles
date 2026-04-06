# ~/.config/scripts/wallpaper-select.sh
#!/usr/bin/env bash
set -euo pipefail

log() {
    printf '[wallpaper-select] %s\n' "$*"
}

toggle_existing() {
    qs ipc -c wallpaper call wallpaper toggle >/dev/null 2>&1
}

if toggle_existing; then
    log "Toggled existing wallpaper picker"
    exit 0
fi

log "Quickshell wallpaper config not running; starting it"
qs -c wallpaper >/dev/null 2>&1 &

for _ in $(seq 1 30); do
    if toggle_existing; then
        log "Started quickshell and toggled wallpaper picker"
        exit 0
    fi
    sleep 0.1
done

log "Failed to open wallpaper picker"
exit 1
