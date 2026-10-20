import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: picker
    required property var controller
    required property string windowAddress
    property string orientation: "horizontal"
    property string error: ""
    readonly property var primary: controller.windowState.windows.find(window => window.address === windowAddress)
    readonly property var companions: controller.windowState.windows.filter(window => window.address !== windowAddress && !window.minimized)
    readonly property var positions: [
        {id:"left",label:"Left half",x:0,y:0,w:.5,h:1}, {id:"right",label:"Right half",x:.5,y:0,w:.5,h:1},
        {id:"top",label:"Top half",x:0,y:0,w:1,h:.5}, {id:"bottom",label:"Bottom half",x:0,y:.5,w:1,h:.5},
        {id:"top-left",label:"Top left",x:0,y:0,w:.5,h:.5}, {id:"top-right",label:"Top right",x:.5,y:0,w:.5,h:.5},
        {id:"bottom-left",label:"Bottom left",x:0,y:.5,w:.5,h:.5}, {id:"bottom-right",label:"Bottom right",x:.5,y:.5,w:.5,h:.5}
    ]
    anchors { top:true; bottom:true; left:true; right:true }
    color: "transparent"; exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "forynarch-window-layout"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    function arrange(action, companion) {
        if (operation.running) return;
        error = "";
        if (positions.some(position => position.id === action)||action.startsWith("third-")) action = "snap-" + action;
        operation.command = ["forynarch-window-layout", action].concat(["restore","tile-workspace"].includes(action) ? [] : [windowAddress]).concat(companion ? [companion] : []);
        operation.running = true;
    }
    Process {
        id: operation
        stderr: StdioCollector { onStreamFinished: picker.error = text.trim() }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) { picker.controller.layoutOpen = false; picker.controller.refreshWindows(); }
            else if (!picker.error) picker.error = "The arrangement could not be applied. Choose another window and try again.";
        }
    }
    Rectangle { anchors.fill: parent; color: "#59070c15" }
    MouseArea { anchors.fill: parent; onClicked: if (!operation.running) controller.layoutOpen = false }
    GlassCard {
        id: content
        anchors.centerIn: parent
        width: Math.min(parent.width-48, 700); height: Math.min(parent.height-48, 720)
        glass: controller.glass; frost: controller.frost; radius: 20
        focus: true
        Keys.onEscapePressed: if (!operation.running) controller.layoutOpen = false
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 22; spacing: 14
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { text: "Arrange window"; color: "#e5efff"; font.pixelSize: 21; font.weight: Font.DemiBold }
                    Text { text: picker.primary?.title || "Select a window on this workspace"; color: "#90a8c4"; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                }
                ActionButton { icon: "close"; hint: ""; implicitWidth: 34; enabled: !operation.running; Accessible.name: "Close arrangement picker"; onClicked: controller.layoutOpen = false }
            }
        RowLayout {
                Layout.fillWidth:true;spacing:8
                ActionButton {label:"Maximize";icon:"maximize";Layout.fillWidth:true;enabled:!!picker.primary;onClicked:{controller.controlWindow("maximize",windowAddress);controller.layoutOpen=false;}}
                ActionButton {label:"Fullscreen";icon:"maximize";Layout.fillWidth:true;enabled:!!picker.primary;onClicked:{controller.controlWindow("fullscreen",windowAddress);controller.layoutOpen=false;}}
                ActionButton {label:"Minimize";icon:"minimize";Layout.fillWidth:true;enabled:!!picker.primary;onClicked:{controller.controlWindow("minimize",windowAddress);controller.layoutOpen=false;}}
            }
            Text { text: "Position this window"; color: "#dfe9f8"; font.pixelSize: 14; font.weight: Font.Medium }
        Text { visible: picker.primary?.floating || ["floating", "hybrid"].includes(controller.windowMode); text: "Other windows stay where they are. Choose a window below only if you want a pair."; color: "#90a8c4"; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            GridLayout {
                columns: 4; rowSpacing: 8; columnSpacing: 8; Layout.fillWidth: true
                Repeater {
                    model: picker.positions
                    Button {
                        id: position
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 80
                        enabled: !!picker.primary && !operation.running
                        Accessible.name: modelData.label
                        background: Rectangle { radius: 10; color: position.hovered || position.activeFocus ? "#293d56" : "#1a283a"; border.width: position.activeFocus ? 1 : 0; border.color: controller.accent }
                        contentItem: Column {
                            spacing: 5
                            Rectangle {
                                width: 64; height: 34; radius: 4; color: "#0e1723"; anchors.horizontalCenter: parent.horizontalCenter
                                Rectangle { x:2+60*position.modelData.x; y:2+30*position.modelData.y; width:60*position.modelData.w; height:30*position.modelData.h; radius:2; color:controller.accent }
                            }
                            Text { text: position.modelData.label; color: "#dfe9f8"; font.pixelSize: 11; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                        onClicked: picker.arrange(modelData.id, "")
                    }
                }
            }
            RowLayout {
                Layout.fillWidth:true;spacing:8
                Repeater {
                    model:[{id:"third-left",label:"Left third"},{id:"third-middle",label:"Middle third"},{id:"third-right",label:"Right third"}]
                    ActionButton {required property var modelData;label:modelData.label;hint:"Three-column placement";Layout.fillWidth:true;enabled:!!picker.primary&&!operation.running;onClicked:picker.arrange(modelData.id,"")}
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Pair with another window"; color: "#dfe9f8"; font.pixelSize: 14; font.weight: Font.Medium; Layout.fillWidth: true }
                ActionButton { label: "Side by side"; hint: ""; selected: picker.orientation === "horizontal"; onClicked: picker.orientation = "horizontal" }
            ActionButton { label: "Top / bottom"; hint: "Split the screen into upper and lower halves"; selected: picker.orientation === "vertical"; onClicked: picker.orientation = "vertical" }
            }
        Text { text: picker.primary?.floating || ["floating", "hybrid"].includes(controller.windowMode) ? "Floating windows stay independent: move or resize either window freely. Other windows stay open." : "Tiled windows share a divider. Drag it to resize the split."; color: "#90a8c4"; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 5
                model: picker.companions
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: ItemDelegate {
                    id: candidate
                    required property var modelData
                    width: ListView.view.width; height: 48
                    enabled: !!picker.primary && !operation.running
                    Accessible.name: "Pair with " + modelData.title
                    background: Rectangle { radius: 10; color: candidate.hovered || candidate.activeFocus ? "#293d56" : "#162335" }
                    contentItem: RowLayout {
                        Icon { name: candidate.modelData.app === "File Manager" ? "folder" : "desktop"; ink: controller.accent; size: 20 }
                        Text { text: candidate.modelData.title || candidate.modelData.app; color: "#dfe9f8"; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                        Icon { name: "chevron"; size: 16; ink: "#90a8c4" }
                    }
                    onClicked: picker.arrange("pair-" + picker.orientation, modelData.address)
                }
                Text { anchors.centerIn: parent; visible: picker.companions.length === 0; text: "Open another window to create a pair."; color: "#90a8c4"; font.pixelSize: 12 }
            }
            Text { visible: picker.error !== ""; text: picker.error; color: "#ffc2af"; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            RowLayout {
                Layout.fillWidth: true
                ActionButton { label: "Restore arrangement"; hint: ""; enabled: !operation.running; onClicked: picker.arrange("restore", "") }
                ActionButton { label: "Tile open windows"; hint: "Arrange existing windows without overlap"; enabled: !operation.running; onClicked: picker.arrange("tile-workspace", "") }
                Item { Layout.fillWidth: true }
                Text { text: operation.running ? "Arranging…" : "Super + Ctrl + Space"; color: "#90a8c4"; font.pixelSize: 12 }
            }
        }
    }
}
