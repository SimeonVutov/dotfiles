# Changelog

## v0.1.0-alpha.1 - 2026-10-02

### Highlights

A configurable Quickshell desktop brings an adaptive topbar, app launcher, session menu, and monitor controls. New connectivity, media, audio, hardware, and workspace tools make common desktop tasks available from the topbar.

### Added

- The topbar lets you arrange modules, choose their displayed information, and retain customized views across restarts while adapting to limited screen space.
- The topbar shows battery charge and charging status, with indicators for low battery.
- The clock opens a dashboard with the current time, date, and a calendar that supports month and year navigation.
- Hardware panels show CPU, memory, temperature, and GPU readings, including recent history charts.
- The topbar provides a power button that runs the configured power action.
- Hardware controls let you switch ASUS thermal profiles and power presets, and identify when the active power configuration is custom.
- A monitor settings panel lets you rearrange displays, select layout presets and per-display modes, and preview changes that revert unless confirmed.
- A Quickshell launcher searches and ranks applications by name, supports keyboard and mouse selection, and presents results in an animated satellite-themed interface.
- The topbar provides Wi-Fi controls to scan networks, connect or disconnect, enter passwords, and forget saved networks.
- The connectivity panel lets you discover, pair, connect, disconnect, and forget Bluetooth devices, including responding to pairing prompts.
- Media controls let you manage playback, seek supported tracks, and choose a player or follow the currently playing source automatically.
- Separate output and microphone controls let you choose audio devices and available profiles.
- The workspace selector represents workspaces as planets and animates switches while retaining click- and scroll-to-switch controls.
- An animated session menu provides lock, sleep, hibernate, shutdown, restart, and logout actions, with keyboard confirmation and immediate mouse selection.
- A hybrid AMD/NVIDIA configuration prioritizes integrated graphics and uses stable device aliases.
- Topbar panels and quick settings use dismissible overlays, coordinate full-screen menus so only one is open at a time, and support keyboard focus.

### Changed

- Quickshell now provides the desktop topbar and integrated desktop interface in place of Waybar.
- Hyprland shortcuts now open the Quickshell launcher, session menu, and monitor settings, and shared startup handling can start or restart the shell when needed.
- Hyprland window borders use configurable active and inactive colors.
- Kitty uses shorter repaint and input delays and no longer synchronizes rendering to the monitor.
- Ctrl+Shift+T now opens an interactive Zsh window instead of launching tmux directly.
- The tmux cleanup script now makes a one-time check with a configurable inactivity timeout and rechecks attachment before removing a session; a user timer schedules these checks once per minute.
- Tmux reloads its configuration from the configured file, refreshes client environment variables on reattach, and no longer overwrites DISPLAY with its startup value.

### Removed

- The bundled Rofi launcher themes and shared styling files have been removed as the desktop moves to the Quickshell launcher.
- The hypridle service is no longer linked to start with the graphical session.
- The workflow that generated and applied Copilot-written pull request summaries has been removed.
- Merging a pull request no longer automatically creates a release and tag.

### Fixed

- Wallpaper palette updates now discard outdated results so the displayed colors stay aligned with the selected wallpaper.
- The wallpaper picker toggle now targets the newest Quickshell instance and can start it through the shared launcher, avoiding failures caused by stale instance records.

### Documentation

- The README now explains how to initialize local display state, configure the laptop-specific hybrid graphics profile, and reuse and attribute the project’s original work.
- The pull request template now prompts contributors to describe behavior changes, validation, migration steps, and risks.
- A repository license and notice specify attribution requirements for sharing original material and require separate written permission for commercial use.
- Desktop screenshots have been updated to show the Quickshell topbar, launcher, monitor switcher, and session menu instead of the previous Rofi and Waybar previews.

### Maintenance

- Release preparation now compares final-state changes with the previous release, validates and drafts reviewable release metadata, supports resuming or probing analysis, and publishes reviewed releases before opening a synchronization pull request.
- Pull requests and pushes now receive checks for configuration syntax, workflow validity, automation tests, and conventional commit titles and messages.
- Pull requests are automatically labeled according to the repository areas changed.
- Dependabot checks GitHub Actions and automation npm dependencies weekly, grouping action updates and limiting open npm update pull requests.

