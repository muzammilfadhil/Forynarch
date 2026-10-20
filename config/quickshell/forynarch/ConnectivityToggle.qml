import QtQuick
import QtQuick.Controls
AbstractButton {
    id: control
    property color accent: "#9acbff"
    checkable: true
    opacity: enabled ? 1 : 0.5
    implicitWidth: 52; implicitHeight: 44
    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    contentItem: Item {}
    background: Item {
        Rectangle {
            anchors.centerIn: parent; width: parent.width; height: 28; radius: 14
            color: control.checked ? control.accent : "#23374f"
            border.color: control.activeFocus ? "#e5efff" : "#6483a3"
            border.width: control.activeFocus ? 2 : 1
            Rectangle {x: control.checked ? parent.width-width-4 : 4; y: 4; width: 20; height: 20; radius: 10; color: control.checked ? "#102338" : "#dceaff"}
        }
    }
    Keys.onReturnPressed: {checked = !checked; clicked();}
    Keys.onEnterPressed: {checked = !checked; clicked();}
}
