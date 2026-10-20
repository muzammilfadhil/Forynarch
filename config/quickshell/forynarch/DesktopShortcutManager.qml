import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id:manager
    required property var controller
    readonly property var applications:DesktopEntries.applications.values.filter(entry=>!query.text||entry.name.toLowerCase().includes(query.text.toLowerCase())).sort((a,b)=>a.name.localeCompare(b.name))
    anchors {top:true;bottom:true;left:true;right:true}
    color:"transparent";exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"forynarch-desktop-shortcuts"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.Exclusive
    Rectangle {anchors.fill:parent;color:"#77050a12"}
    MouseArea {anchors.fill:parent;onClicked:controller.desktopShortcutsOpen=false}
    GlassCard {
        anchors.centerIn:parent;width:Math.min(640,parent.width-40);height:Math.min(680,parent.height-40);radius:22;glass:controller.glass;frost:controller.frost
        focus:true;Keys.onEscapePressed:controller.desktopShortcutsOpen=false
        MouseArea {anchors.fill:parent}
        ColumnLayout {
            anchors.fill:parent;anchors.margins:24;spacing:12
            RowLayout {
                Layout.fillWidth:true
                Text {text:"Desktop shortcuts";color:"#edf3fc";font.pixelSize:23;font.weight:Font.DemiBold;Layout.fillWidth:true}
                ActionButton {label:"Done";onClicked:controller.desktopShortcutsOpen=false}
            }
            SettingRow {
                Layout.fillWidth:true;title:"Show application shortcuts";description:"Optional · off by default"
                Toggle {checked:controller.desktopShortcutsEnabled;Accessible.name:"Show desktop application shortcuts";onClicked:{controller.desktopShortcutsEnabled=checked;controller.save();}}
            }
            Text {text:"Choose up to 32 installed applications. Double-click an icon on the desktop to open it. Turn off the display switch to hide all shortcuts without losing your selection.";color:"#b5c5d9";font.pixelSize:13;wrapMode:Text.WordWrap;Layout.fillWidth:true}
            ConnectivityField {id:query;Layout.fillWidth:true;placeholderText:"Find an application";Accessible.name:"Find an application"}
            ListView {
                Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:6;reuseItems:true
                model:manager.applications
                delegate:Rectangle {
                    id:row
                    required property var modelData
                    width:ListView.view.width;height:62;radius:10;color:"#172638"
                    RowLayout {
                        anchors.fill:parent;anchors.margins:12;spacing:12
                        Image {source:Quickshell.iconPath(row.modelData.icon,true);Layout.preferredWidth:28;Layout.preferredHeight:28;sourceSize:Qt.size(32,32);fillMode:Image.PreserveAspectFit}
                        Text {text:row.modelData.name;textFormat:Text.PlainText;color:"#e5efff";font.pixelSize:14;Layout.fillWidth:true;elide:Text.ElideRight}
                        Toggle {
                            checked:controller.desktopShortcutIds.includes(row.modelData.id)
                            enabled:checked||controller.desktopShortcutIds.length<32
                            Accessible.name:"Add "+row.modelData.name+" to desktop"
                            onClicked:controller.setDesktopShortcut(row.modelData.id,checked)
                        }
                    }
                }
            }
            Text {text:controller.desktopShortcutIds.length+" / 32 selected";color:"#9eafc5";font.pixelSize:12}
        }
    }
}
