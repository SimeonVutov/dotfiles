#!/bin/sh
set -eu

config_dir=$HOME/.config/hypr/conf
monitor_file=$config_dir/monitors/current.conf
workspace_file=$config_dir/workspaces/current.conf

umask 077
mkdir -p "$config_dir/monitors" "$config_dir/workspaces"

if [ ! -e "$monitor_file" ] && [ ! -L "$monitor_file" ]; then
    (set -C; printf 'monitor = , preferred, auto, 1\n' > "$monitor_file")
fi

if [ ! -e "$workspace_file" ] && [ ! -L "$workspace_file" ]; then
    (set -C; : > "$workspace_file")
fi
