import QtQuick

// Minimal touch login: user name (prefilled with the last user), password, reboot/power-off.
// The on-screen keyboard is KWin's own input method (plasma-keyboard, set in the sddm user's kwinrc) and appears
// over the bottom of the screen when a field gets focus over the Wayland text-input protocol. Sizes follow the window height.
Rectangle {
    id: root
    width: 1600
    height: 2560
    color: "#1b1e2b"
    property real u: Math.min(width, height) / 40
    property int sessionIndex: sessionModel.lastIndex
    property string sessionName: ""

    Connections {
        target: sddm
        function onLoginFailed() { err.text = "Wrong user or password"; pass.text = ""; pass.forceActiveFocus() }
        function onLoginSucceeded() { err.text = "" }
    }

    // Kept in the upper part of the screen so the keyboard at the bottom never covers the fields.
    Column {
        id: form
        spacing: root.u
        width: Math.min(root.width * 0.8, root.u * 30)
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.u * 2

        Text { text: "u880"; color: "#ffffff"; font.pixelSize: root.u * 2.4; anchors.horizontalCenter: parent.horizontalCenter }

        Rectangle {
            width: parent.width; height: root.u * 3; radius: root.u / 2; color: "#2a2e42"
            TextInput {
                id: user
                anchors.fill: parent; anchors.margins: root.u / 2
                color: "#ffffff"; font.pixelSize: root.u * 1.4; verticalAlignment: TextInput.AlignVCenter
                text: userModel.lastUser
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhPreferLowercase
                KeyNavigation.tab: pass
                onAccepted: pass.forceActiveFocus()
            }
        }
        Rectangle {
            width: parent.width; height: root.u * 3; radius: root.u / 2; color: "#2a2e42"
            TextInput {
                id: pass
                anchors.fill: parent; anchors.margins: root.u / 2
                color: "#ffffff"; font.pixelSize: root.u * 1.4; verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                focus: true
                onAccepted: sddm.login(user.text, pass.text, root.sessionIndex)
            }
            Text { visible: pass.text.length === 0 && !pass.activeFocus; text: "password"; color: "#7d8299"
                   anchors.left: parent.left; anchors.leftMargin: root.u / 2; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: root.u * 1.4 }
        }
        // Session chooser (tap to open, tap an entry): the last used session is preselected (RememberLastSession=true).
        Rectangle {
            width: parent.width; height: root.u * 3; radius: root.u / 2; color: "#2a2e42"
            Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: root.u / 2
                   color: "#ffffff"; font.pixelSize: root.u * 1.4; text: root.sessionName }
            Text { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: root.u / 2
                   color: "#7d8299"; font.pixelSize: root.u * 1.4; text: sessionList.visible ? "\u25B4" : "\u25BE" }
            MouseArea { anchors.fill: parent; onClicked: sessionList.visible = !sessionList.visible }
        }
        Column {
            id: sessionList
            visible: false; width: parent.width; spacing: root.u / 4
            Repeater {
                model: sessionModel
                delegate: Rectangle {
                    // our sessions (u880-*.desktop) plus stock Phosh; the stock gnome/plasma/weston ones stay hidden
                    visible: model.file.indexOf("/u880-") >= 0 || model.file.indexOf("/phosh.desktop") >= 0
                    width: sessionList.width; height: root.u * 3; radius: root.u / 2
                    color: index === root.sessionIndex ? "#3b6ef5" : "#2a2e42"
                    Component.onCompleted: {
                        if (!visible) return
                        if (index === sessionModel.lastIndex) { root.sessionIndex = index; root.sessionName = model.name }
                        else if (root.sessionName === "") { root.sessionIndex = index; root.sessionName = model.name }
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: root.u / 2
                           color: "#ffffff"; font.pixelSize: root.u * 1.4; text: model.name }
                    MouseArea { anchors.fill: parent; onClicked: { root.sessionIndex = index; root.sessionName = model.name; sessionList.visible = false } }
                }
            }
        }
        Text { id: err; color: "#ff7b7b"; font.pixelSize: root.u * 1.1; anchors.horizontalCenter: parent.horizontalCenter }
        Rectangle {
            width: parent.width; height: root.u * 3; radius: root.u / 2; color: "#3b6ef5"
            Text { anchors.centerIn: parent; text: "Log in"; color: "#ffffff"; font.pixelSize: root.u * 1.4 }
            MouseArea { anchors.fill: parent; onClicked: sddm.login(user.text, pass.text, root.sessionIndex) }
        }
        Row {
            spacing: root.u
            anchors.horizontalCenter: parent.horizontalCenter
            Rectangle { visible: sddm.canReboot; width: root.u * 8; height: root.u * 2.4; radius: root.u / 2; color: "#2a2e42"
                Text { anchors.centerIn: parent; text: "Reboot"; color: "#ffffff"; font.pixelSize: root.u * 1.1 }
                MouseArea { anchors.fill: parent; onClicked: sddm.reboot() } }
            Rectangle { visible: sddm.canPowerOff; width: root.u * 8; height: root.u * 2.4; radius: root.u / 2; color: "#2a2e42"
                Text { anchors.centerIn: parent; text: "Power off"; color: "#ffffff"; font.pixelSize: root.u * 1.1 }
                MouseArea { anchors.fill: parent; onClicked: sddm.powerOff() } }
        }
    }

}
