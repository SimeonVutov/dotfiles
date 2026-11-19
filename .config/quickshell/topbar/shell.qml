//@ pragma Env QSG_RHI_BACKEND = opengl
//@ pragma Env __EGL_VENDOR_LIBRARY_FILENAMES = /usr/share/glvnd/egl_vendor.d/50_mesa.json
//@ pragma Env MALLOC_CONF = narenas:2,dirty_decay_ms:1000,muzzy_decay_ms:0
import Quickshell
import Quickshell.Io
import qs.Bar
import qs.Common
import qs.Settings

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }
    SettingsRoot {}

    // The app launcher and the session menu are processes of their own
    // (quickshell/launcher, quickshell/sessionmenu). Each tells the bar when it
    // opens, so the bar clears its overlays and pauses its animation, and when
    // it closes.
    IpcHandler {
        target: "overlays"

        function begin(name: string): void {
            OverlayController.beginExternal(name);
        }

        function end(name: string): void {
            OverlayController.endExternal(name);
        }
    }
}
