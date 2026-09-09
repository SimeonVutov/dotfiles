pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root
    property string profile: ""
    property string error: ""
    readonly property bool busy: getProfile.running || setProfile.running

    // Refresh on open and on kernel platform-profile changes, never on a timer.
    FileView {
        id: platformProfile
        path: "/sys/firmware/acpi/platform_profile"
        watchChanges: true
        printErrors: false
        onFileChanged: root.refresh()
    }

    function refresh() {
        if (!busy)
            getProfile.running = true;
    }
    function setFanProfile(name) {
        if (busy || ["Quiet", "Balanced", "Performance"].indexOf(name) < 0)
            return;
        error = "";
        setProfile.command = ["asusctl", "profile", "set", name];
        setProfile.running = true;
    }
    function setPowerMode(name) {
        if (["ultimate", "balanced"].indexOf(name) < 0)
            return;
        // name is one of the two literal strings checked above, and
        // powerCommand is a fixed config path, so building this shell string
        // is safe: nothing here is attacker- or user-typed input.
        const command = Config.hardware.powerCommand + " " + name;
        // Printed before running, so the sudo prompt below it is never a
        // surprise — you see exactly what's about to run as root. No --hold:
        // the window waits for the command (including the password prompt)
        // then closes itself, pausing briefly first so the result is readable.
        const shown = "printf 'Running:\\n  %s\\n\\n' '" + command + "'; " + command + "; sleep 1.5";
        Quickshell.execDetached(["kitty", "--class", "wm-floating", "--title", "Power mode", "-e", "sh", "-c", shown]);
    }
    Process {
        id: getProfile
        command: ["asusctl", "profile", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/\b(Quiet|Balanced|Performance)\b/i);
                if (match) {
                    const value = match[1].toLowerCase();
                    root.profile = value.charAt(0).toUpperCase() + value.slice(1);
                    root.error = "";
                } else {
                    root.profile = "";
                    root.error = "Couldn't read the thermal profile.";
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0 || status !== 0) {
                root.profile = "";
                root.error = "Couldn't read the thermal profile. Check asusctl / asusd.";
            }
        }
    }
    Process {
        id: setProfile
        onExited: (code, status) => {
            if (code !== 0 || status !== 0) {
                root.error = "Thermal profile change failed. Check asusctl / asusd.";
                return;
            }
            // Not root.refresh(): its "!busy" guard can still see this very
            // process as running at the instant its own onExited fires,
            // silently skipping the read until something else (reopening the
            // popup) called refresh() later.
            getProfile.running = true;
        }
    }
}
