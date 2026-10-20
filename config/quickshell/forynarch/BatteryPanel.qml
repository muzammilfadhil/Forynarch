import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window
    required property var controller
    anchors { top:true; bottom:true; left:true; right:true }
    color:"transparent"; exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"forynarch-battery"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.Exclusive
    MouseArea { anchors.fill:parent; onClicked:controller.dismissBattery() }
    FocusScope {
        anchors.fill:parent; focus:true
        Component.onCompleted:forceActiveFocus()
        Keys.onEscapePressed:controller.dismissBattery()
        MotionSurface {
            controller:window.controller; shown:controller.batteryOpen
            width:Math.min(380,parent.width-24)
            height:Math.min(content.implicitHeight+36,parent.height-controller.panelReserved-32)
            x:parent.width-width-12
            y:controller.bottomPanel?parent.height-height-controller.panelReserved-12:controller.panelReserved+12
            GlassCard { anchors.fill:parent; radius:20; glass:controller.glass; frost:controller.frost; color:controller.glass?"#e6111823":"#111823" }
            MouseArea { anchors.fill:parent }
            ScrollView {
                anchors.fill:parent; anchors.margins:18; clip:true
                contentWidth:availableWidth
                ColumnLayout {
                    id:content; width:parent.width; spacing:14
                    RowLayout {
                        Layout.fillWidth:true
                        Text { Layout.fillWidth:true; text:"Battery & power"; color:"#deebfc"; font.pixelSize:18; font.weight:Font.Medium }
                        ActionButton { icon:"close"; hint:"Close battery details"; showTooltip:false; implicitWidth:36; implicitHeight:36; onClicked:controller.dismissBattery() }
                    }
                    BatteryDetails { Layout.fillWidth:true; controller:window.controller }
                    ActionButton { label:"Power settings"; icon:"settings"; Layout.fillWidth:true; onClicked:controller.openSettings("Power") }
                }
            }
        }
    }
}
