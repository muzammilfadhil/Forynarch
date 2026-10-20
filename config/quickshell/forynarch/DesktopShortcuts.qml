import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: shortcuts
    required property var controller
    property string selected: ""
    Variants {
        model:shortcuts.controller.desktopShortcutEntries
        PanelWindow {
            id:tile
            required property var modelData
            readonly property int slot:shortcuts.controller.desktopShortcutEntries.findIndex(entry=>entry.id===modelData.id)
            readonly property int rows:Math.max(1,Math.floor((screen.height-180)/104))
            screen:Quickshell.screens[0]
            anchors {top:true;right:true}
            margins {top:84+(tile.slot%tile.rows)*104;right:24+Math.floor(tile.slot/tile.rows)*112}
            implicitWidth:100;implicitHeight:96
            color:"transparent";exclusionMode:ExclusionMode.Ignore
            WlrLayershell.namespace:"forynarch-desktop-shortcut"
            WlrLayershell.layer:WlrLayer.Bottom
            WlrLayershell.keyboardFocus:WlrKeyboardFocus.OnDemand
            Rectangle {
                anchors.fill:parent;radius:12
                color:pointer.containsMouse||shortcuts.selected===tile.modelData.id?"#592b435f":"transparent"
                border.width:shortcuts.selected===tile.modelData.id?1:0;border.color:shortcuts.controller.accent
                focus:true
                Accessible.role:Accessible.Button
                Accessible.name:tile.modelData.name
                Accessible.onPressAction:shortcuts.controller.launchDesktopShortcut(tile.modelData)
                Keys.onReturnPressed:shortcuts.controller.launchDesktopShortcut(tile.modelData)
                Keys.onEnterPressed:shortcuts.controller.launchDesktopShortcut(tile.modelData)
                Keys.onEscapePressed:shortcuts.selected=""
                Behavior on color {enabled:shortcuts.controller.motion;ColorAnimation {duration:120}}
                Image {
                    id:icon;source:Quickshell.iconPath(tile.modelData.icon,true);width:40;height:40;sourceSize:Qt.size(48,48);fillMode:Image.PreserveAspectFit
                    anchors {top:parent.top;topMargin:9;horizontalCenter:parent.horizontalCenter}
                    scale:pointer.pressed?0.94:pointer.containsMouse?1.05:1
                    Behavior on scale {enabled:shortcuts.controller.motion;NumberAnimation {duration:120;easing.type:Easing.OutCubic}}
                }
                Text {anchors.centerIn:icon;visible:icon.status!==Image.Ready;text:tile.modelData.name.slice(0,2).toUpperCase();textFormat:Text.PlainText;color:shortcuts.controller.accent;font.pixelSize:22;font.bold:true}
                Text {
                    anchors {left:parent.left;right:parent.right;top:icon.bottom;topMargin:7;leftMargin:4;rightMargin:4}
                    text:tile.modelData.name;textFormat:Text.PlainText;color:"#e5efff";font.pixelSize:12;horizontalAlignment:Text.AlignHCenter;wrapMode:Text.WordWrap;maximumLineCount:2;elide:Text.ElideRight
                }
                MouseArea {
                    id:pointer;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor
                    onClicked:{parent.forceActiveFocus();shortcuts.selected=tile.modelData.id;}
                    onDoubleClicked:shortcuts.controller.launchDesktopShortcut(tile.modelData)
                }
            }
        }
    }
}
