import QtQuick
import QtQuick.Controls

AbstractButton {
    id: toggle
    property color accent: "#9acbff"
    checkable: true
    implicitWidth: 44; implicitHeight: 28
    Accessible.role: Accessible.CheckBox
    background: Rectangle {
        radius: height/2
        color: toggle.checked ? toggle.accent : "#354156"
        border.width: toggle.activeFocus ? 2 : 0; border.color: "#e5efff"
        Rectangle {
            x: toggle.checked ? parent.width-width-4 : 4; y: 4
            width: 20; height: 20; radius: 10
            color: toggle.checked ? "#102338" : "#bcc9dd"
        }
    }
}
