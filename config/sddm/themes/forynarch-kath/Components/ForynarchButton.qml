import QtQuick
import QtQuick.Controls
Button {
    id: control
    property bool primary: false
    implicitHeight: 44
    implicitWidth: label.implicitWidth + 28
    contentItem: Text {id: label; text: control.text; textFormat: Text.PlainText; color: "#e2eeff"; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter}
    hoverEnabled: true
    background: NeonFrame {
        fill: control.primary ? "#19354d" : control.hovered ? "#243c55" : "#17283d"
        highlighted: control.activeFocus || control.primary && control.hovered
        reduceMotion: config.ReduceMotion === "true"
    }
    scale: control.down ? 0.98 : 1
    Behavior on scale {NumberAnimation {duration: config.ReduceMotion === "true" ? 0 : 120}}
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
}
