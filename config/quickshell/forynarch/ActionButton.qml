import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Control {
    id: button
    property bool showTooltip:true
    property bool acceptsSecondaryClick:false
    signal secondaryClicked()
    property string label: ""
    property string icon: ""
    property string hint: ""
    property color accent: "#9acbff"
    property bool selected: false
    property bool quiet: false
    property bool leftAligned: false
    property int rounding: 12
    property bool animateHover: false
    signal clicked()
    implicitWidth: content.implicitWidth + (label ? 28 : 20)
    implicitHeight: 38
    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.Button
    Accessible.name: hint || label
    Accessible.onPressAction: if (enabled) clicked()
    opacity: enabled ? 1 : 0.4
    background: Rectangle {
        radius: button.rounding
        color: button.selected ? button.accent : (mouse.containsMouse ? "#293549" : (button.quiet ? "transparent" : "#202b3c"))
        border.width: button.activeFocus && button.focusReason !== Qt.MouseFocusReason ? 2 : mouse.containsMouse ? 1 : 0
        border.color: button.activeFocus && button.focusReason !== Qt.MouseFocusReason ? "#e5efff" : "#91b5dc"
        Behavior on color { enabled:button.animateHover; ColorAnimation { duration:100 } }
    }
    contentItem: Item {
        id: content
        implicitWidth: group.implicitWidth; implicitHeight: group.implicitHeight
        Row {
        id: group; spacing: 9
        anchors.verticalCenter: parent.verticalCenter
        x: button.leftAligned ? 0 : (parent.width-width)/2
        Icon { name: button.icon; visible: name !== ""; size: 18; ink: button.selected ? "#102338" : "#d3dff0" }
        Text {
            text: button.label; visible: text !== ""; textFormat: Text.PlainText
            color: button.selected ? "#102338" : "#d3dff0"
            font.family: "Adwaita Sans"; font.pixelSize: 13; font.weight: Font.Medium
        }
        }
    }
    leftPadding: label ? 12 : 8; rightPadding: label ? 12 : 8
    Keys.onReturnPressed: if (enabled) clicked()
    Keys.onSpacePressed: if (enabled) clicked()
    MouseArea {
        id: mouse; anchors.fill: parent; hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons:Qt.LeftButton|(button.acceptsSecondaryClick?Qt.RightButton:0)
        onClicked:mouse=>{button.forceActiveFocus(Qt.MouseFocusReason);if(mouse.button===Qt.RightButton)button.secondaryClicked();else button.clicked();}
    }
    ToolTip {
        visible: button.showTooltip && mouse.containsMouse && button.hint !== ""
        delay: 700; text: button.hint
        padding: 9
        contentItem: Text { text: button.hint; color: "#dfe9f8"; font.family: "Adwaita Sans"; font.pixelSize: 11 }
        background: Rectangle { radius: 8; color: "#25354b"; border.width: 1; border.color: "#425875" }
    }
}
