#!/usr/bin/env python3
"""One Bluetooth action, with an application-local BlueZ pairing agent."""

import json
import os
import re
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib


AGENT_XML = """<node><interface name="org.bluez.Agent1">
<method name="Release"/>
<method name="Cancel"/>
<method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
<method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
<method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
<method name="DisplayPasskey"><arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/></method>
<method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
<method name="RequestAuthorization"><arg type="o" direction="in"/></method>
<method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
</interface></node>"""


def emit(**message):
    print(json.dumps(message), flush=True)


class Action:
    def __init__(self, path, operation):
        self.path = path
        self.operation = operation
        self.bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.loop = GLib.MainLoop()
        self.pending = None
        self.pending_kind = ""
        self.buffer = b""
        self.finished = False

    def call(self, path, interface, method, args=None, done=None):
        def completed(bus, result):
            try:
                bus.call_finish(result)
                if done:
                    done()
                else:
                    self.finish()
            except GLib.Error as error:
                self.finish(error.message)

        self.bus.call("org.bluez", path, interface, method, args, None,
                      Gio.DBusCallFlags.NONE, 90000, None, completed)

    def finish(self, error=""):
        if self.finished:
            return
        self.finished = True
        emit(event="error" if error else "done", message=error)
        self.loop.quit()

    def cancel(self):
        if self.pending:
            self.pending.return_dbus_error("org.bluez.Error.Canceled", "Canceled by user")
            self.pending = None
        if self.operation == "pair":
            self.call(self.path, "org.bluez.Device1", "CancelPairing", done=lambda: self.finish("Pairing canceled"))
        else:
            self.finish("Canceled")

    def agent(self, connection, sender, path, interface, method, parameters, invocation):
        values = parameters.unpack()
        if method in ("Cancel", "Release"):
            if self.pending:
                self.pending.return_dbus_error("org.bluez.Error.Canceled", "Pairing canceled")
                self.pending = None
            invocation.return_value(None)
            emit(event="clear")
            return
        if not values or values[0] != self.path:
            invocation.return_dbus_error("org.bluez.Error.Rejected", "Unexpected device")
            return
        if method.startswith("Display"):
            code = values[1] if method == "DisplayPinCode" else f"{values[1]:06d}"
            emit(event="prompt", kind="display", message=f"Enter {code} on your device, then press Enter.")
            invocation.return_value(None)
            return
        if self.pending:
            invocation.return_dbus_error("org.bluez.Error.Rejected", "Another prompt is pending")
            return
        self.pending = invocation
        self.pending_kind = method
        if method in ("RequestPinCode", "RequestPasskey"):
            emit(event="prompt", kind="pin" if method == "RequestPinCode" else "passkey", message="Enter the code shown on your device.")
        else:
            message = f"Does {values[1]:06d} match the code on your device?" if method == "RequestConfirmation" else "Allow this device to pair and connect?"
            emit(event="prompt", kind="confirm", message=message)

    def respond(self, message):
        if message.get("cancel"):
            self.cancel()
            return
        if not self.pending:
            return
        value = str(message.get("value", ""))
        if self.pending_kind == "RequestPasskey":
            if not re.fullmatch(r"[0-9]{1,6}", value):
                return
            result = GLib.Variant("(u)", (int(value),))
        elif self.pending_kind == "RequestPinCode":
            if not 1 <= len(value) <= 16:
                return
            result = GLib.Variant("(s)", (value,))
        else:
            result = None
        self.pending.return_value(result)
        self.pending = None
        emit(event="clear")

    def read_input(self, fd, condition):
        data = os.read(fd, 4096)
        if not data:
            self.cancel()
            return False
        self.buffer += data
        while b"\n" in self.buffer:
            line, self.buffer = self.buffer.split(b"\n", 1)
            try:
                self.respond(json.loads(line))
            except (ValueError, TypeError):
                self.cancel()
        return True

    def start(self):
        GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP, self.read_input)
        GLib.timeout_add_seconds(100, lambda: self.finish("Bluetooth action timed out"))
        if self.operation == "pair":
            info = Gio.DBusNodeInfo.new_for_xml(AGENT_XML).interfaces[0]
            self.bus.register_object("/topbar/agent", info, self.agent, None, None)
            self.call("/org/bluez", "org.bluez.AgentManager1", "RegisterAgent",
                      GLib.Variant("(os)", ("/topbar/agent", "KeyboardDisplay")),
                      lambda: self.call(self.path, "org.bluez.Device1", "Pair",
                                        done=lambda: self.call(self.path, "org.freedesktop.DBus.Properties", "Set",
                                                               GLib.Variant("(ssv)", ("org.bluez.Device1", "Trusted", GLib.Variant("b", True))),
                                                               done=lambda: self.call(self.path, "org.bluez.Device1", "Connect"))))
        elif self.operation in ("trust", "untrust"):
            self.call(self.path, "org.freedesktop.DBus.Properties", "Set",
                      GLib.Variant("(ssv)", ("org.bluez.Device1", "Trusted", GLib.Variant("b", self.operation == "trust"))))
        else:
            self.call(self.path, "org.bluez.Device1", "Connect" if self.operation == "connect" else "Disconnect")
        self.loop.run()


if __name__ == "__main__":
    try:
        device, operation = sys.argv[1:]
        if not re.fullmatch(r"/org/bluez/hci[0-9]+/dev_(?:[0-9A-Fa-f]{2}_){5}[0-9A-Fa-f]{2}", device):
            raise ValueError("Invalid Bluetooth device path")
        if operation not in ("pair", "connect", "disconnect", "trust", "untrust"):
            raise ValueError("Invalid Bluetooth action")
        Action(device, operation).start()
    except Exception:
        emit(event="error", message="Bluetooth service unavailable or invalid action")
        sys.exit(1)
