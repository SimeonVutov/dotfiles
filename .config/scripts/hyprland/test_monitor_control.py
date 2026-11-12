import copy
import io
import json
from pathlib import Path
import re
import tempfile
import subprocess
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

    def test_requested_order_assigns_main_workspaces_without_moving_displays(self):
        self.payload["monitors"] = [self.payload["monitors"][1], self.payload["monitors"][0], self.payload["monitors"][2]]
        result = control.validate(self.payload, self.state)
        targets = control.workspace_targets(result)
        self.assertTrue(all(targets[n]["name"] == "DP-1" for n in range(1, 6)))
        self.assertEqual([m["x"] for m in result], [1920, 0, 3840])

    def test_orders_are_remembered_per_connected_setup(self):
        laptop, x, y = self.monitors
        with tempfile.TemporaryDirectory() as directory:
            paths = [Path(directory) / "monitors.lua", Path(directory) / "workspaces.lua"]
            for setup in ([x, laptop], [y, laptop]):
                control.persist(setup, control.workspace_targets(setup), paths)
            for setup, expected in (([laptop, x], [x, laptop]), ([laptop, y], [y, laptop]),
                                    ([laptop, x, y], [laptop, x, y]), ([laptop], [laptop])):
                restored = control.restore_order(setup, paths[0])
                self.assertEqual([m["name"] for m in restored], [m["name"] for m in expected])
            combined = [y, x, laptop]
            control.persist(combined, control.workspace_targets(combined), paths)
            self.assertEqual(control.restore_order([laptop, x, y], paths[0]), combined)
            self.assertEqual(control.restore_order([laptop, x], paths[0]), [x, laptop])

    def test_unknown_hardware_and_invalid_order_use_default(self):
        laptop, external = self.monitors[:2]
        original = [dict(external, identity="screen-X"), dict(laptop, identity="laptop")]
        replacement = [dict(laptop, identity="laptop"), dict(external, identity="screen-Y")]
        with tempfile.TemporaryDirectory() as directory:
            paths = [Path(directory) / "monitors.lua", Path(directory) / "workspaces.lua"]
            control.persist(original, control.workspace_targets(original), paths)
            self.assertEqual(control.restore_order(replacement, paths[0]), replacement)
            paths[0].write_text(control.ORDER_PREFIX + '["laptop", "laptop"]\n'
                                + control.ORDER_PREFIX + '{"invalid": true}\n')
            self.assertEqual(control.restore_order(replacement, paths[0]), replacement)

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
        with patch.object(control, "hyprctl") as command, \
             patch.object(control, "discover", return_value=self.state):
            control.apply_monitors(self.monitors, self.monitors)
        rules = [call.args[-1] for call in command.call_args_list]
        self.assertEqual(len(rules), 3)
        self.assertIn("disabled = true", rules[-1])
        self.assertFalse(any("disabled = true" in rule for rule in rules[:-1]))
        self.assertTrue(all(call.args[0] == "eval" for call in command.call_args_list))

    def test_apply_parks_a_screen_before_enabling_its_replacement(self):
        current = [monitor("eDP-1", internal=True), dict(monitor("DP-2"), enabled=False)]
        target = [dict(current[0], enabled=False), dict(current[1], enabled=True)]
        with patch.object(control, "hyprctl") as command, \
             patch.object(control, "discover", return_value={"monitors": target}):
            control.apply_monitors(target, current)
        rules = [call.args[-1] for call in command.call_args_list]
        self.assertEqual(len(rules), 3)
        self.assertIn('output = "eDP-1", disabled = false, mode = "1920x1080@60", position = "1921x0"', rules[0])
        self.assertIn('output = "DP-2", disabled = false, mode = "1920x1080@60", position = "0x0"', rules[1])
        self.assertEqual(rules[2], 'hl.monitor({ output = "eDP-1", disabled = true })')

    def test_laptop_only_clears_the_previous_disabled_flag(self):
        current = copy.deepcopy(self.monitors)
        current[0]["enabled"] = False
        target = [dict(m, enabled=m["internal"]) for m in current]
        live = {m["name"]: dict(m) for m in current}
        observed_replacement = False

        def query(*args, **kwargs):
            nonlocal observed_replacement
            if args[0] == "monitors":
                observed_replacement = live["eDP-1"]["enabled"]
                return [dict(m, id=i, disabled=not m["enabled"], refreshRate=m["rate"],
                             availableModes=m["modes"]) for i, m in enumerate(live.values())]
            self.assertEqual(args[0], "eval")
            rule = args[1]
            name = json.loads(re.search(r'output = ("[^"]+")', rule)[1])
            disabled = re.search(r'disabled = (true|false)', rule)
            # Reproduce hl.monitor's merge behavior: omitted fields retain their value.
            if disabled:
                if disabled[1] == "true":
                    self.assertTrue(observed_replacement)
                live[name]["enabled"] = disabled[1] == "false"
            self.assertTrue(any(m["enabled"] for m in live.values()))
            return "ok"

        with patch.object(control, "hyprctl", side_effect=query):
            control.apply_monitors(target, current)
        self.assertEqual(control.lit(live.values()), {"eDP-1"})

    def test_failed_replacement_never_disables_the_previous_displays(self):
        current = copy.deepcopy(self.monitors)
        current[0]["enabled"] = False
        target = [dict(m, enabled=m["internal"]) for m in current]
        with patch.object(control, "hyprctl") as command, \
             patch.object(control, "discover", return_value={"monitors": current}), \
             patch.object(control.time, "monotonic", side_effect=[0, 0, 6]), \
             patch.object(control.time, "sleep"):
            with self.assertRaisesRegex(ValueError, "Replacement displays did not become active"):
                control.apply_monitors(target, current)
        self.assertFalse(any("disabled = true" in call.args[-1] for call in command.call_args_list))

    def test_replacement_waits_for_asynchronous_enable(self):
        pending = [dict(monitor("eDP-1", internal=True), enabled=False), monitor("DP-1")]
        ready = [dict(pending[0], enabled=True), pending[1]]
        with patch.object(control, "discover", side_effect=[{"monitors": pending}, {"monitors": ready}]) as discover, \
             patch.object(control.time, "sleep") as sleep:
            control.wait_for_enabled([ready[0]])
        self.assertEqual(discover.call_count, 2)
        sleep.assert_called_once_with(.1)

    def test_preview_binds_workspaces_so_no_screen_is_left_without_one(self):
        laptop_only = [dict(m, enabled=m["name"] == "eDP-1") for m in self.monitors]
        with patch.object(control, "hyprctl") as command:
            control.bind_workspaces(control.workspace_targets(laptop_only))
        bound = [call.args[-1] for call in command.call_args_list]
        self.assertEqual(len(bound), 10)
        self.assertTrue(all('monitor = "eDP-1"' in rule for rule in bound))

    def test_revert_restores_the_previous_workspace_rules(self):
        with patch.object(control, "hyprctl") as command:
            control.rebind_workspaces([
                {"workspaceString": "1", "monitor": "desc:Some Screen"},
                {"workspaceString": "special:magic", "monitor": "eDP-1"},
                {"workspaceString": "2", "monitor": ""},
            ])
        restored = [call.args[-1] for call in command.call_args_list]
        self.assertEqual(restored, ['hl.workspace_rule({ workspace = "1", monitor = "desc:Some Screen" })'])

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
            paths = [Path(directory) / "monitors.lua", Path(directory) / "workspaces.lua"]
            control.persist(self.monitors, control.workspace_targets(self.monitors), paths)
            self.assertIn('mirror = "desc:Laptop panel"', paths[0].read_text())

    def test_persistence_preserves_disconnected_display_rules(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = [Path(directory) / "monitors.lua", Path(directory) / "workspaces.lua"]
            disconnected = control.saved_monitor_rule(monitor("disconnected"))
            old_rule = control.saved_monitor_rule(dict(monitor("DP-1"), enabled=False))
            control.atomic_write(paths[0], disconnected + "\n" + old_rule + "\n")
            control.persist(self.monitors, control.workspace_targets(self.monitors), paths)
            content = paths[0].read_text()
            self.assertIn(disconnected, content)
            self.assertEqual(content.count('hl.monitor({ output = "DP-1",'), 1)
            self.assertEqual(len(paths[1].read_text().splitlines()), 10)
            control.persist(self.monitors, control.workspace_targets(self.monitors), paths)
            self.assertEqual(paths[0].read_text(), content)

    def test_non_numbered_workspaces_do_not_break_moves_or_recovery(self):
        workspaces = [{"id": 1, "monitor": "eDP-1"},
                      {"address": "special:magic", "type": "special", "monitor": "eDP-1"},
                      {"address": "coding", "type": "normal", "monitor": "eDP-1"}]
        with patch.object(control, "hyprctl") as command:
            control.relocate(workspaces, {1: "DP-1"}, 1)
        self.assertEqual([call.args for call in command.call_args_list], [
            ("dispatch", 'hl.dsp.workspace.move({ workspace = "1", monitor = "DP-1" })'),
            ("dispatch", 'hl.dsp.focus({ workspace = "1" })'),
        ])
        self.transaction("revert\n", workspaces=workspaces)

    def test_discovery_normalizes_mirror_ids_to_connectors(self):
        outputs = [dict(self.monitors[0], id=0, mirrorOf="none", refreshRate=60, availableModes=[]),
                   dict(self.monitors[1], id=1, mirrorOf="0", refreshRate=60, availableModes=[])]
        with patch.object(control, "hyprctl", return_value=outputs):
            state = control.discover()
        self.assertEqual(state["monitors"][1]["mirror"], "eDP-1")

    def test_lua_quoting_preserves_literal_selector_content(self):
        value = 'desc:Écran "quoted" \\u1234\n\x00'
        encoded = control.lua_string(value)
        result = subprocess.run(["lua", "-"], input="io.write(" + encoded + ")", text=True,
                                capture_output=True, check=True)
        self.assertEqual(result.stdout, value)
        rule = control.monitor_rule(dict(self.monitors[0], selector=value))
        self.assertIn(encoded, rule)

    def test_eval_error_is_not_treated_as_a_successful_process(self):
        result = subprocess.CompletedProcess([], 0, "error: invalid monitor", "")
        with patch.object(control.subprocess, "run", return_value=result):
            with self.assertRaisesRegex(ValueError, "invalid monitor"):
                control.hyprctl("eval", 'hl.monitor({})')



    def test_invalid_reload_reverts_saved_configuration(self):
        errors = iter(["", "invalid Lua"])

        def query(*args, **kwargs):
            if args[0] == "configerrors":
                return next(errors)
            return {"activeworkspace": {"id": 3}, "workspacerules": [], "workspaces": [],
                    }.get(args[0], "ok")

        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory) / "hypr/conf"
            paths = [base / "monitors/current.lua", base / "workspaces/current.lua"]
            originals = ['hl.monitor({ output = "", mode = "preferred" })\n', "-- original workspace rules\n"]
            for path, content in zip(paths, originals):
                control.atomic_write(path, content)
            with patch.dict(control.os.environ, {"XDG_CONFIG_HOME": directory}), \
                 patch.object(control, "discover", return_value=copy.deepcopy(self.state)), \
                 patch.object(control, "hyprctl", side_effect=query) as command, \
                 patch.object(control, "apply_monitors") as apply, \
                 patch.object(control, "wait_for_layout"), \
                 patch.object(control, "emit"), \
                 patch.object(control.select, "select", return_value=([True], [], [])), \
                 patch.object(control.sys, "stdin", io.StringIO("keep\n")):
                with self.assertRaisesRegex(ValueError, "Saved display configuration has errors"):
                    control.preview(self.payload)
            self.assertEqual([path.read_text() for path in paths], originals)
            self.assertEqual(apply.call_count, 2)
            self.assertEqual(sum(call.args == ("reload",) for call in command.call_args_list), 2)

    def test_existing_unrelated_config_error_does_not_prevent_keeping_a_layout(self):
        self.assertEqual(self.transaction("keep\n", configerrors='Unknown keysym: "XF86Lock"'), (1, 1))

    def transaction(self, reply, failure=False, workspaces=None, configerrors=""):
        def query(*args, **kwargs):
            if args[0] == "activeworkspace":
                return {"id": 3}
            if args[0] == "workspacerules":
                return [{"workspaceString": str(n), "monitor": m["selector"]}
                        for n, m in control.workspace_targets(self.monitors).items()]
            if args[0] == "configerrors":
                return configerrors
            if args[0] == "workspaces" and workspaces is not None:
                return workspaces
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
             patch.object(control, "hyprctl", side_effect=lambda *a, **kw: {"activeworkspace": {"id": 3}, "configerrors": ""}.get(a[0], [])), \
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
             patch.object(control, "hyprctl", side_effect=lambda *a, **kw: {"activeworkspace": {"id": 3}, "configerrors": ""}.get(a[0], [])), \
             patch.object(control, "apply_monitors") as apply, \
             patch.object(control, "wait_for_layout"), \
             patch.object(control, "emit"), \
             patch.object(control.select, "select", return_value=([], [], [])):
            with self.assertRaisesRegex(ValueError, "connected or removed"):
                control.preview(self.payload)
        self.assertEqual([m["name"] for m in apply.call_args.args[0]], ["eDP-1"])


if __name__ == "__main__":
    unittest.main()
