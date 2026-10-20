import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray

PanelWindow {
    id: panel
    required property var controller
    required property bool apple
    readonly property bool showMode: !apple&&controller.panelShowMode && width >= 920
    readonly property real sideSpace: Math.max(48, width / 2 - middle.width / 2 - controller.panelSpacing)
    anchors { top: !controller.bottomPanel; bottom: controller.bottomPanel; left: true; right: true }
    margins {top:panel.apple?0:(controller.bottomPanel?0:controller.panelMetrics.topMargin);bottom:panel.apple?0:(controller.bottomPanel?controller.panelMetrics.topMargin:0);left:panel.apple?0:10;right:panel.apple?0:10}
    implicitHeight: panel.apple?controller.panelMetrics.macBarHeight:Math.max(controller.panelMetrics.barHeight,panel.showMode?modeLabels.implicitHeight+8:0)
    exclusiveZone:implicitHeight
    Component.onCompleted:controller.panelActualHeight=implicitHeight
    onImplicitHeightChanged:controller.panelActualHeight=implicitHeight
    color: "transparent"
    WlrLayershell.namespace: "forynarch-panel"
    ScreencopyView { visible: false; captureSource: null; live: false }
    GlassCard { anchors.fill: parent; visible: !(controller.islands&&!panel.apple); glass: controller.glass; frost: controller.frost; radius: panel.apple?0:22 }
    GlassCard {
        id: left
objectName:"panel-left"
visible:controller.panelShowLauncher||panel.showMode||(controller.panelShowApps&&runningApps.applications.length>0)
        x: panel.apple?6:(controller.panelCompact ? middle.x - controller.panelSpacing - width : 0)
        width: leftContents.implicitWidth + 2*controller.panelMetrics.groupPadding
        height: panel.implicitHeight
        glass: controller.glass && (controller.islands&&!panel.apple); frost: controller.frost
        color: (controller.islands&&!panel.apple) ? "#a6111823" : "transparent"
        border.width: (controller.islands&&!panel.apple) ? 1 : 0; radius: panel.apple?0:22
        Row {
            id:leftContents
            anchors.centerIn:parent; spacing:controller.panelMetrics.groupSpacing
            ActionButton {visible:controller.panelShowLauncher; animateHover:controller.motion; anchors.verticalCenter:parent.verticalCenter; icon:"forynarch"; hint:"Open applications · Super+Space"; quiet:true; implicitWidth:30; implicitHeight:Math.min(34,panel.height-4); onClicked:controller.openLauncher() }
            Column {
                id:modeLabels;visible:panel.showMode;width:Math.max(110,Math.min(220,Math.max(modeCaption.implicitWidth,workspaceCaption.implicitWidth))); anchors.verticalCenter:parent.verticalCenter; spacing:0
        transform:Translate{y:Math.max(-(panel.height-modeLabels.implicitHeight)/2,Math.min((panel.height-modeLabels.implicitHeight)/2,controller.panelMetrics.textOffsetY))}
                Text {id:modeCaption;text:"Desktop · " + ({hybrid:"Hybrid",dwindle:"Tiling",master:"Master",scrolling:"Scrolling",floating:"Floating"})[controller.windowMode]; color:"#90a1ba"; font.family:"Adwaita Sans"; font.pixelSize:controller.panelMetrics.modeTextSize }
                Text {id:workspaceCaption;text:"Workspace " + controller.workspace; color:"#deebfc"; font.family:"Adwaita Sans"; font.pixelSize:controller.panelMetrics.workspaceTextSize; font.weight:Font.Medium }
            }
            RunningApplications {
                id: runningApps
                maxWidth: Math.max(0,panel.sideSpace-2*controller.panelMetrics.groupPadding-(controller.panelShowLauncher?30:0)-(panel.showMode?modeLabels.width:0)-controller.panelMetrics.groupSpacing*((panel.showMode?1:0)+(controller.panelShowLauncher?1:0)))
                visible: controller.panelShowApps && applications.length > 0
                width: implicitWidth; height:panel.height-4; anchors.verticalCenter:parent.verticalCenter
                controller: panel.controller; panelWindow: panel
            }
        }
    }
    GlassCard {
        id: middle
        x: (panel.width - width) / 2
        width: visible ? center.implicitWidth + 20 : 0; height: panel.implicitHeight
        visible: controller.panelShowWorkspaces || controller.panelShowClock
        glass: controller.glass && (controller.islands&&!panel.apple); frost: controller.frost
        color: (controller.islands&&!panel.apple) ? "#a6111823" : "transparent"
        border.width: (controller.islands&&!panel.apple) ? 1 : 0; radius: panel.apple?0:22
        RowLayout {
            id: center; anchors.centerIn: parent; spacing: 4
            Row {
                visible: controller.panelShowWorkspaces; spacing: 4
                Repeater {
                    model: 5
                    ActionButton {
                        required property int index
                        animateHover: controller.motion; quiet: true
                        selected: controller.workspace === index + 1; accent: controller.accent
                        label: controller.workspace === index + 1 ? String(index + 1) : "·"
                        Accessible.name: "Workspace " + (index + 1)
                        implicitWidth: controller.workspace === index + 1 ? 32 : 20; implicitHeight: 28; rounding: 14
                        onClicked: controller.run(["forynarch-workspace", "focus", String(index + 1)])
                    }
                }
            }
            Rectangle { visible:controller.panelShowWorkspaces && controller.panelShowClock; Layout.preferredWidth:1; Layout.preferredHeight:16; color:"#354156" }
            ActionButton { visible:controller.panelShowClock; animateHover:controller.motion; label:(panel.width<1200?"":Qt.formatDateTime(controller.now,"ddd, dd MMM") + " · ") + controller.timeText; hint:"Date and time"; quiet:true; implicitHeight:28; onClicked:controller.openSettings("Date & Time") }
        }
    }
    GlassCard {
        id: right
objectName:"panel-right"
visible:controller.panelShowTray||controller.panelShowNotifications||controller.panelShowAudio||controller.panelShowControls||controller.panelShowNetwork||controller.panelShowSettings||controller.panelShowPower||controller.panelShowDesktop||(controller.panelShowBattery&&controller.batteryStatus.batteries.length>0)
        x: panel.apple?panel.width-width-6:(controller.panelCompact ? middle.x + middle.width + controller.panelSpacing : panel.width - width)
        width: controls.implicitWidth + 2*controller.panelMetrics.groupPadding; height: panel.implicitHeight
        glass: controller.glass && (controller.islands&&!panel.apple); frost: controller.frost
        color: (controller.islands&&!panel.apple) ? "#a6111823" : "transparent"
        border.width: (controller.islands&&!panel.apple) ? 1 : 0; radius: panel.apple?0:22
        Row {
            id: controls; anchors.centerIn: parent; spacing: panel.width<900?2:3
            ActionButton {visible:controller.panelShowTray;showTooltip:false;icon:"chevron-up";hint:"Background apps ("+SystemTray.items.values.length+")";quiet:true;implicitWidth:panel.width<900?26:32;implicitHeight:Math.min(34,panel.height-4);selected:controller.trayOpen;onClicked:{let opened=controller.trayOpen;controller.clearPopups();controller.trayOpen=!opened;}}
            ActionButton {visible:controller.panelShowNotifications;showTooltip:false;icon:controller.notificationsDnd?"moon":"bell";hint:controller.notificationsDnd?"Notifications · Do Not Disturb":"Notification center";quiet:true;implicitWidth:panel.width<900?26:32;implicitHeight:Math.min(34,panel.height-4);selected:controller.notificationsOpen;onClicked:controller.openNotifications()
                Rectangle {visible:controller.notificationCount>0;anchors.right:parent.right;anchors.top:parent.top;width:7;height:7;radius:4;color:controller.accent}
            }
            ActionButton {visible:controller.panelShowAudio;showTooltip:false; animateHover:controller.motion; icon:controller.audio?.muted ? "mute" : "volume"; hint:"Sound, outputs and volume mixer";acceptsSecondaryClick:true;onSecondaryClicked:controller.openAdvancedAudio(); quiet:true; implicitWidth:panel.width<900?26:32; implicitHeight:Math.min(34,panel.height-4); selected:controller.controlOpen&&controller.controlAudioRequested; accent:controller.accent; onClicked:controller.openAdvancedAudio() }
            ActionButton {visible:controller.panelShowControls;showTooltip:false;animateHover:controller.motion;icon:"control-center";hint:"Control Center";quiet:true;implicitWidth:panel.width<900?26:32;implicitHeight:Math.min(34,panel.height-4);selected:controller.controlOpen&&!controller.controlAudioRequested;onClicked:{if(controller.controlOpen&&!controller.controlAudioRequested)controller.dismissControls();else controller.openControls();}}
            ActionButton {showTooltip:false; visible:controller.panelShowNetwork; animateHover:controller.motion; icon:"network"; hint:"Network"; quiet:true; implicitWidth:panel.width<900?26:32; implicitHeight:Math.min(34,panel.height-4); onClicked:controller.openSettings("Network") }
            ActionButton {
visible:controller.panelShowBattery&&controller.batteryStatus.batteries.length>0
showTooltip:false;animateHover:controller.motion;icon:"battery"
label:panel.width<1000||controller.batteryStatus.capacity===null?"":Math.round(controller.batteryStatus.capacity)+"%"
hint:"Battery and power";Accessible.name:"Battery and power, "+label+(controller.batteryStatus.charging?", charging":"")
quiet:true;implicitHeight:Math.min(34,panel.height-4);selected:controller.batteryOpen;accent:controller.accent
onClicked:controller.openBattery()
}
ActionButton {visible:controller.panelShowSettings;showTooltip:false; animateHover:controller.motion; icon:"settings"; hint:"Settings"; quiet:true; implicitWidth:panel.width<900?26:32; implicitHeight:Math.min(34,panel.height-4); selected:controller.settingsOpen; accent:controller.accent; onClicked:{if(controller.settingsOpen)controller.dismissSettings();else controller.openSettings("Appearance");} }
            ActionButton {showTooltip:false; visible:controller.panelShowPower; animateHover:controller.motion; icon:"power"; hint:"Session and power"; quiet:true; implicitWidth:panel.width<900?26:32; implicitHeight:Math.min(34,panel.height-4); onClicked:controller.run(["forynarch-power"]) }
            ActionButton {showTooltip:false; visible:controller.panelShowDesktop; animateHover:controller.motion; icon:"desktop"; hint:controller.windowState.desktopShown ? "Restore windows" : "Show desktop"; quiet:true; implicitWidth:panel.width<900?26:32; implicitHeight:Math.min(34,panel.height-4); selected:controller.windowState.desktopShown || false; accent:controller.accent; onClicked:controller.controlWindow("show-desktop","") }
        }
    }
}
