import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: welcome
    required property var controller
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "forynarch-live-welcome"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    Rectangle { anchors.fill: parent; color: "#66050a12" }
    GlassCard {
        width: Math.min(600, parent.width - 40)
        height: content.implicitHeight + 56
        anchors.centerIn: parent
        glass: controller.glass
        frost: controller.frost
        radius: 22
        focus: true
        Keys.onEscapePressed: controller.welcomeOpen = false
        ColumnLayout {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 28 }
            spacing: 18
            Text { text: "FORYNARCH · LIVE SESSION"; color: controller.accent; font.pixelSize: 11; font.letterSpacing: 1.5 }
            Text { text: "Make yourself at home."; color: "#edf3fc"; font.pixelSize: 30; font.weight: Font.DemiBold; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Text {
                text: "Explore the desktop, check your hardware, or set up Forynarch on your computer."
                color: "#b5c5d9"; font.pixelSize: 15; wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#30435b" }
            Text {
                text: "Trying the desktop does not install the system. Installation opens a guided setup with storage, account and software choices. You review changes before anything is written."
                color: "#b5c5d9"; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                ActionButton { label: "Try Forynarch"; onClicked: controller.welcomeOpen = false }
                Item { Layout.fillWidth: true }
                ActionButton {
                    label: "Install Forynarch"; selected: true
                    onClicked: { controller.welcomeOpen = false; controller.run(["forynarch-setup"]); }
                }
            }
            Text { text: "You can open Install Forynarch again from Search (Super + Space)."; color: "#9eafc5"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        }
    }
}
