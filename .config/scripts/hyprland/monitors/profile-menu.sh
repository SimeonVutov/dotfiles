#!/usr/bin/env bash
# -----------------------------------------------------
# Monitor switcher: pick a layout
# -----------------------------------------------------
# Rofi menu — Laptop only / External only / Extend / Duplicate. Detects
# whatever is plugged in (no hardcoded monitor names), and lets you pick
# which external, its resolution/refresh rate, and position for Extend.
# Persists to conf/monitors/current.conf + conf/workspaces/current.conf,
# keyed by hardware description (mon_id) so it survives port renames
# across reboots/replugs.
#
# For resolution/refresh only, without changing layout, use mode-menu.sh.
set -Eeuo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$DIR/config.sh"
source "$DIR/common.sh"

load_monitors

# Restored at the end so switching layouts doesn't strand you on a
# leftover/empty workspace instead of the one you were using.
original_active_ws="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty')"

laptop=""
ext_names=()
for n in "${MON_NAMES[@]}"; do
    if [[ "$n" =~ $LAPTOP_NAME_PATTERN ]]; then
        laptop="$n"
    else
        ext_names+=("$n")
    fi
done

if [[ -z "$laptop" ]]; then
    notify "No laptop panel found" "Nothing matched LAPTOP_NAME_PATTERN ($LAPTOP_NAME_PATTERN)."
    exit 1
fi

# Nothing to pick a layout between with just the laptop connected —
# go straight to the resolution/refresh picker instead.
if (( ${#ext_names[@]} == 0 )); then
    notify "Monitor setup" "Only the laptop panel is connected — opening resolution/refresh instead."
    exec "$DIR/mode-menu.sh"
fi

options=("Laptop only" "External only" "Extend (dual monitor)" "Duplicate (mirror laptop)")

choice="$(printf '%s\n' "${options[@]}" | rofi_menu "Monitor setup")"
[[ -z "$choice" ]] && exit 0

pick_external() {
    if (( ${#ext_names[@]} == 1 )); then
        printf '%s' "${ext_names[0]}"
        return 0
    fi
    local labels=() name pick
    for name in "${ext_names[@]}"; do
        labels+=("$(describe_monitor "$name")")
    done
    pick="$(printf '%s\n' "${labels[@]}" | rofi_menu "Which external monitor?")"
    [[ -z "$pick" ]] && return 1
    printf '%s' "${pick%% —*}"
}

pick_mode() {
    local name="$1" pick
    pick="$(mode_options_for "$name" | rofi_menu "Resolution / refresh for $name")"
    [[ -z "$pick" ]] && return 1
    case "$pick" in
        "Preferred") printf 'preferred' ;;
        "Custom...") prompt_custom_mode "$name" ;;
        *) format_mode "$pick" ;;
    esac
}

# Prints one of: right left up down.
pick_position() {
    local pick
    pick="$(printf '%s\n' "Right of laptop" "Left of laptop" "Above laptop" "Below laptop" | rofi_menu "External monitor position")"
    case "$pick" in
        "Right of laptop") printf 'right' ;;
        "Left of laptop")  printf 'left' ;;
        "Above laptop")    printf 'up' ;;
        "Below laptop")    printf 'down' ;;
        *) return 1 ;;
    esac
}

disable_other_externals() {
    local keep="$1" e
    for e in "${ext_names[@]}"; do
        [[ "$e" == "$keep" ]] || apply_monitor "$(disable_value "$(mon_id "$e")")"
    done
}

case "$choice" in
"Laptop only")
    apply_monitor "$(monitor_value "$(mon_id "$laptop")" preferred auto "$DEFAULT_LAPTOP_SCALE")"
    disable_other_externals ""
    apply_workspace_bindings "$(mon_id "$laptop")"
    notify "Monitor setup" "Laptop only"
    ;;

"External only")
    ext="$(pick_external)" || exit 0
    mode="$(pick_mode "$ext")" || exit 0
    apply_monitor "$(disable_value "$(mon_id "$laptop")")"
    apply_monitor "$(monitor_value "$(mon_id "$ext")" "$mode" auto "$DEFAULT_EXTERNAL_SCALE")"
    disable_other_externals "$ext"
    apply_workspace_bindings "$(mon_id "$ext")"
    notify "Monitor setup" "External only: $ext"
    ;;

"Extend (dual monitor)")
    ext="$(pick_external)" || exit 0
    mode="$(pick_mode "$ext")" || exit 0
    pos="$(pick_position)" || exit 0
    # Laptop applied first so it's the reference "auto-$pos" is relative to.
    apply_monitor "$(monitor_value "$(mon_id "$laptop")" preferred auto "$DEFAULT_LAPTOP_SCALE")"
    apply_monitor "$(monitor_value "$(mon_id "$ext")" "$mode" "auto-$pos" "$DEFAULT_EXTERNAL_SCALE")"
    disable_other_externals "$ext"
    apply_workspace_bindings "$(mon_id "$laptop")" "$(mon_id "$ext")"
    notify "Monitor setup" "Extend: laptop + $ext ($pos)"
    ;;

"Duplicate (mirror laptop)")
    ext="$(pick_external)" || exit 0
    mode="$(pick_mode "$ext")" || exit 0
    apply_monitor "$(monitor_value "$(mon_id "$laptop")" preferred auto "$DEFAULT_LAPTOP_SCALE")"
    apply_monitor "$(monitor_value "$(mon_id "$ext")" "$mode" auto "$DEFAULT_EXTERNAL_SCALE" "$(mon_id "$laptop")")"
    disable_other_externals "$ext"
    # A mirrored output can't host its own workspace, so everything
    # stays bound to the laptop.
    apply_workspace_bindings "$(mon_id "$laptop")"
    notify "Monitor setup" "Duplicate: laptop → $ext"
    ;;
esac

[[ -n "$original_active_ws" ]] && hyprctl dispatch workspace "$original_active_ws" >/dev/null 2>&1
restart_waybar
