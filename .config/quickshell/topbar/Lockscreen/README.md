# Quickshell lockscreen

`LockService.qml` owns the Wayland session lock and its one-way IPC. It runs in
an independent Quickshell process through the `quickshell/lockscreen` symlink.
The top bar imports the same layout components without instantiating the locker.

`Authenticator.qml` handles the system PAM `login` conversation. This is the auth
stack included by the former Hyprlock policy. A successful PAM result is the
only event that releases the lock. There is no unlock IPC, test bypass, or
authentication configuration in the saved layout.

The password field masks characters, disables predictive input, sends its text
directly to an active PAM prompt, and clears immediately after submission.
Enter and the Unlock button share that path. Passwords are never written to
layout state, files, command arguments, or public Quickshell control IPC/logs. Core dumps are
disabled by the locker launcher. Qt and PAM still hold transient strings in
memory; QML cannot promise locked memory or deterministic zeroization of every
copy. No account password is read from a configuration file.

## Layout and widget contract

- `Grid.js` validates whole-cell geometry, collisions, unique widget identities,
  supported settings, and the mandatory password widget. It contains no UI code.
- `LayoutStore.qml` reads and atomically saves the versioned JSON layout. Invalid
  saved data uses the default layout without preventing authentication.
- `WidgetCatalog.js` registers trusted widget components, names, initial spans,
  and settings. Saved layouts cannot name arbitrary QML components.
- `LockFace.qml` maps cell rectangles to each output. The password widget has a
  dedicated implementation outside optional widget loaders.
- `Settings/Lockscreen/` owns the editor controller, canvas, inspector, and
  library. It shares the same grid rules and store as the live screen.

The grid starts at 18 columns × 12 rows. Its density selector supports up to
72 × 48 cells without changing the preview aspect ratio. Changing density keeps
widget cell spans and approximate screen-space centres; increasing density
therefore shrinks their visible rectangles. Coarser grids are rejected if their
placements would overlap or go out of bounds. A widget declares `columns: 2, rows: 3` to
occupy 2 × 3 cells. The same normalized layout scales to every monitor; the
editor's display selector previews the selected aspect ratio.

To implement a widget, add its QML under `widgets/` and set its `component` in
the catalog. Its root must declare `property var widgetSettings` and fill its
provided rectangle. Add custom settings with a `key`, `label`, `kind`, and
`initial` value; numeric settings also declare `minimum`, `maximum`, and `step`.
Set `livePreview: true` to preview edits before they are saved, or `false` to
apply the setting only after confirmation. Omitted flags default to false.
The shared appearance settings all enable live preview, including color edits.
Incomplete or invalid input is not previewed, and Escape restores saved values.
Existing controls support numeric sliders and a color wheel with RGBA and hex
input. Picker hex uses #RRGGBB or #RRGGBBAA; saved values use Qt
#RRGGBB or #AARRGGBB. Color edits preview until Apply; Cancel or Escape reverts. Optional
components receive presentation settings, not the authentication controller.

Clock and Unlock are implemented. Other catalog entries are placeholders; there
is no music-player process, artwork generation, or transport control in this
initial foundation. Locking leaves the user's media and applications running.

The layout lives at `$XDG_STATE_HOME/quickshell/lockscreen-layout.json`, falling
back to `~/.local/state/quickshell/lockscreen-layout.json`. It is not part of Git.
Open the editor with Super+Shift+L or `sh ~/.config/scripts/quick-settings.sh lockscreen`.
Click a placed rectangle to select it and expand its settings. Its top-left move
control starts repositioning; its top-right X removes it. Click a library item to
start placing a new widget. Move the pointer and click to commit a placement.
Escape cancels the current placement or field edit; when idle it closes the
editor. Optional widgets can be removed with their inspector trash button or
hover X. Invalid placement keeps the widget in moving mode, shakes its
outline, and displays the error. The last saved layout remains unchanged.

## Checks

```sh
node ~/.config/quickshell/topbar/Lockscreen/test_grid.cjs
```

The editor preview can be opened with `qs -p ~/.config/quickshell/topbar/LockscreenCheck.qml`
using isolated state while developing. PAM/IPC test drafts are deferred.
Verify a real password, hot-plugging while locked, and suspend/resume on the
live compositor before relying on the new locker unattended.

Hyprlock configuration, its music helper, and its Matugen template remain in
version control for now. Removing them is a separate change.

Password handling references:
[Quickshell PAM](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pam/PamContext/),
[Hyprlock authentication](https://github.com/hyprwm/hyprlock/blob/main/src/auth/Pam.cpp),
and [Swaylock password buffers](https://github.com/swaywm/swaylock/blob/master/password-buffer.c).
