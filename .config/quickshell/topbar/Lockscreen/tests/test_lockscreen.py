"""Offscreen integration checks; never acquires a session lock or uses real PAM."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest


LOCKSCREEN = Path(__file__).resolve().parents[1]
TOPBAR = LOCKSCREEN.parent


class LockscreenTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="lockscreen-test-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.environment = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                                XDG_STATE_HOME=str(self.directory), XDG_RUNTIME_DIR=str(self.directory))
        self.environment.pop("WAYLAND_DISPLAY", None)

    def run_check(self, config, expected):
        result = subprocess.run(["qs", "-p", str(config), "--no-color"], env=self.environment,
                                capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertIn(expected, output)
        self.assertNotIn("TypeError", output)
        self.assertNotIn("ReferenceError", output)
        self.assertNotIn("Failed to load", output)

    def test_editor_and_preview(self):
        self.run_check(TOPBAR / "LockscreenCheck.qml", "PASS lockscreen editor")

        import json
        state = json.loads((self.directory / "quickshell/lockscreen-layout.json").read_text())
        self.assertEqual({widget["type"] for widget in state["widgets"]}, {"clock", "authentication"})

    def test_authentication_state_machine(self):
        # Substitute only the native PAM transport in an isolated copy. Production
        # code has no mock provider, success override, or testing-mode switch.
        config = self.directory / "authentication"
        config.mkdir()
        shutil.copytree(LOCKSCREEN / "widgets", config / "widgets")
        shutil.copytree(LOCKSCREEN / "model", config / "model")
        for name in ("MockPam.qml", "MockPamResult.qml", "AuthenticationCheck.qml"):
            shutil.copyfile(LOCKSCREEN / "tests" / name, config / name)

        source = (LOCKSCREEN / "Authenticator.qml").read_text()
        source = source.replace("import Quickshell.Services.Pam", 'import "."')
        source = source.replace("PamContext", "MockPam").replace("PamResult", "MockPamResult")
        (config / "Authenticator.qml").write_text(source)
        self.run_check(config / "AuthenticationCheck.qml", "PASS PAM prompt lifecycle")

    def test_locker_ipc_has_no_unlock_endpoint(self):
        with (self.directory / "locker.log").open("w+") as log:
            process = subprocess.Popen(["qs", "-p", str(LOCKSCREEN), "--no-color"], env=self.environment,
                                       stdout=log, stderr=subprocess.STDOUT)
            try:
                command = ["qs", "ipc", "-n", "-p", str(LOCKSCREEN), "call", "lockscreen"]
                result = None
                for _ in range(60):
                    result = subprocess.run([*command, "status"], env=self.environment,
                                            capture_output=True, text=True, timeout=3)
                    if result.returncode == 0:
                        break
                    if process.poll() is not None:
                        break
                    time.sleep(.05)

                log.seek(0)
                output = log.read()
                self.assertIsNotNone(result)
                self.assertEqual(result.returncode, 0, output + result.stderr)
                self.assertEqual(result.stdout.strip(), "unlocked")

                interface = subprocess.run(
                    ["qs", "ipc", "-n", "-p", str(LOCKSCREEN), "show"],
                    env=self.environment, capture_output=True, text=True, timeout=3)
                self.assertEqual(interface.returncode, 0, interface.stderr)
                self.assertIn("status(", interface.stdout)
                self.assertNotIn("unlock(", interface.stdout)
            finally:
                process.terminate()
                process.wait(timeout=5)


if __name__ == "__main__":
    unittest.main()
