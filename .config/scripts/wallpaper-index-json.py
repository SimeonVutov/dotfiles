#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

def log(message: str) -> None:
    print(f"[wallpaper-index-json] {message}", file=sys.stderr)

index_file = Path.home() / ".cache" / "wallpaper_cache" / "index.tsv"
current_file = Path.home() / ".cache" / "current_wallpaper"

current = ""
if current_file.exists():
    current = current_file.read_text(encoding="utf-8", errors="ignore").strip()

items = []
if index_file.exists():
    for line in index_file.read_text(encoding="utf-8", errors="ignore").splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) < 5:
            continue
        key, src, preview, frame, media_type = parts[:5]
        items.append(
            {
                "key": key,
                "src": src,
                "preview": preview,
                "frame": frame,
                "type": media_type,
                "name": os.path.basename(src),
                "isCurrent": src == current,
            }
        )

log(f"Loaded {len(items)} item(s)")
print(json.dumps({"items": items, "current": current}, ensure_ascii=False))
