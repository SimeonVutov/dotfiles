#!/usr/bin/env python3
"""Hyprland display discovery and reversible layout transactions."""

from pathlib import Path
import runpy


if __name__ == "__main__":
    helper = Path(__file__).resolve().parents[4] / "scripts/hyprland/monitor_control.py"
    runpy.run_path(str(helper), run_name="__main__")
