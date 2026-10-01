#!/bin/sh
set -eu

fallback=
for card in /sys/class/drm/card[0-9]*; do
    [ -r "$card/device/vendor" ] || continue
    read -r vendor < "$card/device/vendor"
    [ "$vendor" = 0x1002 ] || continue
    path=$card/device/gpu_busy_percent
    [ -r "$path" ] || continue

    if [ -r "$card/device/boot_vga" ]; then
        read -r boot_vga < "$card/device/boot_vga"
        if [ "$boot_vga" = 1 ]; then
            printf '%s\n' "$path"
            exit 0
        fi
    fi
    [ -n "$fallback" ] || fallback=$path
done

[ -n "$fallback" ] || exit 1
printf '%s\n' "$fallback"
