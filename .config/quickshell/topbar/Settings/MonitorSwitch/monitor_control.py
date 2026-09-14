#!/usr/bin/env python3
"""Hyprland display discovery and reversible layout transactions."""

import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import select
import signal
import subprocess
import sys
import tempfile
import time

PREVIEW_SECONDS = 15
WORKSPACE_IDS = range(1, 11)
MODE_PATTERN = re.compile(r"^(\d+)x(\d+)@(\d+(?:\.\d+)?)(?:Hz)?$")
CONNECTOR_PATTERN = re.compile(r"^[A-Za-z0-9_.:-]+$")


def hyprctl(*args, as_json=False):
    result = subprocess.run(
        ["hyprctl", *(["-j"] if as_json else []), *args],
        capture_output=True, text=True, timeout=5, check=True,
    )
    if as_json:
        return json.loads(result.stdout)
    if args[0] in ("keyword", "dispatch", "reload") and result.stdout.strip() != "ok":
        raise ValueError(result.stdout.strip() or "Hyprland rejected the change")
    return result.stdout


def dimensions(monitor):
    width, height = monitor["width"], monitor["height"]
    if monitor["transform"] % 2:
        width, height = height, width
    return round(width / monitor["scale"]), round(height / monitor["scale"])


def discover():
    raw = hyprctl("monitors", "all", as_json=True)
    monitors = []
    for output in raw:
        name = output["name"]
        if not CONNECTOR_PATTERN.fullmatch(name):
            raise ValueError("Unsupported display connector name")
        modes = [mode.removesuffix("Hz") for mode in output.get("availableModes", [])
                 if MODE_PATTERN.fullmatch(mode)]
        preferred = MODE_PATTERN.fullmatch(modes[0]) if modes else None
        width = output.get("width", 0) or (int(preferred[1]) if preferred else 1920)
        height = output.get("height", 0) or (int(preferred[2]) if preferred else 1080)
        rate = round(output.get("refreshRate", 0) or (float(preferred[3]) if preferred else 60), 2)
        description = output.get("description", "")
        unique = sum(m.get("description") == description for m in raw) == 1
        selector = "desc:" + description if description and unique and not re.search(r"[,;\x00-\x1f#$\\]", description) else name
        monitors.append({
            "name": name, "selector": selector, "description": description,
            "internal": bool(re.match(r"^(eDP|LVDS|DSI)-?", name)),
            "enabled": not output.get("disabled", False),
            "width": width, "height": height, "rate": rate,
            "scale": round((output.get("scale", 1) or 1) * 120) / 120,
            "transform": output.get("transform", 0),
            "x": output.get("x", 0), "y": output.get("y", 0),
            "mirror": output.get("mirrorOf", "none"), "modes": modes,
        })
    monitors.sort(key=lambda m: (not m["internal"], m["name"]))
    revision = hashlib.sha256(json.dumps(monitors, sort_keys=True).encode()).hexdigest()
    return {"monitors": monitors, "revision": revision}


def overlap(a, b):
    aw, ah = dimensions(a)
    bw, bh = dimensions(b)
    return min(a["x"] + aw, b["x"] + bw) > max(a["x"], b["x"]) and min(a["y"] + ah, b["y"] + bh) > max(a["y"], b["y"])


def adjacent(a, b):
    aw, ah = dimensions(a)
    bw, bh = dimensions(b)
    vertical = min(a["y"] + ah, b["y"] + bh) > max(a["y"], b["y"])
    horizontal = min(a["x"] + aw, b["x"] + bw) > max(a["x"], b["x"])
    return (vertical and (a["x"] + aw == b["x"] or b["x"] + bw == a["x"])) or (horizontal and (a["y"] + ah == b["y"] or b["y"] + bh == a["y"]))


def validate(payload, state):
    if payload.get("revision") != state["revision"]:
        raise ValueError("Displays changed. Refresh the map before applying.")
    draft = payload.get("monitors", [])
    if sorted(m.get("name", "") for m in draft) != sorted(m["name"] for m in state["monitors"]):
        raise ValueError("The connected displays have changed")
    mode = payload.get("mode")
    if mode not in ("laptop", "external", "extend", "duplicate", "custom"):
        raise ValueError("Unknown display mode")
    result = []
    for original in state["monitors"]:
        requested = next(m for m in draft if m["name"] == original["name"])
        monitor = dict(original)
        if type(requested.get("enabled")) is not bool:
            raise ValueError("Invalid display state")
        monitor["enabled"] = requested["enabled"]
        for key, low, high in (("width", 320, 16384), ("height", 200, 16384),
                               ("rate", 1, 1000), ("scale", 5 / 6 - .000001, 3),
                               ("x", -65536, 65536), ("y", -65536, 65536)):
            value = requested.get(key)
            if type(value) not in (int, float) or not math.isfinite(value) or not low <= value <= high:
                raise ValueError("Invalid display " + key)
            if key in ("width", "height", "x", "y") and value != int(value):
                raise ValueError("Display coordinates and resolution must use whole pixels")
            monitor[key] = value
        if monitor["enabled"] and any(abs(n / monitor["scale"] - round(n / monitor["scale"])) > .01 for n in (monitor["width"], monitor["height"])):
            raise ValueError("Scale must divide the resolution into whole logical pixels")
        monitor["mirror"] = "none"
        prefix = f'{monitor["width"]:g}x{monitor["height"]:g}@'
        rates = [float(m.split("@")[1]) for m in original["modes"] if m.startswith(prefix)]
        if not rates and (monitor["width"], monitor["height"]) != (original["width"], original["height"]):
            raise ValueError("Choose one of this display's available resolutions")
        maximum = max(rates) if rates else original["rate"]
        if monitor["enabled"] and monitor["rate"] > maximum + .01:
            raise ValueError(f'Refresh rate exceeds this resolution\'s maximum of {maximum:g} Hz')
        result.append(monitor)
    active = [m for m in result if m["enabled"]]
    if not active:
        raise ValueError("Keep at least one display enabled")
    if mode == "laptop" and any(m["enabled"] != m["internal"] for m in result):
        raise ValueError("Laptop mode must use only internal displays")
    if mode == "external" and any(m["enabled"] == m["internal"] for m in result):
        raise ValueError("External mode must use all external displays")
    if mode in ("extend", "duplicate") and len(active) != len(result):
        raise ValueError("This mode must enable every display")
    if mode == "duplicate":
        for monitor in active[1:]:
            monitor["mirror"] = active[0]["name"]
    else:
        if any(overlap(a, b) for i, a in enumerate(active) for b in active[i + 1:]):
            raise ValueError("Displays cannot overlap")
        connected = [active[0]]
        pending = active[1:]
        while pending:
            neighbours = [m for m in pending if any(adjacent(m, n) for n in connected)]
            if not neighbours:
                raise ValueError("Each display must share an edge with the layout")
            connected.extend(neighbours)
            pending = [m for m in pending if m not in neighbours]
    return result


def monitor_rule(monitor, selector=None):
    target = selector or monitor["selector"]
    if not monitor["enabled"]:
        return target + ",disable"
    rule = f'{target},{monitor["width"]:g}x{monitor["height"]:g}@{monitor["rate"]:g},{monitor["x"]:g}x{monitor["y"]:g},{monitor["scale"]:.10g},transform,{monitor["transform"]}'
    return rule + ",mirror," + monitor["mirror"]


def apply_monitors(monitors):
    # Enable destinations before disabling the screen hosting the control panel.
    # Hyprland may warn about a transient overlap while the monitors are moved
    # one at a time; it still applies each rule, and the final layout is
    # validated to be overlap-free before any of this runs.
    for monitor in sorted(monitors, key=lambda m: (not m["enabled"], m["mirror"] != "none")):
        hyprctl("keyword", "monitor", monitor_rule(monitor))


# Which screens are lit is the only thing worth verifying automatically: it
# decides whether you can still see anything. Exact geometry is left to the
# person looking at the result, who confirms or reverts it. Demanding an exact
# match here instead reverted layouts that had applied perfectly well, because
# Hyprland legitimately reports back its own rate, scale and mirror details.
def lit(monitors):
    return {m["name"] for m in monitors if m["enabled"]}


def wait_for_layout(monitors):
    deadline = time.monotonic() + 5
    expected = lit(monitors)
    while time.monotonic() < deadline:
        if lit(discover()["monitors"]) == expected:
            return
        time.sleep(.1)
    raise ValueError("Hyprland could not use that layout or display mode; restoring the previous setup")


def workspace_targets(monitors):
    active = [m for m in monitors if m["enabled"] and m["mirror"] == "none"]
    primary, *secondary = active
    return {number: primary if number <= 5 or not secondary else secondary[(number - 6) % len(secondary)] for number in WORKSPACE_IDS}


def relocate(workspaces, targets, focused):
    for workspace in workspaces:
        number = workspace["id"]
        if number > 0 and number in targets and workspace.get("monitor") != targets[number]:
            hyprctl("dispatch", "moveworkspacetomonitor", f"{number} {targets[number]}")
    if focused > 0:
        hyprctl("dispatch", "workspace", str(focused))


# Without this the preview shows the new monitors while the workspace rules
# still bind every workspace to the old ones, leaving a freshly enabled screen
# with none it is allowed to own - so Hyprland invents an extra one past the
# end of the range.
def bind_workspaces(targets):
    for number, monitor in targets.items():
        hyprctl("keyword", "workspace", f'{number}, monitor:{monitor["selector"]}')


def rebind_workspaces(rules):
    for rule in rules:
        number, monitor = str(rule.get("workspaceString", "")), rule.get("monitor", "")
        if number.isdigit() and monitor:
            hyprctl("keyword", "workspace", f"{number}, monitor:{monitor}")


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".monitor-switch-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def persist(monitors, targets, paths):
    selectors = {m["selector"] for m in monitors} | {m["name"] for m in monitors}
    existing = paths[0].read_text() if paths[0].exists() else ""
    retained = [line for line in existing.splitlines() if not (
        line.strip().startswith("monitor") and "=" in line and line.split("=", 1)[1].split(",", 1)[0].strip() in selectors)]
    stable = {m["name"]: m["selector"] for m in monitors}
    saved = [dict(m, mirror=stable.get(m["mirror"], "none")) for m in monitors]
    contents = ["\n".join(retained + ["monitor = " + monitor_rule(m) for m in saved]) + "\n",
                "".join(f'workspace = {n}, monitor:{m["selector"]}\n' for n, m in targets.items())]
    backups = [path.read_text() if path.exists() else None for path in paths]
    try:
        for path, content in zip(paths, contents):
            atomic_write(path, content)
    except Exception:
        for path, backup in zip(paths, backups):
            if backup is not None:
                atomic_write(path, backup)
            else:
                path.unlink(missing_ok=True)
        raise
    return backups


def emit(event, **data):
    try:
        print(json.dumps({"event": event, **data}), flush=True)
    except BrokenPipeError:
        pass


def preview(payload):
    state = discover()
    monitors = validate(payload, state)
    original = state["monitors"]
    workspaces = hyprctl("workspaces", as_json=True)
    focused = hyprctl("activeworkspace", as_json=True).get("id", 0)
    prior_rules = hyprctl("workspacerules", as_json=True)
    committed = False
    config = Path.home() / ".config/hypr/conf"
    paths = [config / "monitors/current.conf", config / "workspaces/current.conf"]
    backups = None
    saving = False
    try:
        apply_monitors(monitors)
        wait_for_layout(monitors)
        targets = workspace_targets(monitors)
        bind_workspaces(targets)
        relocate(hyprctl("workspaces", as_json=True), {n: m["name"] for n, m in targets.items()}, focused)
        deadline = time.monotonic() + PREVIEW_SECONDS
        emit("preview", seconds=PREVIEW_SECONDS)
        connected = {m["name"] for m in original}
        while time.monotonic() < deadline:
            readable, _, _ = select.select([sys.stdin], [], [], 1)
            live = discover()["monitors"]
            if {m["name"] for m in live} != connected:
                raise ValueError("A display was connected or removed; the preview was reverted")
            if not readable:
                continue
            response = sys.stdin.readline().strip()
            if response != "keep":
                break
            if lit(live) != lit(monitors):
                raise ValueError("The display layout changed during the preview")
            saving = True
            backups = persist(monitors, targets, paths)
            # Dynamic workspace rules retain old monitor bindings on some Hyprland versions.
            hyprctl("reload")
            wait_for_layout(monitors)
            relocate(hyprctl("workspaces", as_json=True), {n: m["name"] for n, m in targets.items()}, focused)
            committed = True
            emit("kept")
            return
    finally:
        if not committed:
            # Finish recovery even if the shell sends another termination signal.
            if __name__ == "__main__":
                signal.signal(signal.SIGTERM, signal.SIG_IGN)
                signal.signal(signal.SIGINT, signal.SIG_IGN)
            if backups is not None:
                for path, backup in zip(paths, backups):
                    if backup is None:
                        path.unlink(missing_ok=True)
                    else:
                        atomic_write(path, backup)
            if saving:
                hyprctl("reload")
            live = discover()["monitors"]
            available = {m["name"] for m in live}
            restore = [m for m in original if m["name"] in available]
            if restore and not any(m["enabled"] for m in restore):
                restore[0] = dict(restore[0], enabled=True, mirror="none")
            for m in restore:
                if m["mirror"] not in available:
                    m["mirror"] = "none"
            apply_monitors(restore)
            rebind_workspaces(prior_rules)
            relocate(hyprctl("workspaces", as_json=True), {w["id"]: w["monitor"] for w in workspaces if w["monitor"] in available}, focused)
            emit("reverted")


def interrupted(_signal, _frame):
    raise InterruptedError("Display preview cancelled")


def main():
    try:
        if len(sys.argv) == 2 and sys.argv[1] == "inspect":
            emit("state", **discover())
            return
        if len(sys.argv) != 3 or sys.argv[1] != "preview":
            raise ValueError("Expected inspect or preview")
        runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
        descriptor = os.open(runtime / "quickshell-monitor-switch.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, "w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            signal.signal(signal.SIGTERM, interrupted)
            signal.signal(signal.SIGINT, interrupted)
            preview(json.loads(sys.argv[2]))
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        emit("error", message=str(error))
        sys.exit(1)


if __name__ == "__main__":
    main()
