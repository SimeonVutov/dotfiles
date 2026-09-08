#!/usr/bin/env bash
# -----------------------------------------------------
# Monitor switcher: pick a resolution / refresh rate
# -----------------------------------------------------
# Rofi menu to change an already-active monitor's mode without touching
# the rest of the layout. Handy for e.g. dropping the laptop panel's
# refresh rate to save battery, then bumping it back up once plugged in.
#
# For layout changes (which monitors are on), use profile-menu.sh.
set -Eeuo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$DIR/config.sh"
source "$DIR/common.sh"

load_monitors

active_names=()
for n in "${MON_NAMES[@]}"; do
    [[ "${MON_DISABLED[$n]}" == "false" ]] && active_names+=("$n")
done

if (( ${#active_names[@]} == 0 )); then
    notify "No active monitors" "Nothing to change."
    exit 1
fi

target=""
if (( ${#active_names[@]} == 1 )); then
    target="${active_names[0]}"
else
    labels=()
    for n in "${active_names[@]}"; do
        labels+=("$(describe_monitor "$n")")
    done
    pick="$(printf '%s\n' "${labels[@]}" | rofi_menu "Which monitor?")"
    [[ -z "$pick" ]] && exit 0
    target="${pick%% —*}"
fi

mode="$(mode_options_for "$target" | rofi_menu "Resolution / refresh for $target")"
[[ -z "$mode" ]] && exit 0

case "$mode" in
"Preferred") res="preferred" ;;
"Custom...")
    res="$(prompt_custom_mode "$target")" || exit 0
    ;;
*) res="$(format_mode "$mode")" ;;
esac

# Keep the monitor's current scale/position/mirror — only the mode changes.
scale="${MON_SCALE[$target]}"
pos="$(current_position_for "$(mon_id "$target")")"
mirror_id=""
[[ "${MON_MIRROR[$target]}" != "none" ]] && mirror_id="$(mon_id "${MON_MIRROR[$target]}")"

apply_monitor "$(monitor_value "$(mon_id "$target")" "$res" "$pos" "$scale" "$mirror_id")"
notify "Resolution / refresh" "$target → $mode"
