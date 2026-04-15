#!/usr/bin/env bash
set -euo pipefail

SRC="${1:-}"
TYPE="${2:-image}"
FRAME="${3:-}"

log() {
    printf '[wallpaper-palette] %s\n' "$*" >&2
}

[[ -n "$SRC" ]] || { log "No source provided"; exit 1; }

INPUT="$SRC"
if [[ "$TYPE" == "video" && -n "$FRAME" && -f "$FRAME" ]]; then
    INPUT="$FRAME"
fi

[[ -f "$INPUT" ]] || { log "Input does not exist: $INPUT"; exit 1; }

colors=$(
    magick -- "$INPUT" \
        -resize 200x200^ \
        -gravity center \
        -extent 200x200 \
        -colors 8 \
        -unique-colors \
        txt:- \
    | awk -F'[# ]+' '/^[[:space:]]*[0-9]+,[0-9]+:/ {print "#" toupper($3)}'
)

python3 - <<'PY' "$colors"
import json
import sys

raw = sys.argv[1].splitlines()
seen = []
for c in raw:
    c = c.strip()
    if c and c not in seen:
        seen.append(c)

print(json.dumps(seen[:8]))
PY
