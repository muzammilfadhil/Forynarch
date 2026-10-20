import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
PanelWindow {
    id:window
    required property var controller
    anchors {left:true;right:true;top:true;bottom:true}
    color:"transparent";exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"forynarch-notifications";WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.Exclusive
    MouseArea {anchors.fill:parent;onClicked:controller.notificationsOpen=false}
    Rectangle {
        property real reveal:0
        Component.onCompleted:reveal=1
        opacity:reveal
        Behavior on opacity {enabled:controller.motion;NumberAnimation {duration:120}}
        Accessible.role:Accessible.Pane
        Accessible.name:"Notification center"
        width:Math.min(440,parent.width-32);height:Math.min(680,parent.height-96);x:parent.width-width-10;y:controller.bottomPanel?parent.height-height-64:64
        color:"#111c2b";radius:18;border.color:"#48627f";border.width:1
        MouseArea {anchors.fill:parent}
        FocusScope {anchors.fill:parent;anchors.margins:18;focus:true;Component.onCompleted:forceActiveFocus();Keys.onEscapePressed:controller.notificationsOpen=false
            ColumnLayout {anchors.fill:parent;spacing:12
                RowLayout {Layout.fillWidth:true
                    Text {text:"Notification center";color:"#e5efff";font.pixelSize:18;font.weight:Font.DemiBold;Layout.fillWidth:true}
                    ActionButton {icon:"settings";Accessible.name:"Notification settings";onClicked:controller.openSettings("Notifications")}
                    ActionButton {icon:"close";Accessible.name:"Close notification center";onClicked:controller.notificationsOpen=false}
                }
                ScrollView {id:scroll;Layout.fillWidth:true;Layout.fillHeight:true;clip:true;contentWidth:availableWidth
                    NotificationsPage {width:scroll.availableWidth;controller:window.controller;centerOnly:true}
                }
            }
        }
    }
}
