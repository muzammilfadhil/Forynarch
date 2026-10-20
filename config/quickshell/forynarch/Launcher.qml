import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "LauncherModel.js" as Search

PanelWindow {
    id: window
    required property var controller
    readonly property var powerActions:[
        {name:"Web apps",genericName:"Add and manage separate web app accounts",icon:"applications-internet",keywords:["install","remove","webapp","account"],command:["forynarch-webapps","open"]},
        {name:"Shut down",genericName:"Turn off this computer",icon:"system-shutdown",keywords:["power","shutdown"],command:["forynarch-power","Shut down"]},
        {name:"Restart",genericName:"Reboot this computer",icon:"system-reboot",keywords:["reboot","power"],command:["forynarch-power","Restart"]},
        {name:"Sleep",genericName:"Suspend this session",icon:"system-suspend",keywords:["suspend","power"],command:["forynarch-power","Sleep"]},
        {name:"Hibernate",genericName:"Save this session to disk, when configured",icon:"system-suspend-hibernate",keywords:["hibernation","power"],command:["forynarch-power","Hibernate"]},
        {name:"Log out",genericName:"Close applications and return to the login screen",icon:"system-log-out",keywords:["logout","sign out","session"],command:["forynarch-power","Sign out"]},
        {name:"Emoji, symbols and GIFs",genericName:"Express yourself · Super + .",icon:"face-smile",keywords:["emoji","giphy","kaomoji"],command:["forynarch-emoji"]}
    ]
    readonly property var results: Search.search(DesktopEntries.applications.values.filter(entry=>!entry.command?.[0]?.endsWith("forynarch-power")).concat(powerActions),query.text,controller.defaultTerminal)
    anchors { top:true; bottom:true; left:true; right:true }
    color: "transparent"; focusable: controller.launcherOpen; exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "forynarch-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: controller.launcherOpen?WlrKeyboardFocus.Exclusive:WlrKeyboardFocus.None
    function launch(entry) {
        controller.dismissLauncher();
        Quickshell.execDetached({command:entry.runInTerminal ? ["forynarch-terminal","--"].concat(entry.command) : entry.command,
            workingDirectory:entry.workingDirectory || Quickshell.env("HOME")});
    }
    function activate() { if(results[list.currentIndex]) launch(results[list.currentIndex]); }
    onResultsChanged: list.currentIndex=0
    IpcHandler {
        target:"launcher"
        function status():string { return JSON.stringify({query:query.text,matches:window.results.map(entry=>entry.name),selected:list.currentIndex,animating:pane.animating,blurActive:pane.blurActive}); }
    }
    Rectangle { anchors.fill: parent; color: "#59070c15"; opacity: pane.progress }
    MouseArea { anchors.fill: parent; onClicked: controller.dismissLauncher() }
    MotionSurface {
        id: pane
        controller: window.controller; shown: window.controller.launcherOpen
        anchors.centerIn: parent
        width: Math.min(parent.width-64,700)
        Behavior on height { enabled:window.controller.motion; NumberAnimation {duration:140;easing.type:Easing.OutCubic} }
        height: Math.min(parent.height-100,query.text ? Math.max(320,252+Math.min(window.results.length,5)*68) : 646)
        GlassCard { anchors.fill:parent; glass:controller.glass; frost:controller.frost; radius:24 }
        MouseArea { anchors.fill:parent }
        ColumnLayout {
            anchors.fill:parent; anchors.margins:24; spacing:16
            RowLayout {
                Layout.fillWidth:true
                Icon { name:"spark"; ink:controller.accent; size:22 }
                Text { text:"Applications"; font.family:"Adwaita Sans"; font.pixelSize:17; font.weight:Font.DemiBold; color:"#e5efff"; Layout.fillWidth:true }
                ActionButton { animateHover:controller.motion; icon:"close"; hint:"Close search · Esc"; quiet:true; implicitWidth:32; implicitHeight:32; onClicked:controller.dismissLauncher() }
            }
            TextField {
                id:query
                Layout.fillWidth:true; implicitHeight:62
                leftPadding:48; rightPadding:16
                placeholderText:"Search apps…"; color:"#e5efff"; placeholderTextColor:"#8196b2"
                font.family:"Adwaita Sans"; font.pixelSize:18
                selectByMouse:true
                Accessible.name:"Search applications"
                background:Rectangle { radius:14; color:"#192332"; border.width:1; border.color:query.activeFocus ? controller.accent : "#354156"; Icon { x:16; anchors.verticalCenter:parent.verticalCenter; name:"search"; size:22; ink:"#8196b2" } }
                Component.onCompleted:forceActiveFocus()
                Keys.onEscapePressed:controller.dismissLauncher()
                Keys.onDownPressed:list.currentIndex=Math.min(window.results.length-1,list.currentIndex+1)
                Keys.onUpPressed:list.currentIndex=Math.max(0,list.currentIndex-1)
                Keys.onReturnPressed:window.activate()
                Keys.onEnterPressed:window.activate()
            }
            RowLayout {
                visible:query.text===""
                Layout.fillWidth:true; spacing:10
                ActionButton { animateHover:controller.motion; icon:"folder"; label:"Files"; Layout.fillWidth:true; onClicked:{controller.dismissLauncher();controller.run(["forynarch-files"]);} }
                ActionButton { animateHover:controller.motion; icon:"drive"; label:"Drives"; Layout.fillWidth:true; onClicked:controller.openDrives() }
                ActionButton { animateHover:controller.motion; icon:"terminal"; label:"Terminal"; Layout.fillWidth:true; onClicked:{controller.dismissLauncher();controller.run(["forynarch-terminal"]);} }
                ActionButton { animateHover:controller.motion; icon:"settings"; label:"Settings"; Layout.fillWidth:true; onClicked:controller.openSettings("Appearance") }
            }
            RowLayout {
                Layout.fillWidth:true
                Text { text:query.text ? "RESULTS" : "ALL APPLICATIONS"; font.family:"Adwaita Sans"; font.pixelSize:10; font.letterSpacing:1.2; color:"#8196b2"; Layout.fillWidth:true }
                Text { text:window.results.length+" apps"; font.family:"Adwaita Sans"; font.pixelSize:11; color:"#8196b2" }
            }
            ListView {
                id:list; Layout.fillWidth:true; Layout.fillHeight:true; clip:true
                model:window.results; spacing:6; currentIndex:0
                ScrollBar.vertical:ScrollBar { policy:ScrollBar.AsNeeded }
                delegate:AbstractButton {
                    id:app
                    required property var modelData
                    required property int index
                    width:list.width; height:62; hoverEnabled:true
                    Accessible.name:modelData.name
                    background:Rectangle { radius:12; color:list.currentIndex===app.index ? "#2b4463" : (app.hovered ? "#223349" : "transparent") }
                    contentItem:RowLayout {
                        spacing:14
                        Rectangle {
                            Layout.preferredWidth:42; Layout.preferredHeight:42; radius:12; color:"#1b2b40"
                            Image { id:appIcon; anchors.centerIn:parent; width:28; height:28; source:Quickshell.iconPath(app.modelData.icon,true); sourceSize:Qt.size(32,32); fillMode:Image.PreserveAspectFit }
                            Text { anchors.centerIn:parent; text:app.modelData.name.trim().split(/\s+/).map(word=>word[0]).slice(0,2).join("").toUpperCase(); font.pixelSize:16; font.weight:Font.DemiBold; color:controller.accent; visible:appIcon.source.toString()==="" || appIcon.status===Image.Error }
                        }
                        ColumnLayout {
                            Layout.fillWidth:true; spacing:4
                            Text { text:app.modelData.name; font.family:"Adwaita Sans"; font.pixelSize:14; font.weight:Font.Medium; color:"#e5efff"; elide:Text.ElideRight; Layout.fillWidth:true }
                            Text { text:app.modelData.genericName || app.modelData.comment || "Application"; font.family:"Adwaita Sans"; font.pixelSize:11; color:"#8fa6c2"; elide:Text.ElideRight; Layout.fillWidth:true }
                        }
                        Icon { name:"chevron"; size:16; ink:"#8196b2" }
                    }
                    padding:10
                    onClicked:window.launch(modelData)
                }
                Text { anchors.centerIn:parent; visible:window.results.length===0; text:"No applications found"; font.family:"Adwaita Sans"; font.pixelSize:15; color:"#8fa6c2" }
            }
            Rectangle { Layout.fillWidth:true; Layout.preferredHeight:1; color:"#29394d" }
            RowLayout {
                Layout.fillWidth:true
                Text { text:"↑ ↓  Navigate     Enter  Open"; font.family:"Adwaita Sans"; font.pixelSize:11; color:"#8fa6c2"; Layout.fillWidth:true }
                Text { text:"Esc  Close"; font.family:"Adwaita Sans"; font.pixelSize:11; color:"#8fa6c2" }
            }
        }
    }
}
