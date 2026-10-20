import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window
    required property var controller
    anchors { right:true; left:true; top:true; bottom:true }
    mask:Region {x:0;y:controller.bottomPanel?0:controller.panelReserved;width:window.width;height:Math.max(0,window.height-controller.panelReserved)}
    color:"transparent"; focusable:controller.controlOpen; exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"forynarch-controls"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:controller.controlOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    MouseArea { anchors.fill:parent; onClicked:controller.dismissControls() }
    MotionSurface {
        controller:window.controller; shown:controller.controlOpen
        width:Math.min(400,parent.width-32); height:Math.min(content.implicitHeight+40,640,parent.height-96)
        readonly property real barOffset:controller.panelReserved+12
        x:parent.width-width-10; y:controller.bottomPanel ? parent.height-height-barOffset : barOffset
        GlassCard { anchors.fill:parent; glass:controller.glass; frost:controller.frost; radius:24 }
        MouseArea { anchors.fill:parent }
        FocusScope {
            anchors.fill:parent; focus:true; Component.onCompleted:forceActiveFocus()
            Keys.onEscapePressed:controller.dismissControls()
            ScrollView {
                id: scroll; anchors.fill:parent; anchors.margins:20; clip:true
                contentWidth:availableWidth; contentHeight:content.implicitHeight
                ScrollBar.horizontal.policy:ScrollBar.AlwaysOff
                ColumnLayout {
                    id:content; width:scroll.availableWidth; spacing:16
                    ActionButton{visible:!controller.controlAudioRequested;label:"Control Center appearance";icon:"palette";Layout.fillWidth:true;onClicked:controller.openSettings("Panel")}
                    RowLayout {
                        Layout.fillWidth:true
                        Icon { name:"volume"; ink:controller.accent; size:22 }
                        Text { text:"Sound"; Layout.fillWidth:true; color:"#e5efff"; font.pixelSize:18; font.weight:Font.DemiBold }
                        ActionButton { icon:"close"; implicitWidth:32; implicitHeight:32; onClicked:controller.dismissControls() }
                    }
                    AudioOutputs { Layout.fillWidth:true; controller:window.controller }
                    AudioOutputs { Layout.fillWidth:true;controller:window.controller;input:true }
                    RowLayout {
                        Layout.fillWidth:true
                        ActionButton { icon:controller.audio?.muted ? "mute" : "volume"; implicitWidth:34; implicitHeight:34; enabled:controller.audio!==null; onClicked:controller.audio.muted=!controller.audio.muted }
                        ThemedSlider { Layout.fillWidth:true; from:0; to:1; value:controller.audio?.volume ?? 0; enabled:controller.audio!==null; accent:controller.accent; Accessible.name:"Output volume"; onMoved:controller.setVolume(value) }
                        Text { text:Math.round((controller.audio?.volume || 0)*100)+"%"; color:controller.accent; font.pixelSize:13 }
                    }
                    Rectangle { Layout.fillWidth:true; Layout.preferredHeight:1; color:"#2b394e" }
                    AudioMixer { Layout.fillWidth:true; controller:window.controller }
                    ActionButton { label:"All sound settings"; icon:"settings"; onClicked:controller.openSettings("Sound") }
                    Rectangle { visible:!controller.controlAudioRequested;Layout.fillWidth:true; Layout.preferredHeight:1; color:"#2b394e" }
                    RowLayout {
                        visible:!controller.controlAudioRequested
                        Layout.fillWidth:true
                        Text { text:"Glass surfaces"; Layout.fillWidth:true; color:"#c9d9ee"; font.pixelSize:13 }
                        Toggle { checked:controller.glass; accent:controller.accent; Accessible.name:"Glass surfaces"; onClicked:controller.setGlass(checked) }
                    }
                    RowLayout {
                        Layout.fillWidth:true
                        ActionButton { visible:!controller.controlAudioRequested;icon:"network"; label:"Network"; onClicked:controller.openSettings("Network") }
                        Item { Layout.fillWidth:true }
                        ActionButton { visible:!controller.controlAudioRequested;icon:"lock"; hint:"Lock"; showTooltip:false; implicitWidth:38; onClicked:{controller.dismissControls();controller.run(["forynarch-hotkey","lock"]);} }
                        ActionButton { visible:!controller.controlAudioRequested;icon:"power"; hint:"Session and power"; showTooltip:false; implicitWidth:38; onClicked:{controller.dismissControls();controller.run(["forynarch-power"]);} }
                    }
                }
            }
        }
    }
}
