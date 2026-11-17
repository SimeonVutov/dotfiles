import QtQuick
import "widgets/password"

Widget {
    id: root

    required property var controller
    widgetType: "authentication"
    designWidth: referenceSize.width / 3
    designHeight: 60
    focus: true

    PasswordField {
        anchors.centerIn: parent
        width: 300
        height: 60
        authenticator: root.controller.authenticator
        accent: root.controller.colors.accent
        textColor: root.settings.textColor
    }
}
