//@ pragma Env QSG_RHI_BACKEND = opengl
//@ pragma Env __EGL_VENDOR_LIBRARY_FILENAMES = /usr/share/glvnd/egl_vendor.d/50_mesa.json
//@ pragma Env MALLOC_CONF = narenas:2,dirty_decay_ms:1000,muzzy_decay_ms:0
import Quickshell

// The orbital session menu, as a process of its own: quickshell-overlay.sh
// starts it on a key press, it opens at once, and it exits when it closes.
// Nothing of it stays in memory while it is not in use.
ShellRoot {
    SessionMenuRoot {}
}
