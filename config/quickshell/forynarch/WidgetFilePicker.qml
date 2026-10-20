import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Dialog {
    id: picker
    property bool saving: false
    property string currentFolder: ""
    property string parentFolder: ""
    property var entries: []
    property string error: ""
    property bool replacing: false
    signal chosen(string path, bool allowReplace)
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(680,parent.width-40)
    height: Math.min(560,parent.height-40)
    modal: true; focus: true; padding: 20
    closePolicy: Popup.CloseOnEscape
    header: null; footer: null
    background: Rectangle {radius:18;color:"#111d2d";border.color:"#49627f"}
    Overlay.modal: Rectangle {color:"#99050a12"}
    onOpened:if(saving)fileName.forceActiveFocus();else files.forceActiveFocus()
    function load(path) {
        if(read.running)return;
        error="";replacing=false;read.command=["forynarch-widget-packs","browse",path];read.running=true;
    }
    function openPicker(save,name) {
        saving=save;fileName.text=save?name:"";entries=[];error="";replacing=false;
        folderField.text=currentFolder||Quickshell.env("HOME");load(folderField.text);open();
    }
    function choose() {
        const name=fileName.text.trim();
        if(!name||name.includes("/")||name.includes("\\")||name==="."||name==="..") {error="Enter a file name. Choose its folder using the location field above.";return;}
        const filename=saving&&!name.toLowerCase().endsWith(".json")?name+".json":name;
        const existing=entries.find(entry=>entry.name===filename);
        if(existing?.folder){load(currentFolder+"/"+filename);fileName.text="";return;}
        if(!saving&&!existing){error="Select an existing JSON file.";return;}
        if(saving&&existing&&!replacing){replacing=true;error="This file exists. Choose Replace file to overwrite it.";return;}
        chosen(currentFolder+(currentFolder.endsWith("/")?"":"/")+filename,saving&&!!existing);close();
    }
    Process {
        id:read
        stdout:StdioCollector {onStreamFinished:{try{const state=JSON.parse(text);picker.currentFolder=state.folder;picker.parentFolder=state.parent;picker.entries=state.entries;folderField.text=state.folder;}catch(error){picker.error="The folder could not be read.";}}}
        stderr:StdioCollector {onStreamFinished:if(text.trim())picker.error=text.trim()}
    }
    contentItem: ColumnLayout {
        spacing:12
        RowLayout {
            Layout.fillWidth:true
            Text {text:picker.saving?"Export widget pack":"Choose a widget pack";color:"#edf3fc";font.pixelSize:21;font.weight:Font.DemiBold;Layout.fillWidth:true}
            ActionButton {label:"Cancel";onClicked:picker.close()}
        }
        RowLayout {
            Layout.fillWidth:true
            ActionButton {label:"Up";enabled:!read.running&&picker.currentFolder!==picker.parentFolder;onClicked:picker.load(picker.parentFolder)}
            ConnectivityField {id:folderField;Layout.fillWidth:true;enabled:!read.running;Accessible.name:"Folder location";placeholderText:"Folder path";onAccepted:picker.load(text)}
            ActionButton {label:"Go";enabled:!read.running;onClicked:picker.load(folderField.text)}
        }
        ListView {
            id:files;Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:4;model:picker.entries;enabled:!read.running;reuseItems:true;focus:true
            Keys.onReturnPressed:{const entry=picker.entries[currentIndex];if(entry?.folder){picker.load(picker.currentFolder+"/"+entry.name);fileName.text="";}else if(entry){fileName.text=entry.name;picker.choose();}}
            ScrollBar.vertical: ScrollBar {policy:ScrollBar.AsNeeded}
            delegate:Rectangle {
                id:fileRow;required property var modelData;required property int index
                width:ListView.view.width;height:42;radius:8;color:files.currentIndex===index?"#2b435f":pointer.containsMouse?"#203249":"transparent"
                RowLayout {
                    anchors.fill:parent;anchors.leftMargin:10;anchors.rightMargin:10;spacing:10
                    Icon {name:fileRow.modelData.folder?"folder":"desktop";size:19;ink:"#9acbff"}
                    Text {text:fileRow.modelData.name;textFormat:Text.PlainText;color:"#e5efff";font.pixelSize:13;Layout.fillWidth:true;elide:Text.ElideRight}
                    Text {text:fileRow.modelData.folder?"Folder":"JSON pack";color:"#9eafc5";font.pixelSize:11}
                }
                MouseArea {
                    id:pointer;anchors.fill:parent;hoverEnabled:true
                    onClicked:{files.currentIndex=fileRow.index;if(!fileRow.modelData.folder)fileName.text=fileRow.modelData.name;}
                    onDoubleClicked:{if(fileRow.modelData.folder){picker.load(picker.currentFolder+"/"+fileRow.modelData.name);fileName.text="";}else{fileName.text=fileRow.modelData.name;picker.choose();}}
                }
            }
            Text {anchors.centerIn:parent;visible:picker.entries.length===0;text:read.running?"Reading folder…":"No folders or JSON packs here";color:"#9eafc5";font.pixelSize:13}
        }
        Text {text:picker.error;textFormat:Text.PlainText;visible:text!=="";color:picker.replacing?"#edc998":"#ffb6b6";wrapMode:Text.WordWrap;Layout.fillWidth:true;font.pixelSize:12}
        RowLayout {
            Layout.fillWidth:true
            ConnectivityField {id:fileName;Layout.fillWidth:true;placeholderText:"File name.json";Accessible.name:"Widget pack file name";enabled:!read.running;onTextChanged:picker.replacing=false;onAccepted:picker.choose()}
            ActionButton {label:picker.replacing?"Replace file":picker.saving?"Save pack":"Open pack";selected:true;enabled:!read.running&&fileName.text.trim()!=="";onClicked:picker.choose()}
        }
    }
}
