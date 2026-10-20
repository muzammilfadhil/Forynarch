import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
PanelWindow {
    id: panel
    required property var controller
    anchors{left:true;right:true;top:true;bottom:true}
    color:"transparent";exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"forynarch-capture"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.Exclusive
    MouseArea{anchors.fill:parent;onClicked:controller.clearPopups()}
    GlassCard {
        anchors.centerIn:parent;width:Math.min(600,parent.width-40);height:Math.min(640,parent.height-40)
        glass:controller.glass;radius:18;focus:true
        Keys.onEscapePressed:controller.clearPopups()
        MouseArea{anchors.fill:parent}
        ColumnLayout {
            anchors.fill:parent;anchors.margins:22;spacing:16
            RowLayout {Layout.fillWidth:true
                Text{text:"Screenshots";color:"#deebfc";font.pixelSize:22;font.weight:Font.DemiBold;Layout.fillWidth:true}
                ActionButton{icon:"close";hint:"Close";onClicked:controller.clearPopups()}
            }
            ScrollView {id:captureScroll;Layout.fillWidth:true;Layout.fillHeight:true;clip:true;contentWidth:Math.max(0,availableWidth-12)
                ScrollBar.vertical.policy:ScrollBar.AlwaysOn
                CapturePage {controller:panel.controller;width:Math.max(0,captureScroll.availableWidth-12)}
            }
        }
    }
}
