import QtQuick
import Quickshell
import qs.Bar
import qs.Common
import qs.Popups

// Regression gate for everything under Modules/, Popups/, Ui/, Services/,
// Common/, and Bar/ — instantiates every configured bar module (which pulls
// in its popup and every Ui/ component it uses) plus every popup directly, so
// a broken import, a bad property rename, or a dangling signal handler fails
// to load instead of failing silently at runtime.
//
// Run with:
//   QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qs -p ModulesCheck.qml
// "Configuration Loaded" with no ERROR lines (besides the sandbox's expected
// "No PanelWindow backend loaded" when run as the top-level shell) means every
// type in the graph resolved and every delegate constructed without throwing.
ShellRoot {
    FloatingWindow {
        implicitWidth: 1800
        implicitHeight: 400

        Column {
            anchors.fill: parent
            spacing: 12

            Row {
                Section {
                    moduleIds: Config.modulesLeft
                }
                Section {
                    moduleIds: Config.modulesCenter
                }
                Section {
                    moduleIds: Config.modulesRight
                }
            }

            // Popups are normally opened lazily from their owning module; force
            // one of each into existence here so their QML is exercised too.
            Row {
                spacing: 12
                Dashboard {
                    open: false
                }
                MediaPopup {
                    open: false
                }
                AudioPopup {
                    open: false
                }
                ConnectionsPopup {
                    open: false
                }
                HardwarePopup {
                    open: false
                }
            }
        }
    }
}
