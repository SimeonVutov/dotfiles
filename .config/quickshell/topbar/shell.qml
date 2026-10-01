//@ pragma Env QSG_RHI_BACKEND = opengl
//@ pragma Env __EGL_VENDOR_LIBRARY_FILENAMES = /usr/share/glvnd/egl_vendor.d/50_mesa.json
//@ pragma Env MALLOC_CONF = narenas:2,dirty_decay_ms:1000,muzzy_decay_ms:0
import Quickshell
import Quickshell.Hyprland
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
    LauncherRoot {
        id: launcher
    }
    SettingsRoot {}

    GlobalShortcut {
        appid: "quickshell-topbar"
        name: "launcher"
        description: "Toggle app launcher"
        onPressed: launcher.toggle()
    }
}
