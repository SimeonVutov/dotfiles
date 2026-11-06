#!/bin/sh
set -eu

config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/hypr/conf
umask 077
mkdir -p "$config_dir/monitors" "$config_dir/workspaces"

monitor_file=$config_dir/monitors/current.lua
workspace_file=$config_dir/workspaces/current.lua
if [ ! -e "$monitor_file" ] && [ ! -L "$monitor_file" ]; then
    (set -C; printf 'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })\n' > "$monitor_file")
fi
if [ ! -e "$workspace_file" ] && [ ! -L "$workspace_file" ]; then
    (set -C; : > "$workspace_file")
fi
