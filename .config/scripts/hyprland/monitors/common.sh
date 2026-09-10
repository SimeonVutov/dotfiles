#!/usr/bin/env bash
# -----------------------------------------------------
# Monitor switcher: shared helpers
# -----------------------------------------------------
# Sourced by profile-menu.sh / mode-menu.sh. Not run directly.
# Expects config.sh to already be sourced.

have() { command -v "$1" >/dev/null 2>&1; }

notify() {
    have notify-send && notify-send -a "Monitor switch" "$1" "${2:-}" || true
}

# Waybar can leave a stale workspace button behind after a layout switch;
# restarting resyncs it (same fix as the manual SUPER SHIFT Z keybind).
restart_waybar() {
    have waybar || return 0
    killall waybar >/dev/null 2>&1
    nohup waybar >/dev/null 2>&1 &
    disown
}

# -----------------------------------------------------
# Monitor detection
# -----------------------------------------------------
declare -A MON_DESC MON_W MON_H MON_HZ MON_SCALE MON_MIRROR MON_DISABLED MON_MODES
MON_NAMES=()

load_monitors() {
    MON_NAMES=()
    local name desc w h hz scale mirror disabled modes
    while IFS=$'\t' read -r name desc w h hz scale mirror disabled modes; do
        [[ -n "$name" ]] || continue
        MON_NAMES+=("$name")
        MON_DESC[$name]="$desc"
        MON_W[$name]="$w"
        MON_H[$name]="$h"
        MON_HZ[$name]="$hz"
        MON_SCALE[$name]="$scale"
        MON_MIRROR[$name]="$mirror"
        MON_DISABLED[$name]="$disabled"
        MON_MODES[$name]="${modes//$'\x1f'/$'\n'}"
    done < <(hyprctl monitors all -j | jq -r '
        .[] | [
            .name, .description, .width, .height, .refreshRate,
            .scale, .mirrorOf, .disabled,
            (.availableModes | join("\u001f"))
        ] | @tsv
    ')
}

# "desc:<hardware description>" — stable across reboots/replugs, unlike
# port names (eDP-1/eDP-2, HDMI-A-1/DP-3).
mon_id() {
    printf 'desc:%s' "${MON_DESC[$1]}"
}

describe_monitor() {
    local name="$1"
    printf '%s — %s (%sx%s@%s)' "$name" "${MON_DESC[$name]}" "${MON_W[$name]}" "${MON_H[$name]}" "${MON_HZ[$name]%.*}"
}

# -----------------------------------------------------
# Resolution / refresh rate
# -----------------------------------------------------

# Sort "WxHxHz" lines by resolution then refresh rate, both descending.
sort_modes() {
    awk -F'[x@]' '{ printf "%d\t%s\t%s\n", ($1*$2), $3, $0 }' | sort -t$'\t' -k1,1nr -k2,2nr | cut -f3-
}

# "Preferred" + "Custom..." (free-typed WxH@Hz) + every mode Hyprland
# reports, sorted. Custom exists because availableModes only lists what
# the EDID enumerates, not everything the panel actually accepts.
mode_options_for() {
    printf 'Preferred\nCustom...\n'
    printf '%s\n' "${MON_MODES[$1]}" | sort_modes
}

format_mode() {
    printf '%s' "${1%Hz}"
}

valid_custom_mode() {
    [[ "$1" =~ ^[0-9]+x[0-9]+@[0-9]+(\.[0-9]+)?$ ]]
}

# Common desktop resolutions offered alongside whatever the monitor itself
# advertises, largest first — covers panels whose EDID under-reports what
# they actually accept (the same reason Custom exists at all).
COMMON_RESOLUTIONS=(3840x2160 3440x1440 2560x1440 2560x1080 1920x1200 1920x1080 1680x1050 1600x900 1366x768 1280x720)

# Fallback refresh rates, used only when the chosen resolution isn't one of
# the monitor's own advertised modes and so has no known rates to offer.
COMMON_REFRESH_RATES=(240 165 144 120 90 75 60)

# Unique WxH values out of a monitor's own advertised modes, largest first.
resolutions_for() {
    printf '%s\n' "${MON_MODES[$1]}" | sed -E 's/@.*$//' | sort -u | \
        awk -F x '{ printf "%d\t%s\n", ($1 * $2), $0 }' | sort -t$'\t' -k1,1nr | cut -f2-
}

# Refresh rates the monitor advertises for one exact WxH, descending.
refreshes_for() {
    printf '%s\n' "${MON_MODES[$1]}" | grep -F "${2}@" | sed -E 's/^[0-9]+x[0-9]+@//; s/Hz$//' | sort -rn -u
}

valid_resolution() {
    [[ "$1" =~ ^[0-9]+x[0-9]+$ ]]
}

valid_refresh() {
    [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$ ]]
}

# -----------------------------------------------------
# Rofi
# -----------------------------------------------------

rofi_menu() {
    local prompt="$1"
    rofi -dmenu -i -p "$prompt" \
        -theme "$ROFI_THEME" \
        -theme-str 'listview { columns: 1; lines: 8; } element { orientation: horizontal; } element-icon { size: 0px; }'
}


# Two steps instead of one free-typed "WIDTHxHEIGHT@REFRESH" string: pick a
# resolution from a list (the monitor's own modes plus common presets), then
# pick a refresh rate for it (the monitor's own known rates for that exact
# resolution, or a curated fallback). rofi's dmenu mode still accepts free
# text typed over the list, so an unlisted resolution or rate still works —
# it's just no longer the only way in.
prompt_custom_mode() {
    local name="$1" res hz known offered=()
    local -A seen=()

    known="$(resolutions_for "$name")"
    while IFS= read -r res; do
        [[ -n "$res" ]] || continue
        offered+=("$res")
        seen[$res]=1
    done <<< "$known"
    for res in "${COMMON_RESOLUTIONS[@]}"; do
        [[ -n "${seen[$res]:-}" ]] || offered+=("$res")
    done

    res="$(printf '%s
' "${offered[@]}" | rofi_menu "Resolution for $name")"
    [[ -z "$res" ]] && return 1
    if ! valid_resolution "$res"; then
        notify "Invalid resolution" "Expected WIDTHxHEIGHT, e.g. 2560x1440. Got: $res"
        return 1
    fi

    known="$(refreshes_for "$name" "$res")"
    [[ -n "$known" ]] || known="$(printf '%s
' "${COMMON_REFRESH_RATES[@]}")"
    hz="$(printf '%s
' "$known" | rofi_menu "Refresh rate for $res")"
    [[ -z "$hz" ]] && return 1
    if ! valid_refresh "$hz"; then
        notify "Invalid refresh rate" "Expected a number, e.g. 144. Got: $hz"
        return 1
    fi

    printf '%s@%s' "$res" "$hz"
}

# -----------------------------------------------------
# Applying monitor / workspace state
# -----------------------------------------------------

current_position_for() {
    local id="$1" line rest pos
    line="$(awk -v key="monitor = ${id}," 'substr($0, 1, length(key)) == key' "$MONITORS_OUT" 2>/dev/null | tail -1)"
    [[ -n "$line" ]] || { printf 'auto'; return; }
    rest="${line#monitor = ${id},}"
    IFS=',' read -r _ pos _ <<< "$rest"
    printf '%s' "${pos:-auto}"
}

# monitor_value ID RESOLUTION POSITION SCALE [MIRROR_OF_ID]
monitor_value() {
    local id="$1" res="$2" pos="$3" scale="$4" mirror="${5:-}"
    if [[ -n "$mirror" ]]; then
        printf '%s,%s,%s,%s,mirror,%s' "$id" "$res" "$pos" "$scale" "$mirror"
    else
        printf '%s,%s,%s,%s' "$id" "$res" "$pos" "$scale"
    fi
}

disable_value() {
    printf '%s,disable' "$1"
}

# Applies live and persists to MONITORS_OUT (one line per monitor id).
apply_monitor() {
    local value="$1"
    local id="${value%%,*}"
    hyprctl keyword monitor "$value" >/dev/null

    mkdir -p "$(dirname "$MONITORS_OUT")"
    touch "$MONITORS_OUT"
    local tmp="${MONITORS_OUT}.tmp"
    awk -v key="monitor = ${id}," 'substr($0, 1, length(key)) != key' "$MONITORS_OUT" > "$tmp"
    printf 'monitor = %s\n' "$value" >> "$tmp"
    mv "$tmp" "$MONITORS_OUT"
}

# Binds workspace numbers to monitor(s), live + persisted, then relocates
# any that already exist elsewhere. One monitor id: everything goes to
# it (single-monitor modes). Two: primary range to the first, secondary
# range to the second (Extend).
apply_workspace_bindings() {
    local primary_id="$1" secondary_id="${2:-}"
    mkdir -p "$(dirname "$WORKSPACES_OUT")"
    : > "$WORKSPACES_OUT"

    local n
    if [[ -n "$secondary_id" ]]; then
        for n in "${WORKSPACES_PRIMARY[@]}"; do
            hyprctl keyword workspace "${n}, monitor:${primary_id}" >/dev/null
            printf 'workspace = %s, monitor:%s\n' "$n" "$primary_id" >> "$WORKSPACES_OUT"
        done
        for n in "${WORKSPACES_SECONDARY[@]}"; do
            hyprctl keyword workspace "${n}, monitor:${secondary_id}" >/dev/null
            printf 'workspace = %s, monitor:%s\n' "$n" "$secondary_id" >> "$WORKSPACES_OUT"
        done
        reconcile_workspace_monitors "$primary_id" "${WORKSPACES_PRIMARY[@]}"
        reconcile_workspace_monitors "$secondary_id" "${WORKSPACES_SECONDARY[@]}"
    else
        for n in "${WORKSPACES_PRIMARY[@]}" "${WORKSPACES_SECONDARY[@]}"; do
            hyprctl keyword workspace "${n}, monitor:${primary_id}" >/dev/null
            printf 'workspace = %s, monitor:%s\n' "$n" "$primary_id" >> "$WORKSPACES_OUT"
        done
        reconcile_workspace_monitors "$primary_id" "${WORKSPACES_PRIMARY[@]}" "${WORKSPACES_SECONDARY[@]}"
    fi
}

# Moves any of the given workspace numbers that already exist but aren't
# on target_id yet — a `monitor:` rule only applies to workspaces created
# from now on, not ones left over from a previous layout.
# reconcile_workspace_monitors TARGET_ID N [N...]
reconcile_workspace_monitors() {
    local target_id="$1"
    shift
    local -A live
    local wid wmon
    while IFS=$'\t' read -r wid wmon; do
        live[$wid]="$wmon"
    done < <(hyprctl workspaces -j | jq -r '.[] | [.id, .monitor] | @tsv')

    local n mon
    for n in "$@"; do
        mon="${live[$n]:-}"
        [[ -n "$mon" ]] || continue
        [[ "$(mon_id "$mon")" == "$target_id" ]] && continue
        hyprctl dispatch moveworkspacetomonitor "${n} ${target_id}" >/dev/null
    done
}
