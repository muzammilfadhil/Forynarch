import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
PanelWindow {
    id:window
    required property var controller
    anchors {left:true;right:true;top:true;bottom:true}
    color:"transparent";exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"forynarch-background-apps";WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.Exclusive
    MouseArea {anchors.fill:parent;onClicked:controller.trayOpen=false}
    FocusScope {anchors.fill:parent;focus:true;Component.onCompleted:forceActiveFocus();Keys.onEscapePressed:controller.trayOpen=false}
    Rectangle {
        readonly property int count:SystemTray.items.values.length
        property real reveal:0
        Component.onCompleted:reveal=1
        opacity:reveal
        Behavior on opacity {enabled:controller.motion;NumberAnimation {duration:100}}
        Accessible.role:Accessible.Pane
        Accessible.name:"Background apps"
        readonly property int columns:Math.max(1,Math.min(4,count))
        width:count?columns*44+(columns-1)*6+20:220
        height:count?Math.min(6,Math.ceil(count/4))*50+14:58
        x:parent.width-width-10;y:controller.bottomPanel?parent.height-height-64:64
        color:"#111c2b";radius:16;border.color:"#48627f";border.width:1
        MouseArea {anchors.fill:parent}
        Text {visible:parent.count===0;anchors.centerIn:parent;text:"No background apps";color:"#b5c9e3";font.pixelSize:13}
        Flickable {id:viewport;anchors.fill:parent;anchors.margins:10;clip:true;contentWidth:width;contentHeight:grid.implicitHeight;boundsBehavior:Flickable.StopAtBounds
            Flow {id:grid;width:viewport.width;spacing:6
                Repeater {model:SystemTray.items
                    Rectangle {
                        id:button
                        required property var modelData
                        width:44;height:44;radius:8;color:pointer.containsMouse||activeFocus?"#29445f":"transparent"
                        border.width:activeFocus?2:0;border.color:controller.accent;activeFocusOnTab:true
                        Behavior on color {enabled:controller.motion;ColorAnimation {duration:90}}
                        Accessible.role:Accessible.Button;Accessible.name:modelData.title||modelData.id
                        function menu() {if(!modelData.hasMenu)return;const point=mapToItem(window.contentItem,width,height);modelData.display(window,point.x,point.y);}
                        function activate() {if(modelData.onlyMenu)menu();else{modelData.activate();controller.trayOpen=false;}}
                        Accessible.onPressAction:activate();Keys.onReturnPressed:activate();Keys.onSpacePressed:activate();Keys.onMenuPressed:menu();Keys.onEscapePressed:controller.trayOpen=false
                        Image {anchors.centerIn:parent;width:22;height:22;source:button.modelData.icon;sourceSize:Qt.size(22,22);fillMode:Image.PreserveAspectFit}
                        ToolTip.visible:pointer.containsMouse
                        ToolTip.text:modelData.title||modelData.id
                        MouseArea {id:pointer;anchors.fill:parent;hoverEnabled:true;acceptedButtons:Qt.LeftButton|Qt.RightButton|Qt.MiddleButton;cursorShape:Qt.PointingHandCursor
                            onClicked:event=>{if(event.button===Qt.RightButton)button.menu();else if(event.button===Qt.MiddleButton)button.modelData.secondaryActivate();else button.activate();}
                            onWheel:event=>button.modelData.scroll(event.angleDelta.y,false)
                        }
                    }
                }
            }
        }
    }
}
