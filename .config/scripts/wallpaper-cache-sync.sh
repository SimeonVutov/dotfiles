# ~/.config/scripts/wallpaper-cache-sync.sh
#!/usr/bin/env bash
set -euo pipefail

WALLPAPERS_DIR="${HOME}/Wallpapers"
CACHE_ROOT="${HOME}/.cache/wallpaper_cache"
PREVIEW_DIR="${CACHE_ROOT}/previews"
FRAME_DIR="${CACHE_ROOT}/frames"
INDEX_FILE="${CACHE_ROOT}/index.tsv"
TMP_INDEX="${CACHE_ROOT}/index.tsv.tmp"

mkdir -p "$PREVIEW_DIR" "$FRAME_DIR" "$CACHE_ROOT"

log() {
    printf '[wallpaper-cache-sync] %s\n' "$*"
}

warn() {
    printf '[wallpaper-cache-sync] WARNING: %s\n' "$*" >&2
}

is_video_ext() {
    case "${1,,}" in
        mp4|webm|mkv|mov|avi) return 0 ;;
        *) return 1 ;;
    esac
}

make_key() {
    printf '%s' "$1" | sha1sum | awk '{print $1}'
}

needs_regen() {
    local src="$1" out="$2"
    [[ ! -f "$out" ]] && return 0
    [[ "$src" -nt "$out" ]] && return 0
    return 1
}

extract_video_frame() {
    local src="$1" out="$2"

    if ffmpeg -loglevel error -y -ss 1 -i "$src" -frames:v 1 "$out" >/dev/null 2>&1; then
        return 0
    fi

    ffmpeg -loglevel error -y -i "$src" -frames:v 1 "$out" >/dev/null 2>&1
}

make_preview_image() {
    local src="$1" out="$2"

    if ! magick identify -- "$src" >/dev/null 2>&1; then
        warn "ImageMagick cannot identify image: $src"
        return 1
    fi

    if magick -- "$src" \
        -auto-orient \
        -thumbnail '1280x720^' \
        -gravity center \
        -extent 1280x720 \
        "$out"; then
        return 0
    fi

    warn "Direct render failed, retrying via temporary copy: $src"

    local tmp
    tmp="$(mktemp --suffix=.img)"
    cp -- "$src" "$tmp"

    if magick -- "$tmp" \
        -auto-orient \
        -thumbnail '1280x720^' \
        -gravity center \
        -extent 1280x720 \
        "$out"; then
        rm -f -- "$tmp"
        return 0
    fi

    rm -f -- "$tmp"
    warn "Failed to render preview for image: $src"
    return 1
}

make_preview_gif() {
    local src="$1" out="$2"

    if ! magick identify -- "$src" >/dev/null 2>&1; then
        warn "ImageMagick cannot identify gif: $src"
        return 1
    fi

    if magick -- "$src" \
        -coalesce \
        -delete 1--1 \
        -auto-orient \
        -thumbnail '1280x720^' \
        -gravity center \
        -extent 1280x720 \
        "$out"; then
        return 0
    fi

    warn "Failed to render preview for gif: $src"
    return 1
}

make_preview() {
    local src="$1" out="$2"
    local ext="${src##*.}"
    ext="${ext,,}"

    case "$ext" in
        gif) make_preview_gif "$src" "$out" ;;
        *) make_preview_image "$src" "$out" ;;
    esac
}

: > "$TMP_INDEX"
declare -A valid_preview_files=()
declare -A valid_frame_files=()

count=0
regen_count=0
skip_count=0

log "Scanning wallpapers in: $WALLPAPERS_DIR"

while IFS= read -r -d '' src; do
    count=$((count + 1))

    ext="${src##*.}"
    ext="${ext,,}"
    key="$(make_key "$src")"
    preview="${PREVIEW_DIR}/${key}.png"
    frame="${FRAME_DIR}/${key}.png"
    base="$(basename "$src")"

    log "Processing [$count]: $base"

    if is_video_ext "$ext"; then
        if needs_regen "$src" "$frame"; then
            log "Extracting preview frame from video: $base"
            if extract_video_frame "$src" "$frame"; then
                regen_count=$((regen_count + 1))
            else
                warn "Skipping video; failed to extract frame: $src"
                skip_count=$((skip_count + 1))
                continue
            fi
        else
            log "Video frame already up to date: $base"
        fi

        if needs_regen "$src" "$preview"; then
            log "Rendering preview: $(basename "$frame")"
            if make_preview "$frame" "$preview"; then
                regen_count=$((regen_count + 1))
            else
                warn "Skipping video; failed to render preview: $src"
                skip_count=$((skip_count + 1))
                continue
            fi
        else
            log "Preview already up to date: $base"
        fi

        printf '%s\t%s\t%s\t%s\tvideo\n' "$key" "$src" "$preview" "$frame" >> "$TMP_INDEX"
        valid_preview_files["$preview"]=1
        valid_frame_files["$frame"]=1
        log "Done: $base"
    else
        if needs_regen "$src" "$preview"; then
            log "Rendering preview: $base"
            if make_preview "$src" "$preview"; then
                regen_count=$((regen_count + 1))
            else
                warn "Skipping image due to preview failure: $src"
                skip_count=$((skip_count + 1))
                continue
            fi
        else
            log "Preview already up to date: $base"
        fi

        printf '%s\t%s\t%s\t%s\timage\n' "$key" "$src" "$preview" "$src" >> "$TMP_INDEX"
        valid_preview_files["$preview"]=1
        log "Done: $base"
    fi
done < <(
    find "$WALLPAPERS_DIR" -type f \( \
        -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o \
        -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' -o \
        -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o \
        -iname '*.mov' -o -iname '*.avi' \
    \) -print0 | sort -z
)

mv "$TMP_INDEX" "$INDEX_FILE"

find "$PREVIEW_DIR" -type f -name '*.png' -print0 | while IFS= read -r -d '' f; do
    [[ -n "${valid_preview_files[$f]:-}" ]] || rm -f -- "$f"
done

find "$FRAME_DIR" -type f -name '*.png' -print0 | while IFS= read -r -d '' f; do
    [[ -n "${valid_frame_files[$f]:-}" ]] || rm -f -- "$f"
done

log "Finished. Indexed $((count - skip_count)) wallpapers. Regenerated $regen_count cache artifact(s). Skipped $skip_count file(s)."
