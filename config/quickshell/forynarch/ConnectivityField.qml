import QtQuick
import QtQuick.Controls
TextField {
    id: field
    implicitHeight: 44
    color: "#e2eeff"; placeholderTextColor: "#a2b8d1"
    selectionColor: "#476c94"; selectedTextColor: "#ffffff"
    font.pixelSize: 14; selectByMouse: true
    background: Rectangle {radius: 8; color: "#0d1929"; border.color: field.activeFocus ? "#9acbff" : "#6483a3"; border.width: 1}
}
