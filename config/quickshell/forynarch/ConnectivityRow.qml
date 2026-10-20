import QtQuick
import QtQuick.Layouts
Rectangle {
    id: row
    property string heading
    property string detail
    property string iconName: "network"
    property bool connected: false
    default property alias actions: buttons.data
    implicitHeight: Math.max(88, copy.implicitHeight + 32)
    color: connected ? "#20334a" : "#172739"
    radius: 12
    border.color: connected ? "#6483a3" : "#304861"
    RowLayout {
        anchors.fill: parent; anchors.margins: 16; spacing: 14
        Icon {name: row.iconName; size: 22; ink: "#9acbff"; Accessible.ignored: true}
        ColumnLayout {
            id: copy; Layout.fillWidth: true; spacing: 6
            Text {Layout.fillWidth: true; text: row.heading; textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere; color: "#e2eeff"; font.pixelSize: 14; font.weight: Font.DemiBold}
            Text {Layout.fillWidth: true; text: row.detail; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: "#b5cbe3"; font.pixelSize: 12}
        }
        RowLayout {id: buttons; spacing: 8}
    }
}
