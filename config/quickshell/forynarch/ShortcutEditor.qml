import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
ColumnLayout {
    id:page
    required property var controller
    property var rows:[]
    property var currentConflicts:[]
    property var editing:null
    property string error:""
    property bool valid:false
    readonly property bool busy:write.running
    function load(){if(!read.running)read.running=true;}
    function edit(row){editing=row;error="";valid=false;keys.text=row.keys;dialog.open();validate.restart();}
    function save(){if(!valid||busy||!editing)return;write.command=["forynarch-shortcut-config","set",editing.id,keys.text];write.running=true;}
    spacing:10
    Component.onCompleted:load()
    Process {id:read;command:["forynarch-shortcut-config","status"]
        stdout:StdioCollector{onStreamFinished:{try{const data=JSON.parse(text);page.rows=data.rows;page.currentConflicts=data.conflicts;}catch(e){page.error="Shortcuts could not be loaded.";}}}
        stderr:StdioCollector{onStreamFinished:if(text.trim())page.error=text.trim()}
    }
    Timer {id:validate;interval:250;onTriggered:{if(check.running){restart();return;}if(page.editing){page.valid=false;check.command=["forynarch-shortcut-config","check",page.editing.id,keys.text];check.running=true;}}}
    Process {id:check
        stdout:StdioCollector{onStreamFinished:{try{const data=JSON.parse(text);page.valid=data.valid;page.error=data.conflicts.map(c=>c.key+" conflicts with "+c.other).join("\n");}catch(e){page.valid=false;}}}
        stderr:StdioCollector{onStreamFinished:if(text.trim()){page.valid=false;page.error=text.trim();}}
    }
    Process {id:write
        stderr:StdioCollector{onStreamFinished:page.error=text.trim()}
        onExited:(code,status)=>{if(code===0){dialog.close();resetDialog.close();page.error="";page.load();controller.refreshShortcutLabels();}else if(!page.error)page.error="The shortcut could not be applied. Your previous binding is unchanged.";}
    }
    RowLayout {
        Layout.fillWidth:true
        Text {text:"System shortcuts";font.pixelSize:20;font.bold:true;color:"#e5efff";Layout.fillWidth:true}
        ActionButton {label:"Restore defaults";implicitHeight:40;onClicked:resetDialog.open()}
    }
    Text {text:"Customize system shortcuts. Conflicts are checked before changes are saved. Application-specific shortcuts are managed by each app.";color:"#b5c9e3";font.pixelSize:12;wrapMode:Text.WordWrap;Layout.fillWidth:true}
    TextField {id:search;Layout.fillWidth:true;implicitHeight:38;placeholderText:"Find an action or shortcut";color:"#dceaff";placeholderTextColor:"#91a8c3";background:Rectangle{radius:10;color:"#203249";border.color:"#38506c"}}
    Text {visible:page.currentConflicts.length>0;text:page.currentConflicts.map(c=>c.key+" · "+c.action+" / "+c.other).join("\n");color:"#ffc2af";wrapMode:Text.WordWrap;Layout.fillWidth:true}
    Text {visible:page.error!==""&&!dialog.visible;text:page.error;color:"#ffc2af";wrapMode:Text.WordWrap;Layout.fillWidth:true}
    Repeater {
        model:page.rows.filter(row=>(row.title+" "+row.keys).toLowerCase().includes(search.text.toLowerCase()))
        Rectangle {
            required property var modelData
            Layout.fillWidth:true;Layout.preferredHeight:56;radius:10;color:"#192637"
            RowLayout {
                anchors.fill:parent;anchors.margins:10;spacing:8
                Text {text:modelData.title;color:"#dfe9f8";font.pixelSize:12;wrapMode:Text.WordWrap;Layout.fillWidth:true;Layout.preferredWidth:1}
                Text {text:modelData.keys||"Unassigned";color:modelData.custom?"#9acbff":"#b5c9e3";font.pixelSize:11;Layout.preferredWidth:190;elide:Text.ElideRight}
                ActionButton {label:"Edit";Accessible.name:"Edit "+modelData.title;implicitHeight:36;onClicked:page.edit(modelData)}
            }
        }
    }
    Popup {
        id:dialog;parent:Overlay.overlay;anchors.centerIn:parent;width:Math.min(parent.width-32,540);padding:24;modal:true;focus:true;closePolicy:Popup.NoAutoClose
        background:Rectangle{radius:18;color:"#111e2e";border.color:"#6483a3"}
        onOpened:{keys.forceActiveFocus();keys.selectAll();}
        onClosed:{validate.stop();page.editing=null;}
        contentItem:ColumnLayout {
            spacing:14
            Text {text:page.editing?.title||"Edit shortcut";color:"#e5efff";font.pixelSize:20;font.bold:true;wrapMode:Text.WordWrap;Layout.fillWidth:true}
            TextField {id:keys;Layout.fillWidth:true;implicitHeight:44;placeholderText:"Unassigned";color:"#dceaff";onAccepted:page.save();onTextEdited:{page.valid=false;validate.restart();}background:Rectangle{radius:10;color:"#203249";border.width:1;border.color:keys.activeFocus?"#9acbff":"#38506c"}}
            Text {text:"Type key names such as Super + Shift + E, F2 or Super + mouse:273.";color:"#b5c9e3";font.pixelSize:12;wrapMode:Text.WordWrap;Layout.fillWidth:true}
            RowLayout {
                ActionButton {label:"Use default";implicitHeight:40;onClicked:{keys.text=page.editing.defaultKeys;page.valid=false;validate.restart();}}
                ActionButton {label:"Disable";implicitHeight:40;onClicked:{keys.text="";page.valid=false;validate.restart();}}
            }
            Text {visible:page.error!=="";text:page.error;wrapMode:Text.WordWrap;color:"#ffc2af";Layout.fillWidth:true;font.pixelSize:12}
            RowLayout {
                Layout.fillWidth:true;Item{Layout.fillWidth:true}
                ActionButton {label:"Cancel";implicitHeight:42;enabled:!page.busy;onClicked:dialog.close();}
                ActionButton {label:"Apply shortcut";implicitHeight:42;selected:true;enabled:page.valid&&!check.running&&!validate.running&&!page.busy;onClicked:page.save()}
            }
        }
    }
    Popup {
        id:resetDialog;parent:Overlay.overlay;anchors.centerIn:parent;width:Math.min(parent.width-32,480);padding:24;modal:true;focus:true;closePolicy:Popup.NoAutoClose
        background:Rectangle{radius:18;color:"#111e2e";border.color:"#6483a3"}
        contentItem:ColumnLayout {
            spacing:16
            Text {text:"Restore system shortcuts?";color:"#e5efff";font.pixelSize:20;Layout.fillWidth:true}
            Text {text:"This removes your Forynarch shortcut overrides. Additional bindings in your own Hyprland files are preserved.";color:"#b5c9e3";wrapMode:Text.WordWrap;Layout.fillWidth:true}
            Text {visible:page.error!=="";text:page.error;color:"#ffc2af";wrapMode:Text.WordWrap;Layout.fillWidth:true}
            RowLayout {Layout.fillWidth:true;Item{Layout.fillWidth:true}
                ActionButton {label:"Cancel";enabled:!page.busy;implicitHeight:42;onClicked:resetDialog.close()}
                ActionButton {label:"Restore defaults";enabled:!page.busy;implicitHeight:42;onClicked:{write.command=["forynarch-shortcut-config","reset-all"];write.running=true;}}
            }
        }
    }
}
