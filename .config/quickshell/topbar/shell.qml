//@ pragma Env QSG_RHI_BACKEND = opengl
//@ pragma Env __EGL_VENDOR_LIBRARY_FILENAMES = /usr/share/glvnd/egl_vendor.d/50_mesa.json
//@ pragma Env MALLOC_CONF = narenas:2,dirty_decay_ms:1000,muzzy_decay_ms:0
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Bar
import qs.Common
import qs.SessionMenu
import qs.Settings

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }
    SessionMenuRoot {
        id: sessionMenu
    }
    SettingsRoot {}

    // The app launcher is a process of its own (quickshell/launcher); it asks
    // for the screen to be cleared before it opens.
    IpcHandler {
        target: "overlays"

        function dismiss(): void {
            OverlayController.dismiss();
        }
    }

    // Hyprland binds this directly, so opening skips a shell script and an IPC client.
    GlobalShortcut {
        appid: "quickshell-topbar"
        name: "session-menu"
        description: "Toggle session menu"
        onPressed: sessionMenu.toggle()
    }
}
