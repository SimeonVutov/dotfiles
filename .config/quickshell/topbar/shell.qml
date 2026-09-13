//  Standalone Quickshell top bar — and, sharing the same process, the
//  session menu (IPC-controlled, see SessionMenu/SessionMenuRoot.qml).
//  One resident process instead of two keeps memory to one Qt/QML engine
//  and one GPU context, and makes opening the session menu instant: no
//  process start, no QML load, no shader compile on the keypress path.
//
//  Run with:  qs -c topbar
//
//  One bar per connected monitor. Quickshell.screens updates itself when
//  monitors come and go, so switching layouts needs no restart.
import Quickshell
import qs.Bar
import qs.SessionMenu

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }
    SessionMenuRoot {}
}
