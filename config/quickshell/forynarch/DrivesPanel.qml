import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: window
    required property var controller
    property var drives: []
    property string selectedId: ""
    property string message: ""
    property bool failed: false
    readonly property var selected: drives.find(d => d.id === selectedId) || null
    readonly property bool busy: scan.running || action.running
    onSelectedChanged: {letter.currentIndex = selected && selected.letter ? letter.model.indexOf(selected.letter+":") : 0;unlockKey.text="";}
    anchors { top:true; bottom:true; left:true; right:true }
    color: "transparent"; focusable:controller.drivesOpen; exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace: "forynarch-drives"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: controller.drivesOpen?WlrKeyboardFocus.Exclusive:WlrKeyboardFocus.None
    function refresh() { if (!busy) scan.running=true; }
    function perform(verb, id, letter) {
        if (busy) return;
        message=""; failed=false;
        action.command=letter ? ["forynarch-drives",verb,id,letter] : ["forynarch-drives",verb,id];
        action.secret=verb==="unlock"?unlockKey.text:"";
        action.stdinEnabled=verb==="unlock";
        action.running=true;
        unlockKey.text="";
    }
    function size(bytes) { return bytes >= 1e12 ? (bytes/1e12).toFixed(1)+" TB" : (bytes/1e9).toFixed(1)+" GB"; }
    Component.onCompleted: refresh()
    Process {
        id: scan; command:["forynarch-drives","list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const v=JSON.parse(text); if(Array.isArray(v)) {window.drives=v; if(!v.some(d=>d.id===window.selectedId)) window.selectedId=v.length?v[0].id:"";} }
                catch(e) {window.message="Drive discovery failed. Try Refresh.";window.failed=true;}
            }
        }
        stderr: StdioCollector { onStreamFinished: {if(text.trim()) {window.message=text.trim();window.failed=true;}} }
    }
    Process {
        id: action
        property string secret: ""
        onRunningChanged: if(running&&stdinEnabled){write(secret+"\n");secret="";stdinEnabled=false;}
        stdout: StdioCollector { onStreamFinished: {if(text.trim()) window.message=text.trim();} }
        stderr: StdioCollector { onStreamFinished: {if(text.trim()) window.message=text.trim();} }
        onExited: (code, status) => {window.failed=code!==0;scan.running=true;}
    }
    IpcHandler {
        target:"drives"
        function status(): string {return JSON.stringify({count:window.drives.length,busy:window.busy,selected:window.selectedId,message:window.message});}
        function refresh(): void {window.refresh();}
    }
    Rectangle {anchors.fill:parent;color:"#59070c15";opacity:surface.progress}
    MouseArea {anchors.fill:parent;onClicked:controller.dismissDrives()}
    MotionSurface {
        id:surface;controller:window.controller;shown:controller.drivesOpen
        anchors.centerIn:parent;width:Math.min(parent.width-64,920);height:Math.min(parent.height-96,620)
        GlassCard {anchors.fill:parent;radius:24;glass:controller.glass;frost:controller.frost}
        MouseArea {anchors.fill:parent}
        FocusScope {
            anchors.fill:parent;focus:true;Component.onCompleted:forceActiveFocus()
            Keys.onEscapePressed:controller.dismissDrives()
            ColumnLayout {
                anchors.fill:parent;anchors.margins:24;spacing:16
                Item {
                    Layout.fillWidth:true;Layout.preferredHeight:48
                    Rectangle {width:46;height:46;radius:16;color:"#294562";Icon {anchors.centerIn:parent;name:"drive";ink:controller.accent;size:24}}
                    ColumnLayout {
                        x:58;width:parent.width-236;spacing:3
                        Text {text:"This Computer";font.pixelSize:22;font.weight:Font.DemiBold;color:"#e5efff"}
                        Text {text:"Your files. Your drives.";font.pixelSize:12;color:"#8fa7c4"}
                    }
                    ActionButton {anchors.right:parent.right;anchors.rightMargin:50;anchors.verticalCenter:parent.verticalCenter;animateHover:controller.motion;icon:"folder";label:"Files";onClicked:{controller.dismissDrives();controller.run(["forynarch-files"]);}}
                    ActionButton {anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;animateHover:controller.motion;icon:"close";hint:"Close · Esc";quiet:true;onClicked:controller.dismissDrives()}
                }
                Rectangle {
                    Layout.fillWidth:true;Layout.preferredHeight:68;radius:16;color:"#1b2d43"
                    RowLayout {
                        anchors.fill:parent;anchors.margins:14;spacing:12
                        Icon {name:"lock";ink:controller.accent;size:22}
                        ColumnLayout {Layout.fillWidth:true;spacing:4
                            Text {text:"Windows-friendly. Read-only by default.";color:"#dcecff";font.pixelSize:13}
                            Text {text:"NTFS and exFAT support · Drive letters use verified mappings";color:"#91aac8";font.pixelSize:11}
                        }
                        ActionButton {animateHover:controller.motion;label:window.busy?"Working…":"Refresh";enabled:!window.busy;onClicked:window.refresh()}
                    }
                }
                RowLayout {
                    Layout.fillWidth:true;Layout.fillHeight:true;spacing:14
                    Item {
                        Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumWidth:0
                        Text {text:"DRIVES · "+window.drives.length;color:"#8fa7c4";font.pixelSize:10;font.letterSpacing:1}
                        ListView {
                            id: driveList
                            anchors {left:parent.left;right:parent.right;top:parent.top;bottom:parent.bottom;topMargin:26}
                            clip:true;spacing:8;model:window.drives
                            ScrollBar.vertical:ScrollBar {}
                            delegate: Rectangle {
                                required property var modelData
                                width:ListView.view.width;height:94;radius:16
                                color:window.selectedId===modelData.id?"#2b4564":"#192637"
                                border.color:window.selectedId===modelData.id?controller.accent:"#2b3e55";border.width:1
                                MouseArea {anchors.fill:parent;onClicked:window.selectedId=modelData.id}
                                RowLayout {
                                    anchors.fill:parent;anchors.margins:16;spacing:14
                                    Rectangle {width:46;height:46;radius:14;color:"#344f70";Icon {anchors.centerIn:parent;name:modelData.locked?"lock":"drive";ink:controller.accent;size:24}}
                                    ColumnLayout {Layout.fillWidth:true;spacing:6
                                        Text {text:modelData.name;Layout.fillWidth:true;elide:Text.ElideRight;color:"#e5efff";font.pixelSize:14;font.weight:Font.DemiBold}
                                        Text {text:modelData.filesystem.toUpperCase()+" · "+window.size(modelData.size);color:"#a4bbd6";font.pixelSize:11}
                                        Text {text:modelData.protected?"System / recovery · Protected":modelData.locked?"Encrypted · Locked":modelData.mounted?(modelData.readOnly?"Mounted · Read-only":"Mounted · Read / write"):"Not mounted";color:modelData.protected||modelData.locked?"#f2cc91":"#a6c9ed";font.pixelSize:11}
                                    }
                                }
                            }
                            Column {
                                parent:driveList
                                anchors.centerIn:parent;width:parent.width-32;spacing:12;visible:window.drives.length===0
                                Icon {anchors.horizontalCenter:parent.horizontalCenter;name:"drive";size:40;ink:"#7897b9"}
                                Text {width:parent.width;text:window.busy?"Looking for drives…":"No data drives found";horizontalAlignment:Text.AlignHCenter;color:"#e0eaff";font.pixelSize:16}
                                Text {width:parent.width;text:"Connect a supported drive, then choose Refresh.\nA VM only sees disks attached to it.";horizontalAlignment:Text.AlignHCenter;wrapMode:Text.WordWrap;color:"#91a8c3";font.pixelSize:12}
                            }
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth:310;Layout.fillHeight:true;radius:18;color:"#172232"
                        ScrollView {
                            id: details;anchors.fill:parent;anchors.margins:18;clip:true;contentWidth:availableWidth;contentHeight:detailColumn.implicitHeight
                            ScrollBar.horizontal.policy:ScrollBar.AlwaysOff
                            ColumnLayout {
                                id:detailColumn;width:details.availableWidth;spacing:12
                                Text {text:window.selected?window.selected.name:"Drive details";Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#e5efff";font.pixelSize:17;font.weight:Font.DemiBold}
                Text {text:window.selected?(window.selected.protected?"This partition is reserved for the system or recovery.":window.selected.locked?"Enter its password or 48-digit BitLocker recovery key. Unlocking is read-only; your key is not saved.":"Mount only when you want to browse. Read-only access keeps existing files intact."):"Choose a drive to view its access mode and Windows alias.";Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#94acc8";font.pixelSize:12}
                                Text {visible:!!window.selected;text:window.selected?window.selected.device:"";color:"#aec5e0";font.pixelSize:11}
                                Text {visible:!!window.selected;text:window.selected?window.selected.mountpoint:"";Layout.fillWidth:true;wrapMode:Text.WrapAnywhere;color:"#94acc8";font.pixelSize:11}
                TextField {
                    id:unlockKey;Layout.fillWidth:true;visible:!!window.selected?.canUnlock
                    placeholderText:"Password or recovery key";echoMode:TextInput.Password
                    maximumLength:512;enabled:!window.busy
                    color:"#e4efff";placeholderTextColor:"#91aac8";font.pixelSize:13;padding:12
                    background:Rectangle {radius:10;color:"#172639";border.width:1;border.color:unlockKey.activeFocus?controller.accent:"#38506c"}
                    Accessible.name:"Drive password or recovery key"
                    onAccepted:if(text.length&&!window.busy)window.perform("unlock",window.selected.id)
                }
                ActionButton {
                    visible:!!window.selected?.canUnlock;Layout.fillWidth:true;label:"Unlock read-only";icon:"lock"
                    enabled:!window.busy&&unlockKey.text.length>0
                    onClicked:window.perform("unlock",window.selected.id)
                }
                                ActionButton {
                                    animateHover:controller.motion;Layout.fillWidth:true;label:window.selected?.mounted?"Open files":"Mount read-only";icon:"folder"
                                    enabled:!window.busy&&!!window.selected&&window.selected.canMount
                                    onClicked:window.perform(window.selected.mounted?"open":"mount-ro",window.selected.id)
                                }
                                ActionButton {
                                    animateHover:controller.motion;Layout.fillWidth:true;label:"Safely unmount";quiet:true
                                    enabled:!window.busy&&!!window.selected&&window.selected.canMount&&window.selected.mounted
                                    onClicked:window.perform("unmount",window.selected.id)
                                }
                                Rectangle {Layout.fillWidth:true;height:1;color:"#30435a"}
                                Text {text:"Windows drive alias";color:"#dceaff";font.pixelSize:13}
                                Text {text:"Choose the same letter shown in Windows. Aliases never rename or format a partition.";Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#94acc8";font.pixelSize:11}
                                RowLayout {Layout.fillWidth:true
                                    ComboBox {
                                        id:letter;model:["Choose…","C:","D:","E:","F:","G:","H:","I:","J:","K:","L:","M:","N:","O:","P:","Q:","R:","S:","T:","U:","V:","W:","X:","Y:","Z:"]
                                        Layout.fillWidth:true;implicitHeight:38;enabled:!!window.selected&&!window.selected.protected;onActivated:window.message=""
                                        contentItem:Text {text:letter.displayText;color:letter.enabled?"#dceaff":"#7890ac";font.pixelSize:12;verticalAlignment:Text.AlignVCenter;leftPadding:12}
                                        background:Rectangle {radius:10;color:"#24374e";border.width:1;border.color:letter.activeFocus?controller.accent:"#38506c"}
                                        indicator:Icon {x:letter.width-width-10;y:(letter.height-height)/2;name:"down";size:14;ink:"#abc9e9"}
                                        popup:Popup {
                                            y:letter.height+6;width:letter.width;height:Math.min(240,contentItem.implicitHeight+12);padding:6
                                            background:Rectangle {color:"#192a3f";radius:12;border.width:1;border.color:"#3d5776"}
                                            contentItem:ListView {clip:true;implicitHeight:contentHeight;model:letter.popup.visible?letter.delegateModel:null;currentIndex:letter.highlightedIndex;ScrollBar.vertical:ScrollBar {}}
                                        }
                                        delegate:ItemDelegate {required property string modelData;required property int index;width:letter.width-12;height:32;highlighted:letter.highlightedIndex===index;contentItem:Text {text:modelData;color:"#e1edff";font.pixelSize:12;verticalAlignment:Text.AlignVCenter} background:Rectangle {radius:7;color:parent.highlighted?"#345678":"transparent"}}
                                    }
                                    ActionButton {animateHover:controller.motion;label:"Save";enabled:letter.currentIndex>0&&!window.busy&&!!window.selected&&!window.selected.protected&&window.selected.id!=="";onClicked:window.perform("alias",window.selected.id,letter.currentText.charAt(0))}
                                }
                                Text {text:"For exact Windows letters, import the map exported from Windows. Never infer C: from disk order.";Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#94acc8";font.pixelSize:11}
                            }
                        }
                    }
                }
                ActionButton {
                    visible:!!window.selected?.encrypted&&!window.selected?.locked
                    Layout.fillWidth:true;label:"Lock drive";icon:"lock";quiet:true
                    enabled:!window.busy&&!window.selected?.mounted
                    onClicked:window.perform("lock",window.selected.id)
                }
                Text {visible:window.message!=="";text:window.message;Layout.fillWidth:true;wrapMode:Text.WordWrap;maximumLineCount:3;elide:Text.ElideRight;color:window.failed?"#f1b8a8":"#b5d5f8";font.pixelSize:11}
            }
        }
    }
}
