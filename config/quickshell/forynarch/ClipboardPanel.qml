import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
PanelWindow {
    id: panel
    required property var controller
    property var entries:[]
    property string error:""
    anchors{left:true;right:true;top:true;bottom:true}
    color:"transparent";exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"forynarch-clipboard"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.Exclusive
    function refresh(){if(!read.running&&!action.running)read.running=true;}
    function execute(command,id){if(action.running)return;error="";action.command=["forynarch-capture",command].concat(id===undefined?[]:[String(id)]);action.running=true;}
    Component.onCompleted:refresh()
    Timer{interval:1200;repeat:true;running:controller.captureModel.preferences.historyEnabled;onTriggered:panel.refresh()}
    Process{id:read;command:["forynarch-capture","clipboard-list"]
        stdout:StdioCollector{onStreamFinished:{try{const next=JSON.parse(text);if(JSON.stringify(next)!==JSON.stringify(panel.entries))panel.entries=next;}catch(e){panel.error="Clipboard history could not be read.";}}}
    }
    Process{id:action
        stderr:StdioCollector{onStreamFinished:if(text.trim())panel.error=text.trim()}
        onExited:(code,status)=>{if(code===0&&command[1]==="clipboard-copy"){controller.clearPopups();controller.requestFocusReturn();}else panel.refresh();}
    }
    MouseArea{anchors.fill:parent;onClicked:controller.clearPopups()}
    GlassCard {
        anchors.centerIn:parent;width:Math.min(520,parent.width-40);height:Math.min(600,parent.height-40)
        glass:controller.glass;radius:18;focus:true
        Keys.onEscapePressed:controller.clearPopups()
        MouseArea{anchors.fill:parent}
        ColumnLayout {
            anchors.fill:parent;anchors.margins:20;spacing:12
            RowLayout {Layout.fillWidth:true
                Text{text:"Clipboard history";color:"#deebfc";font.pixelSize:21;font.weight:Font.DemiBold;Layout.fillWidth:true}
                ActionButton{icon:"close";hint:"Close";onClicked:controller.clearPopups()}
            }
            SettingRow {Layout.fillWidth:true;title:"Remember copied items";description:"Text and PNG images stay on this device"
                Toggle{checked:controller.captureModel.preferences.historyEnabled;enabled:controller.captureModel.loaded&&!controller.captureModel.busy;Accessible.name:"Remember copied items";onClicked:controller.captureModel.set("historyEnabled",checked)}
            }
            RowLayout{Layout.fillWidth:true
                Text{text:"Select Copy, then paste into your app.";color:"#b5c9e3";font.pixelSize:12;Layout.fillWidth:true}
                ActionButton{label:"Clear everything";hint:"Remove saved entries and clear the current clipboard";enabled:!action.running;onClicked:panel.execute("clipboard-clear")}
            }
            ListView {
                Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:6;model:panel.entries
                ScrollBar.vertical:ScrollBar{policy:ScrollBar.AsNeeded}
                delegate:Rectangle{
                    id:entry;required property var modelData
                    width:ListView.view.width;height:84;radius:8;color:"#172537"
                    RowLayout{anchors.fill:parent;anchors.margins:10;spacing:8
                        Icon{name:entry.modelData.mime==="image/png"?"image":"clipboard";ink:controller.accent;size:22}
                        Text{Layout.fillWidth:true;Layout.fillHeight:true;verticalAlignment:Text.AlignVCenter;text:entry.modelData.preview;textFormat:Text.PlainText;color:"#deebfc";font.pixelSize:12;wrapMode:Text.Wrap;maximumLineCount:3;elide:Text.ElideRight}
                        ActionButton{label:"Copy";enabled:!action.running;onClicked:panel.execute("clipboard-copy",entry.modelData.id)}
                        ActionButton{icon:"trash";hint:"Delete entry";enabled:!action.running;onClicked:panel.execute("clipboard-delete",entry.modelData.id)}
                    }
                }
                Text{anchors.centerIn:parent;visible:panel.entries.length===0;text:controller.captureModel.preferences.historyEnabled?"Copied items will appear here.":"Enable history to remember copied items.";color:"#b5c9e3";font.pixelSize:13}
            }
            Text{Layout.fillWidth:true;visible:panel.error!=="";text:panel.error;color:"#ffc2af";wrapMode:Text.WordWrap}
        }
    }
}
