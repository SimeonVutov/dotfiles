"""Run the shared Hyprland display-controller tests from their original location."""

from pathlib import Path
import runpy
import sys
import unittest


helper = Path(__file__).resolve().parents[4] / "scripts/hyprland"
sys.path.insert(0, str(helper))
DisplayTests = runpy.run_path(str(helper / "test_monitor_control.py"))["DisplayTests"]


if __name__ == "__main__":
    unittest.main()
