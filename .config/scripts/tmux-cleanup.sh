#!/bin/sh

timeout_minutes=${TMUX_CLEANUP_MINUTES:-900}
case "$timeout_minutes" in
    ''|*[!0-9]*) exit 1 ;;
esac
[ "$timeout_minutes" -gt 0 ] || exit 1

tmux list-sessions -F '#{session_id} #{session_attached} #{session_last_attached} #{?@cleanup_minutes,#{@cleanup_minutes},0} #{?@cleanup_attachment,#{@cleanup_attachment},0}' 2>/dev/null |
while read -r session attached last_attached minutes attachment; do
    if [ "$attached" -gt 0 ] || [ "$attachment" != "$last_attached" ]; then
        minutes=0
    else
        case "$minutes" in
            ''|*[!0-9]*) minutes=0 ;;
            *) minutes=$((minutes + 1)) ;;
        esac
    fi

    if [ "$minutes" -ge "$timeout_minutes" ]; then
        # Recheck attachment inside tmux before destroying a session.
        tmux if-shell -t "$session" -F "#{&&:#{==:#{session_attached},0},#{==:#{session_last_attached},$last_attached}}" "kill-session -t $session" 2>/dev/null
    else
        tmux set-option -t "$session" @cleanup_minutes "$minutes" \; \
            set-option -t "$session" @cleanup_attachment "$last_attached" 2>/dev/null
    fi
done
