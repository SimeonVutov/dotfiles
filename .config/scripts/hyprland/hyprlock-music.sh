#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Treat these as Spotify-like players
PREFERRED_PLAYERS=(
  spotify
  spotify_player
  ncspot
  spotify-launcher
  mpv
  vlc
  firefox
  chromium
  brave
  chrome
)

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyprlock-art"
SQUARE_SIZE=1024

BAR_LENGTH=16
BAR_CHAR="━"
BAR_HANDLE="⦿"
COLOR_PLAYED="ffffff99"
COLOR_REMAINING="ffffff30"

# Stable file path used by hyprlock image widget
WIDGET_ART="$CACHE_DIR/music-widget.jpg"
FALLBACK_ART="$CACHE_DIR/music-fallback.jpg"

mkdir -p "$CACHE_DIR"

# ============================================================================
# Helpers
# ============================================================================

have() {
  command -v "$1" >/dev/null 2>&1
}

ensure_fallback_art() {
  if [[ -s "$FALLBACK_ART" ]]; then
    return 0
  fi

  if have convert; then
    convert -size 1024x1024 xc:'#1e1e2e' \
      -fill '#cdd6f4' \
      -gravity center \
      -pointsize 72 \
      -annotate +0+0 '♪' \
      "$FALLBACK_ART" >/dev/null 2>&1 || true
  fi

  # Last-resort empty file copy target
  if [[ ! -s "$FALLBACK_ART" ]]; then
    : > "$FALLBACK_ART"
  fi
}

ensure_widget_art() {
  ensure_fallback_art
  if [[ ! -s "$WIDGET_ART" ]]; then
    cp -f "$FALLBACK_ART" "$WIDGET_ART" 2>/dev/null || true
  fi
}

list_players() {
  have playerctl || return 0
  playerctl -l 2>/dev/null || true
}

is_spotify_like() {
  local p="${1,,}"
  [[ "$p" == spotify* || "$p" == spotify_player* || "$p" == ncspot* || "$p" == spotify-launcher* ]]
}

select_player() {
  have playerctl || {
    printf ''
    return
  }

  local players
  players="$(list_players)"
  [[ -n "$players" ]] || {
    printf ''
    return
  }

  local preferred
  for preferred in "${PREFERRED_PLAYERS[@]}"; do
    while IFS= read -r candidate; do
      [[ -n "$candidate" ]] || continue
      if [[ "$candidate" == "$preferred" || "$candidate" == "$preferred".* ]]; then
        if playerctl -p "$candidate" status >/dev/null 2>&1; then
          printf '%s' "$candidate"
          return
        fi
      fi
    done <<< "$players"
  done

  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    if playerctl -p "$candidate" status >/dev/null 2>&1; then
      printf '%s' "$candidate"
      return
    fi
  done <<< "$players"

  printf ''
}

playerctl_safe() {
  local player="$1"
  shift
  if [[ -n "$player" ]]; then
    playerctl -p "$player" "$@" 2>/dev/null || true
  else
    playerctl "$@" 2>/dev/null || true
  fi
}

get_metadata() {
  local key="$1"
  local player
  player="$(select_player)"
  playerctl_safe "$player" metadata --format "{{ $key }}"
}

get_status() {
  local player
  player="$(select_player)"
  playerctl_safe "$player" status
}

trim_string() {
  local str="${1:-}"
  local max_len="${2:-30}"

  if (( ${#str} <= max_len )); then
    printf '%s' "$str"
  else
    printf '%s…' "${str:0:max_len}"
  fi
}

microseconds_to_mmss() {
  local us="${1:-0}"
  [[ "$us" =~ ^[0-9]+$ ]] || {
    printf '0:00'
    return
  }

  local seconds=$((us / 1000000))
  printf '%d:%02d' $((seconds / 60)) $((seconds % 60))
}

get_track_length() {
  local us
  us="$(get_metadata 'mpris:length')"
  [[ -n "$us" && "$us" != "0" ]] || {
    printf '0:00'
    return
  }
  microseconds_to_mmss "$us"
}

get_current_position() {
  local player us
  player="$(select_player)"

  if [[ -n "$player" ]]; then
    us="$(playerctl -p "$player" position 2>/dev/null | awk '{print int($1 * 1000000)}')" || true
  else
    us="$(playerctl position 2>/dev/null | awk '{print int($1 * 1000000)}')" || true
  fi

  [[ -n "$us" && "$us" != "0" ]] || {
    printf '0:00'
    return
  }
  microseconds_to_mmss "$us"
}

calculate_progress_percent() {
  local player pos_us length_us
  player="$(select_player)"

  if [[ -n "$player" ]]; then
    pos_us="$(playerctl -p "$player" position 2>/dev/null | awk '{print int($1 * 1000000)}')" || true
    length_us="$(playerctl -p "$player" metadata mpris:length 2>/dev/null)" || true
  else
    pos_us="$(playerctl position 2>/dev/null | awk '{print int($1 * 1000000)}')" || true
    length_us="$(playerctl metadata mpris:length 2>/dev/null)" || true
  fi

  if [[ -n "${pos_us:-}" && -n "${length_us:-}" && "$length_us" =~ ^[0-9]+$ && "$length_us" -gt 0 ]]; then
    local percent=$((pos_us * 100 / length_us))
    (( percent > 100 )) && percent=100
    (( percent < 0 )) && percent=0
    printf '%d' "$percent"
  else
    printf '0'
  fi
}

generate_progress_bar() {
  local percent status progress i
  percent="$(calculate_progress_percent)"
  status="$(get_status)"

  if [[ -z "$status" || "$status" == "Stopped" ]]; then
    local empty=""
    for ((i=0; i<BAR_LENGTH; i++)); do
      empty+="$BAR_CHAR"
    done
    printf '<span foreground="#%s">%s</span>' "$COLOR_REMAINING" "$empty"
    return
  fi

  [[ "$percent" -ge 95 ]] && percent=100
  progress=$((percent * BAR_LENGTH / 100))
  (( progress > BAR_LENGTH )) && progress=$BAR_LENGTH
  (( progress < 0 )) && progress=0

  local played="" remaining=""
  for ((i=0; i<progress; i++)); do
    played+="$BAR_CHAR"
  done
  for ((i=progress; i<BAR_LENGTH; i++)); do
    remaining+="$BAR_CHAR"
  done

  if [[ "$progress" -eq "$BAR_LENGTH" ]]; then
    printf '<span foreground="#%s">%s</span><span foreground="#ffffff99">%s</span>' \
      "$COLOR_PLAYED" "$played" "$BAR_HANDLE"
  elif [[ "$progress" -eq 0 ]]; then
    printf '<span foreground="#ffffff99">%s</span><span foreground="#%s">%s</span>' \
      "$BAR_HANDLE" "$COLOR_REMAINING" "$remaining"
  else
    printf '<span foreground="#%s">%s</span><span foreground="#ffffff99">%s</span><span foreground="#%s">%s</span>' \
      "$COLOR_PLAYED" "$played" "$BAR_HANDLE" "$COLOR_REMAINING" "$remaining"
  fi
}

download_to_cache() {
  local url="$1"
  local output="$CACHE_DIR/$(printf '%s' "$url" | sha256sum | awk '{print $1}').img"

  if [[ ! -s "$output" ]]; then
    have curl && curl -fsSL --max-time 5 "$url" -o "$output" >/dev/null 2>&1 || true
  fi

  printf '%s' "$output"
}

create_square_cover() {
  local input="$1"
  local base output
  base="$(basename "$input")"
  output="$CACHE_DIR/${base%.*}_sq_${SQUARE_SIZE}.jpg"

  if [[ -s "$output" && "$output" -nt "$input" ]]; then
    printf '%s' "$output"
    return
  fi

  if have convert; then
    convert "$input" -auto-orient -gravity center \
      -thumbnail "${SQUARE_SIZE}x${SQUARE_SIZE}^" \
      -extent "${SQUARE_SIZE}x${SQUARE_SIZE}" \
      -quality 90 "$output" >/dev/null 2>&1 && {
      printf '%s' "$output"
      return
    }
  fi

  printf '%s' "$input"
}

get_album_art_source() {
  local url local_path
  url="$(get_metadata 'mpris:artUrl')"

  [[ -n "$url" ]] || {
    printf ''
    return
  }

  case "$url" in
    file://*)
      local_path="${url#file://}"
      ;;
    http://*|https://*)
      local_path="$(download_to_cache "$url")"
      ;;
    *)
      printf ''
      return
      ;;
  esac

  [[ -n "$local_path" && -s "$local_path" ]] || {
    printf ''
    return
  }

  create_square_cover "$local_path"
}

refresh_widget_art() {
  ensure_widget_art

  local art
  art="$(get_album_art_source)"

  if [[ -n "$art" && -s "$art" ]]; then
    cp -f "$art" "$WIDGET_ART" 2>/dev/null || true
  else
    cp -f "$FALLBACK_ART" "$WIDGET_ART" 2>/dev/null || true
  fi

  printf '%s\n' "$WIDGET_ART"
}

get_status_icon() {
  case "$(get_status | tr '[:upper:]' '[:lower:]')" in
    playing) printf '󰏤' ;;
    paused)  printf '󰐊' ;;
    *)       printf '󰓛' ;;
  esac
}

get_active_player() {
  local p
  p="$(select_player)"
  printf '%s' "$p"
}

get_player_display() {
  local player
  player="$(get_active_player)"
  local lower="${player,,}"

  if is_spotify_like "$lower"; then
    printf '󰓇  Spotify'
    return
  fi

  case "$lower" in
    firefox*)  printf '󰈹  Firefox' ;;
    chromium*) printf '󰊯  Chromium' ;;
    brave*)    printf '󰞀  Brave' ;;
    chrome*)   printf '󰊯  Chrome' ;;
    mpv*)      printf '󰕼  mpv' ;;
    vlc*)      printf '󰕼  VLC' ;;
    *)         printf '%s' "${player:-No player}" ;;
  esac
}

get_title() {
  local title
  title="$(get_metadata 'xesam:title')"
  printf '%s\n' "$(trim_string "${title:-Nothing Playing}" 29)"
}

get_artist() {
  local artist
  artist="$(get_metadata 'xesam:artist')"
  printf '%s\n' "$(trim_string "${artist:-}" 26)"
}

get_artist_display() {
  local artist
  artist="$(get_artist)"
  if [[ -n "$artist" ]]; then
    printf '󰠃  %s\n' "$artist"
  else
    printf '󰠃  \n'
  fi
}

case "${1:-}" in
  --title)
    get_title
    ;;
  --artist)
    get_artist
    ;;
  --artist-display)
    get_artist_display
    ;;
  --status)
    get_status_icon
    printf '\n'
    ;;
  --length)
    get_track_length
    printf '\n'
    ;;
  --position)
    get_current_position
    printf '\n'
    ;;
  --progress)
    calculate_progress_percent
    printf '\n'
    ;;
  --progress-bar)
    generate_progress_bar
    printf '\n'
    ;;
  --art|--art-refresh)
    refresh_widget_art
    ;;
  --player)
    get_player_display
    printf '\n'
    ;;
  --help|*)
    cat <<EOF
Usage: $(basename "$0") [OPTION]

Options:
  --title
  --artist
  --artist-display
  --status
  --length
  --position
  --progress
  --progress-bar
  --art
  --art-refresh
  --player
EOF
    ;;
esac
