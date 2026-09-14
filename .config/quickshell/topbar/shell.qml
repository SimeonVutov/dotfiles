// One resident shell for the bar and its full-screen overlays.
import Quickshell
import qs.Bar
import qs.SessionMenu
import qs.Launcher
import qs.Settings

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }
    SessionMenuRoot {}
    LauncherRoot {}
    SettingsRoot {}
}
