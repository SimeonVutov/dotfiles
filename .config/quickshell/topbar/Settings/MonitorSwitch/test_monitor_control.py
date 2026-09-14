import copy
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import monitor_control as control


def monitor(name, x=0, internal=False):
    return dict(name=name, selector=name, description=name, enabled=True, internal=internal,
                width=1920, height=1080, rate=60, scale=1, transform=0, x=x, y=0,
                mirror="none", modes=["1920x1080@60"])


class DisplayTests(unittest.TestCase):
    def setUp(self):
        self.monitors = [monitor("eDP-1", internal=True), monitor("DP-1", 1920), monitor("DP-2", 3840)]
        self.state = dict(monitors=self.monitors, revision="original")
        self.payload = dict(monitors=copy.deepcopy(self.monitors), revision="original", mode="extend")

    def test_valid_layout_and_workspace_distribution(self):
        result = control.validate(self.payload, self.state)
        targets = control.workspace_targets(result)
        self.assertTrue(all(targets[n]["name"] == "eDP-1" for n in range(1, 6)))
        self.assertEqual([targets[n]["name"] for n in range(6, 11)], ["DP-1", "DP-2", "DP-1", "DP-2", "DP-1"])

    def test_mirror_workspaces_stay_on_source(self):
        self.payload["mode"] = "duplicate"
        result = control.validate(self.payload, self.state)
        self.assertEqual(result[1]["mirror"], "eDP-1")
        self.assertTrue(all(m["name"] == "eDP-1" for m in control.workspace_targets(result).values()))

    def test_invalid_requests_are_rejected_before_apply(self):
        variants = []
        for changes in ({"x": 400}, {"x": 9000}, {"rate": float("nan")}, {"rate": 61},
                        {"width": "1920; exec evil"}, {"scale": 1.4}):
            payload = copy.deepcopy(self.payload)
            payload["monitors"][1].update(changes)
            variants.append(payload)
        payload = copy.deepcopy(self.payload)
        payload["revision"] = "stale"
        variants.append(payload)
        payload = copy.deepcopy(self.payload)
        for m in payload["monitors"]:
            m["enabled"] = False
        variants.append(payload)
        for payload in variants:
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                control.validate(payload, self.state)

    def test_verification_tracks_which_screens_are_lit(self):
        live = copy.deepcopy(self.monitors)
        # Hyprland reporting its own rate, scale, position or mirror details
        # must not read as a failed layout.
        live[1].update(rate=59.94, scale=1.25, x=99, mirror="eDP-1", width=1280)
        self.assertEqual(control.lit(self.monitors), control.lit(live))
        live[1]["enabled"] = False
        self.assertNotEqual(control.lit(self.monitors), control.lit(live))

    def test_apply_enables_before_disabling(self):
        self.monitors[0]["enabled"] = False
        with patch.object(control, "hyprctl") as command:
            control.apply_monitors(self.monitors)
        rules = [call.args[-1] for call in command.call_args_list]
        self.assertEqual(len(rules), 3)
        self.assertTrue(rules[-1].endswith(",disable"))
        self.assertFalse(any(rule.endswith(",disable") for rule in rules[:-1]))

    def test_refresh_accepts_unlisted_values_below_the_maximum(self):
        self.payload["monitors"][1]["rate"] = 50
        self.assertEqual(control.validate(self.payload, self.state)[1]["rate"], 50)

    def test_fractional_scale_keeps_shared_edges_exact(self):
        self.payload["monitors"][0]["scale"] = 5 / 6
        self.payload["monitors"][1]["x"] = 2304
        self.payload["monitors"][2]["x"] = 4224
        self.assertEqual(control.dimensions(control.validate(self.payload, self.state)[0]), (2304, 1296))

    def test_mirror_persistence_uses_hardware_identity(self):
        self.monitors[0]["selector"] = "desc:Laptop panel"
        self.monitors[1]["mirror"] = "eDP-1"
        with tempfile.TemporaryDirectory() as directory:
            paths = [Path(directory) / "monitors.conf", Path(directory) / "workspaces.conf"]
            control.persist(self.monitors, control.workspace_targets(self.monitors), paths)
            self.assertIn("mirror,desc:Laptop panel", paths[0].read_text())

    def test_persistence_preserves_disconnected_display_rules(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = [Path(directory) / "monitors.conf", Path(directory) / "workspaces.conf"]
            control.atomic_write(paths[0], "monitor = disconnected,preferred,auto,1\nmonitor = DP-1,disable\n")
            control.persist(self.monitors, control.workspace_targets(self.monitors), paths)
            content = paths[0].read_text()
            self.assertIn("disconnected,preferred,auto,1", content)
            self.assertEqual(content.count("monitor = DP-1,"), 1)
            self.assertEqual(len(paths[1].read_text().splitlines()), 10)

    def transaction(self, reply, failure=False):
        def query(*args, **kwargs):
            if args[0] == "activeworkspace":
                return {"id": 3}
            if args[0] == "workspacerules":
                return [{"workspaceString": str(n), "monitor": m["selector"]}
                        for n, m in control.workspace_targets(self.monitors).items()]
            return []

        with patch.object(control, "discover", return_value=copy.deepcopy(self.state)), \
             patch.object(control, "hyprctl", side_effect=query), \
             patch.object(control, "apply_monitors") as apply, \
             patch.object(control, "wait_for_layout"), \
             patch.object(control, "persist", return_value=[]) as persist, \
             patch.object(control, "emit"), \
             patch.object(control.select, "select", return_value=([True], [], [])), \
             patch.object(control.sys, "stdin", io.StringIO(reply)):
            if failure:
                apply.side_effect = [ValueError("Mode rejected"), None]
                with self.assertRaises(ValueError):
                    control.preview(self.payload)
            else:
                control.preview(self.payload)
            return apply.call_count, persist.call_count

    def test_keep_persists_once(self):
        self.assertEqual(self.transaction("keep\n"), (1, 1))

    def test_cancel_and_ui_exit_restore_without_persisting(self):
        self.assertEqual(self.transaction("revert\n"), (2, 0))
        self.assertEqual(self.transaction(""), (2, 0))

    def test_partial_apply_failure_restores(self):
        self.assertEqual(self.transaction("", failure=True), (2, 0))

    def test_timeout_restores_without_ui_response(self):
        with patch.object(control, "discover", return_value=copy.deepcopy(self.state)), \
             patch.object(control, "hyprctl", side_effect=lambda *a, **kw: {"id": 3} if a[0] == "activeworkspace" else []), \
             patch.object(control, "apply_monitors") as apply, \
             patch.object(control, "wait_for_layout"), \
             patch.object(control, "persist") as persist, \
             patch.object(control, "emit"), \
             patch.object(control.time, "monotonic", side_effect=[0, 16]):
            control.preview(self.payload)
        self.assertEqual(apply.call_count, 2)
        persist.assert_not_called()

    def test_hot_unplug_restores_remaining_screen(self):
        unplugged = dict(monitors=[copy.deepcopy(self.monitors[0])], revision="changed")
        with patch.object(control, "discover", side_effect=[copy.deepcopy(self.state), unplugged, unplugged]), \
             patch.object(control, "hyprctl", side_effect=lambda *a, **kw: {"id": 3} if a[0] == "activeworkspace" else []), \
             patch.object(control, "apply_monitors") as apply, \
             patch.object(control, "wait_for_layout"), \
             patch.object(control, "emit"), \
             patch.object(control.select, "select", return_value=([], [], [])):
            with self.assertRaisesRegex(ValueError, "connected or removed"):
                control.preview(self.payload)
        self.assertEqual([m["name"] for m in apply.call_args.args[0]], ["eDP-1"])


if __name__ == "__main__":
    unittest.main()
