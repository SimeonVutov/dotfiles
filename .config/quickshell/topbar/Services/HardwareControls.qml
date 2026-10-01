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
        const command = Config.hardware.powerCommand + " " + name;
        // Show the command before its authorization prompt.
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
            // refresh() may still see this process as busy inside onExited.
            getProfile.running = true;
        }
    }
}
