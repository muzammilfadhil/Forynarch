import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: manager
    required property var controller
    property string action: ""
    property string error: ""
    property string notice: ""
    property var reviewedPack: null
    property string reviewedDigest: ""
    property string reviewedPath: ""
    property string exportId: ""
    property string removeId: ""
    property var response: ({})
    anchors { top:true; bottom:true; left:true; right:true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "forynarch-widget-packs"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    function execute(name,args) {
        if(operation.running)return;
        action=name;error="";notice="";response={};operation.command=["forynarch-widget-packs"].concat(args);operation.running=true;
    }
    Process {
        id: operation
        stdout:StdioCollector {onStreamFinished:{try{manager.response=JSON.parse(text);}catch(error){manager.error="The widget pack response could not be read.";}}}
        stderr:StdioCollector {onStreamFinished:if(text.trim())manager.error=text.trim()}
        onExited:(code,status)=>{
            if(code!==0){if(!manager.error)manager.error="The operation could not be completed.";return;}
            if(manager.action==="inspect") {manager.reviewedPack=manager.response.pack;manager.reviewedDigest=manager.response.digest;manager.reviewedPath=pathField.text;return;}
            if(manager.action==="sources") {controller.widgetPacksOpen=false;controller.run(["forynarch-files",manager.response.folder]);return;}
            if(manager.action==="import") {
                const next=Object.assign({},controller.widgetExtras);
                manager.response.pack.widgets.forEach(row=>next["custom:"+manager.response.pack.id+":"+row.id]=false);
                controller.widgetExtras=next;controller.save();manager.reviewedPack=null;pathField.text="";
                manager.notice="Pack imported. Turn on the widgets you want below.";
            }
            if(manager.action==="remove") {
                const next=Object.assign({},controller.widgetExtras);
                Object.keys(next).filter(key=>key.startsWith("custom:"+manager.response.removed+":")).forEach(key=>delete next[key]);
                controller.widgetExtras=next;controller.save();manager.removeId="";manager.notice="Pack removed.";
            }
            if(manager.action==="export")manager.notice="Pack exported. Layout positions and account data were not included.";
            controller.reloadWidgetPacks();
        }
    }
    WidgetFilePicker {
        id:filePicker
        onChosen:(path,allowReplace)=>{
            if(saving)manager.execute("export",["export",manager.exportId,path].concat(allowReplace?["--replace"]:[]));
            else {pathField.text=path;manager.execute("inspect",["inspect",path]);}
        }
    }
    Rectangle {anchors.fill:parent;color:"#77050a12"}
    MouseArea {anchors.fill:parent;onClicked:if(!operation.running)controller.widgetPacksOpen=false}
    GlassCard {
        width:Math.min(760,parent.width-40);height:Math.min(700,parent.height-40);anchors.centerIn:parent;radius:22;glass:controller.glass;frost:controller.frost
        focus:true
        Keys.onEscapePressed:if(!operation.running)controller.widgetPacksOpen=false
        MouseArea {anchors.fill:parent}
        ColumnLayout {
            anchors.fill:parent;anchors.margins:24;spacing:12
            RowLayout {
                Layout.fillWidth:true
                Text {text:"Widget packs";color:"#edf3fc";font.pixelSize:24;font.weight:Font.DemiBold;Layout.fillWidth:true}
                ActionButton {label:"Close";enabled:!operation.running;onClicked:controller.widgetPacksOpen=false}
            }
            Text {text:"Build your own cards, import a community pack, or share an exported copy. Packs contain data only; code, commands and remote resources are not run.";color:"#b5c5d9";font.pixelSize:13;wrapMode:Text.WordWrap;Layout.fillWidth:true}
            RowLayout {
                Layout.fillWidth:true
                ConnectivityField {id:pathField;Layout.fillWidth:true;placeholderText:"Choose a widget pack JSON file";Accessible.name:"Widget pack file";enabled:!operation.running;onTextChanged:manager.reviewedPack=null;onAccepted:manager.execute("inspect",["inspect",text])}
                ActionButton {label:"Choose file";enabled:!operation.running;onClicked:filePicker.openPicker(false,"")}
                ActionButton {label:"Review";enabled:!operation.running&&pathField.text.trim()!=="";onClicked:manager.execute("inspect",["inspect",pathField.text])}
            }
            Rectangle {
                Layout.fillWidth:true;implicitHeight:reviewColumn.implicitHeight+24;radius:12;color:"#203249";visible:!!manager.reviewedPack
                ColumnLayout {
                    id:reviewColumn;anchors.fill:parent;anchors.margins:12;spacing:8
                    Text {text:manager.reviewedPack?.name||"";textFormat:Text.PlainText;color:"#e5efff";font.pixelSize:16;Layout.fillWidth:true;elide:Text.ElideRight}
                    Text {text:(manager.reviewedPack?.author||"")+" · "+(manager.reviewedPack?.license||"")+" · "+(manager.reviewedPack?.widgets.length||0)+" widgets";textFormat:Text.PlainText;color:"#b5c5d9";font.pixelSize:12;Layout.fillWidth:true;elide:Text.ElideRight}
                    RowLayout {
                        Text {text:"Imported widgets start switched off.";color:"#b5c5d9";font.pixelSize:12;Layout.fillWidth:true;wrapMode:Text.WordWrap}
                        ActionButton {label:"Import pack";selected:true;enabled:!operation.running;onClicked:manager.execute("import",["import",manager.reviewedPath,"--expected-digest",manager.reviewedDigest])}
                    }
                }
            }
            Text {text:manager.error||manager.notice;textFormat:Text.PlainText;visible:text!=="";color:manager.error?"#ffb6b6":"#a9d5f8";wrapMode:Text.WordWrap;font.pixelSize:12;Layout.fillWidth:true;Accessible.role:Accessible.AlertMessage}
            Text {text:controller.packWarnings.join("\n");textFormat:Text.PlainText;visible:text!=="";color:"#edc998";wrapMode:Text.WordWrap;font.pixelSize:12;Layout.fillWidth:true;maximumLineCount:3;elide:Text.ElideRight}
            ScrollView {
                Layout.fillWidth:true;Layout.fillHeight:true;clip:true;contentWidth:availableWidth
                ColumnLayout {
                    width:parent.width;spacing:12
                    Text {text:"No imported packs yet. Start with the Workday example.";visible:controller.importedPacks.length===0;color:"#9eafc5";font.pixelSize:13;Layout.fillWidth:true;wrapMode:Text.WordWrap}
                    Repeater {
                        model:controller.importedPacks
                        Rectangle {
                            id:packCard
                            required property var modelData
                            Layout.fillWidth:true;implicitHeight:packContent.implicitHeight+24;radius:12;color:"#172638";border.color:"#30435b"
                            ColumnLayout {
                                id:packContent;anchors.fill:parent;anchors.margins:12;spacing:8
                                RowLayout {
                                    Text {text:packCard.modelData.name;textFormat:Text.PlainText;color:"#e5efff";font.pixelSize:16;Layout.fillWidth:true;elide:Text.ElideRight}
                                    ActionButton {label:"Export";enabled:!operation.running;onClicked:{manager.exportId=packCard.modelData.id;filePicker.openPicker(true,manager.exportId+".json");}}
                                    ActionButton {label:"Remove";enabled:!operation.running;onClicked:manager.removeId=packCard.modelData.id}
                                }
                                Text {text:packCard.modelData.author+" · "+packCard.modelData.license;textFormat:Text.PlainText;color:"#9eafc5";font.pixelSize:11;Layout.fillWidth:true;elide:Text.ElideRight}
                                Repeater {
                                    model:packCard.modelData.widgets
                                    SettingRow {
                                        required property var modelData
                                        Layout.fillWidth:true;title:modelData.name;description:"Custom widget"
                                        Toggle {checked:controller.widgetEnabled("custom:"+packCard.modelData.id+":"+modelData.id);Accessible.name:"Show "+modelData.name;onClicked:controller.setWidget("custom:"+packCard.modelData.id+":"+modelData.id,checked)}
                                    }
                                }
                                RowLayout {
                                    visible:manager.removeId===packCard.modelData.id;Layout.fillWidth:true
                                    Text {text:"Remove this pack and its desktop widgets?";color:"#edc998";font.pixelSize:12;wrapMode:Text.WordWrap;Layout.fillWidth:true}
                                    ActionButton {label:"Keep";enabled:!operation.running;onClicked:manager.removeId=""}
                                    ActionButton {label:"Remove pack";enabled:!operation.running;onClicked:manager.execute("remove",["remove",packCard.modelData.id])}
                                }
                            }
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth:true
                ActionButton {label:"Workday example";enabled:!operation.running;onClicked:{pathField.text="/usr/share/forynarch/widget-packs/workday.json";manager.execute("inspect",["inspect",pathField.text]);}}
            ActionButton {label:"Open packs folder";onClicked:{controller.widgetPacksOpen=false;controller.run(["forynarch-files",controller.packFolder]);}}
                ActionButton {label:"Edit widget source";enabled:!operation.running;onClicked:manager.execute("sources",["sources"])}
                Item {Layout.fillWidth:true}
                ActionButton {label:"Edit layout";enabled:controller.importedPacks.length>0&&!operation.running;onClicked:{controller.widgetPacksOpen=false;controller.editWidgets();}}
            }
        }
    }
}
