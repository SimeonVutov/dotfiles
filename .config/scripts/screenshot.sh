#!/bin/bash
# Area screenshot, copied to the clipboard and saved.
#
# grimblast refuses to start while its lock file exists but never checks
# whether the owning process is still alive, so an abandoned area selection
# (or one interrupted by a display change) wedges every later screenshot
# until the lock is removed by hand.
# Detect a live capture by its workers rather than by name: exact matching on
# those cannot be fooled by another process that merely mentions the lock path.
lock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/grimblast.lock"
if [ -e "$lock" ] && ! pgrep -x slurp >/dev/null 2>&1 && ! pgrep -x grim >/dev/null 2>&1; then
    rm -f "$lock"
fi

directory="$HOME/Pictures/Screenshots"
mkdir -p "$directory"

# Translate the removed layer-rule command used by older grimblast packages.
hyprctl() {
    if [[ "$1" == keyword && "$2" == layerrule && "$3" == 'match:namespace ^selection$, no_anim on' ]]; then
        command hyprctl eval 'hl.layer_rule({ match = { namespace = "^selection$" }, no_anim = true })'
    else
        command hyprctl "$@"
    fi
}
export -f hyprctl

exec grimblast copysave area "$directory/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
