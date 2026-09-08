//  Standalone Quickshell top bar.
//
//  Run with:  qs -c topbar
//
//  One bar per connected monitor. Quickshell.screens updates itself when
//  monitors come and go, so switching layouts needs no restart.
import Quickshell
import qs.Bar

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }
}
