#!/bin/bash
# Tracks how long tmux sessions have been detached (in active minutes)

declare -A detached_time

while true; do
    # Sleep for 60 seconds. This pauses naturally when the laptop sleeps.
    sleep 60

    # If tmux server isn't running, clear the tracker and loop
    if ! tmux ls >/dev/null 2>&1; then
        detached_time=()
        continue
    fi

    # Loop through all sessions and their attached status (0 or 1)
    while read -r s_name s_attached; do
        if [ "$s_attached" -eq 0 ]; then
            # Increment the detached counter by 1 minute
            detached_time["$s_name"]=$(( ${detached_time["$s_name"]:-0} + 1 ))

            # 15 hours = 900 minutes. Destroy if threshold reached.
            if [ "${detached_time["$s_name"]}" -ge 900 ]; then
                tmux kill-session -t "$s_name"
                unset detached_time["$s_name"]
            fi
        else
            # If it's attached, reset the counter to 0
            detached_time["$s_name"]=0
        fi
    done < <(tmux ls -F '#{session_name} #{session_attached}' 2>/dev/null)

    # Housekeeping: Remove deleted sessions from our tracking array
    for s_name in "${!detached_time[@]}"; do
        if ! tmux has-session -t "$s_name" 2>/dev/null; then
            unset detached_time["$s_name"]
        fi
    done
done
