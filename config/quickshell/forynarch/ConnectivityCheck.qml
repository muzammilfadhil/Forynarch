import QtQuick
import QtQuick.Controls
CheckBox {
    id: control
    implicitHeight: Math.max(44, contentItem.implicitHeight + 8); spacing: 10
    indicator: Rectangle {
        x: 0; y: (control.height-height)/2; width: 20; height: 20; radius: 4
        color: control.checked ? "#9acbff" : "#142438"
        border.color: control.activeFocus ? "#e5efff" : "#8aabc9"; border.width: control.activeFocus ? 2 : 1
        Text {anchors.centerIn: parent; text: "✓"; visible: control.checked; color: "#102137"; font.pixelSize: 14; font.weight: Font.Bold}
    }
    contentItem: Text {leftPadding: control.indicator.width+control.spacing; text: control.text; textFormat: Text.PlainText; wrapMode: Text.WordWrap; verticalAlignment: Text.AlignVCenter; color: "#dceaff"; font.pixelSize: 13}
    Keys.onReturnPressed: {checked = !checked; toggled();}
    Keys.onEnterPressed: {checked = !checked; toggled();}
}
