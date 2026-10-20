import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "EmojiData.js" as Data
import "EmojiModel.js" as Model
PanelWindow {
    id: picker
    required property var controller
    property string tab: "Emoji"
    property string category: ""
    property string tone: "Default"
    property string emojiFont: Qt.fontFamilies().includes("Apple Color Emoji")?"Apple Color Emoji":"Noto Color Emoji"
    property string emojiFontFile:""
    property string fontError:""
    FontLoader {source:picker.emojiFontFile;onStatusChanged:if(status===FontLoader.Ready){picker.emojiFont=name;picker.savePreferences();}}
    FileDialog {id:fontDialog;title:"Install an emoji font";nameFilters:["Font files (*.ttf *.otf *.ttc)"];onAccepted:{picker.fontError="";fontInstaller.command=["forynarch-emoji-font",selectedFile.toString()];fontInstaller.running=true;}}
    Process {
        id:fontInstaller
        stdout:StdioCollector {onStreamFinished:{try{const result=JSON.parse(text);picker.emojiFontFile=result.file;picker.emojiFont=result.family;picker.savePreferences();}catch(e){}}}
        stderr:StdioCollector {onStreamFinished:picker.fontError=text.trim()}
    }
    property var history: []
    property var gifs: []
    property string gifError: ""
    property bool editingGiphyKey:false
    property string pending: ""
    property bool insertText: true
    readonly property var groups: ["All"].concat([...new Set(Data.rows.map(row=>row.group))])
    readonly property var results: tab === "Emoji" ? Model.search(Data.rows, query.text, category, tone) :
        Model.characters(tab,history,query.text)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { left:true; right:true; top:true; bottom:true }
    WlrLayershell.namespace: "forynarch-emoji"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: controller.emojiOpen?WlrKeyboardFocus.Exclusive:WlrKeyboardFocus.None
    function select(value, gif) {
        if (!gif) { history=Model.recent(value,history); savePreferences(); }
        pending=value;
        controller.emojiClosing=true;controller.emojiOpen=false;
        clipboard.running=true;
    }
    function savePreferences(){preferences.setText(JSON.stringify({history:history,font:emojiFont,fontFile:emojiFontFile,insert:insertText}));}
    function searchGifs() { if (!gifSearch.running) { gifs=[]; gifError=""; gifSearch.running=true; } }
    onTabChanged: { query.text=""; grid.currentIndex=0; if(tab==="GIFs")searchGifs();else{gifs=[];if(gifSearch.running)gifSearch.running=false;} }
    FileView {
        id:preferences; path:(Quickshell.env("XDG_STATE_HOME")||Quickshell.env("HOME")+"/.local/state")+"/forynarch/emoji.json"; printErrors:false
        onLoaded: { try {var v=JSON.parse(text()); if(Array.isArray(v.history))picker.history=v.history.filter(x=>typeof x==="string"&&x.length<128).slice(0,32); if(typeof v.font==="string"&&v.font.length<100)picker.emojiFont=v.font;if(typeof v.fontFile==="string"&&v.fontFile.startsWith("file://"))picker.emojiFontFile=v.fontFile; if(typeof v.insert==="boolean")picker.insertText=v.insert;}catch(e){} }
    }
    Process {
        id:clipboard; command:["forynarch-insert",picker.insertText&&picker.tab!=="GIFs"?"paste":"copy"]; stdinEnabled:true
        onStarted:{write(picker.pending);stdinEnabled=false;}
        onExited:(code,status)=>{if(code!==0)Quickshell.execDetached(["notify-send","Emoji","Could not copy the selection."]);picker.controller.emojiClosing=false;}
    }
    Process {
        id:gifSearch; command:["forynarch-giphy",query.text]
        stdout:StdioCollector { onStreamFinished:{try{var v=JSON.parse(text);picker.gifs=v.items||[];picker.gifError=v.error||"";}catch(e){picker.gifError="GIF search could not be completed.";}} }
    }
    Process {
        id:saveKey; command:["forynarch-emoji-config"]; stdinEnabled:true
        onStarted:{write(JSON.stringify({apiKey:apiKey.text}));stdinEnabled=false;apiKey.clear();}
        onExited:(code,status)=>{if(code===0){picker.editingGiphyKey=false;picker.searchGifs();}else picker.gifError="The API key could not be saved.";}
    }
    MouseArea { anchors.fill:parent; onClicked:controller.closeEmoji() }
    MotionSurface {
        controller:picker.controller; shown:controller.emojiOpen
        anchors.centerIn:parent; width:Math.min(parent.width-24,620); height:Math.min(parent.height-40,680)
        GlassCard {anchors.fill:parent;glass:controller.glass;frost:controller.frost;radius:22}
        MouseArea {anchors.fill:parent}
        ColumnLayout {
            anchors.fill:parent;anchors.margins:20;spacing:12
            RowLayout {
                Text {text:"Express yourself";color:"#e5efff";font.family:"Adwaita Sans";font.pixelSize:20;font.weight:Font.DemiBold;Layout.fillWidth:true}
                ActionButton {icon:"close";hint:"Close emoji picker";onClicked:controller.closeEmoji()}
            }
            Flow {
                Layout.fillWidth:true;Layout.preferredHeight:childrenRect.height;spacing:5
                Repeater {model:["Recent","Emoji","GIFs","Kaomoji","Symbols"]
                    ActionButton {required property string modelData;label:modelData;selected:picker.tab===modelData;animateHover:controller.motion;implicitHeight:40;onClicked:picker.tab=modelData}
                }
            }
            TextField {
                id:query;Layout.fillWidth:true;implicitHeight:44;maximumLength:200;placeholderText:picker.tab==="GIFs"?"Search GIPHY…":picker.tab==="Symbols"?"Find a symbol…":picker.tab==="Kaomoji"?"Find an expression…":"Search emoji…";color:"#e5efff";placeholderTextColor:"#a5b9d2";selectByMouse:true
                Accessible.name:placeholderText
                background:Rectangle {radius:10;color:"#192b42";border.color:query.activeFocus?controller.accent:"#6483a3"}
                Component.onCompleted:forceActiveFocus()
                onTextChanged:grid.currentIndex=0
                Keys.onReturnPressed:{if(picker.tab==="GIFs")picker.searchGifs();else if(picker.results[grid.currentIndex])picker.select(picker.results[grid.currentIndex].value,false);}
                Keys.onDownPressed:{grid.forceActiveFocus();grid.currentIndex=Math.min(picker.results.length-1,grid.currentIndex+grid.columns);}
                Keys.onEscapePressed:controller.closeEmoji()
            }
            RowLayout {
                visible:picker.tab==="Emoji";Layout.fillWidth:true
                Choice {choices:picker.groups.map(name=>({label:name,value:name}));selectedValue:picker.category||"All";Layout.fillWidth:true;Accessible.name:"Emoji category";onChosen:value=>picker.category=value==="All"?"":value}
                Choice {choices:["Default","All","Light","Medium-light","Medium","Medium-dark","Dark"].map(name=>({label:name,value:name}));selectedValue:picker.tone;Accessible.name:"Skin tone";onChosen:value=>picker.tone=value}
            }
            GridView {
                id:grid;readonly property int columns:Math.max(1,Math.floor(width/cellWidth))
                visible:picker.tab!=="GIFs";Layout.fillWidth:true;Layout.fillHeight:true;clip:true
                cellWidth:picker.tab==="Kaomoji"?Math.min(width,250):52;cellHeight:52
                model:picker.results;keyNavigationEnabled:true;currentIndex:0
                ScrollBar.vertical:ScrollBar {policy:ScrollBar.AsNeeded}
                delegate:AbstractButton {
                    id:character
                    required property var modelData;required property int index
                    width:grid.cellWidth-4;height:48;Accessible.name:modelData.name;hoverEnabled:true
                    background:Rectangle {radius:9;color:parent.hovered?"#314d70":"transparent";border.width:grid.currentIndex===index?1:0;border.color:controller.accent}
                    contentItem:Text {text:modelData.value;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;font.family:picker.tab==="Emoji"||picker.tab==="Recent"?picker.emojiFont:"Adwaita Sans";font.pixelSize:picker.tab==="Kaomoji"?16:27;color:"#e5efff"}
                    ToolTip {
                        id:characterTip
                        visible:character.hovered;delay:500;text:character.modelData.name
                        implicitWidth:Math.min(420,contentItem.implicitWidth+leftPadding+rightPadding)
                        contentItem:Text {text:characterTip.text;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:"#e5efff";font.family:"Adwaita Sans";font.pixelSize:12}
                        background:Rectangle {radius:8;color:"#1d3048";border.color:"#91b5dc"}
                    }
                    onClicked:picker.select(modelData.value,false)
                }
                Keys.onReturnPressed:if(picker.results[currentIndex])picker.select(picker.results[currentIndex].value,false)
                Keys.onEscapePressed:controller.closeEmoji()
                Text {anchors.centerIn:parent;visible:picker.results.length===0;text:picker.tab==="Recent"?"Your recent selections appear here.":"No matching characters.";color:"#b5c9e3";wrapMode:Text.WordWrap;width:parent.width;horizontalAlignment:Text.AlignHCenter}
            }
            ColumnLayout {
                visible:picker.tab==="GIFs";Layout.fillWidth:true;Layout.fillHeight:true;spacing:8
                RowLayout {
                    ActionButton {label:gifSearch.running?"Searching…":"Search GIFs";enabled:!gifSearch.running;onClicked:picker.searchGifs()}
                    ActionButton {label:"GIPHY settings";onClicked:picker.editingGiphyKey=!picker.editingGiphyKey}
                    Text {text:"Copies a GIF link. Paste it into your conversation.";Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#b5c9e3";font.pixelSize:11}
                }
                Text {visible:picker.gifError!=="";text:picker.gifError;Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#f2b49b"}
                RowLayout {
                    visible:picker.editingGiphyKey||picker.gifError.includes("API key");Layout.fillWidth:true
                    ConnectivityField {id:apiKey;Layout.fillWidth:true;echoMode:TextInput.Password;placeholderText:"Your GIPHY API key";Accessible.name:"GIPHY API key";maximumLength:128}
                    ActionButton {label:"Save key";enabled:apiKey.text.length>0&&!saveKey.running;onClicked:{saveKey.stdinEnabled=true;saveKey.running=true;}}
                    ActionButton {label:"Clear key";enabled:!saveKey.running;onClicked:{apiKey.clear();saveKey.stdinEnabled=true;saveKey.running=true;}}
                }
                GridView {
                    Layout.fillWidth:true;Layout.fillHeight:true;clip:true;cellWidth:Math.max(1,width/3);cellHeight:110;model:picker.gifs
                    ScrollBar.vertical:ScrollBar{}
                    delegate:AbstractButton {
                        required property var modelData;width:GridView.view.cellWidth-8;height:104;Accessible.name:modelData.title||"GIF";hoverEnabled:true
                        background:Rectangle {radius:8;color:"#192b42";border.color:parent.activeFocus?controller.accent:"#6483a3"}
                        contentItem:Item {
                            Image {anchors.fill:parent;source:modelData.preview;sourceSize:Qt.size(180,100);fillMode:Image.PreserveAspectFit;cache:false;visible:!animation.visible}
                            AnimatedImage {id:animation;anchors.fill:parent;source:visible?modelData.motion:"";visible:parent.parent.hovered&&controller.motion;playing:visible;fillMode:Image.PreserveAspectFit;cache:false}
                        }
                        onClicked:picker.select(modelData.url,true)
                    }
                }
                Image {source:"/usr/share/forynarch/powered-by-giphy.png";Layout.preferredWidth:200;Layout.preferredHeight:25;fillMode:Image.PreserveAspectFit;Layout.alignment:Qt.AlignRight;Accessible.name:"Powered By GIPHY"}
            }
            RowLayout {
                visible:picker.tab!=="GIFs";Layout.fillWidth:true
                ConnectivityCheck {text:"Insert into the active app";checked:picker.insertText;onToggled:{picker.insertText=checked;picker.savePreferences();}}
                Item {Layout.fillWidth:true}
                Text {text:"Super + .";color:"#a5b9d2";font.pixelSize:12}
            }
            Choice {
                visible:picker.tab==="Emoji";Layout.fillWidth:true;Accessible.name:"Emoji font"
                choices:[...new Set(["Noto Color Emoji",picker.emojiFont].concat(Qt.fontFamilies().filter(name=>name.toLowerCase().includes("emoji"))))].map(name=>({label:name,value:name}))
                selectedValue:picker.emojiFont;onChosen:value=>{picker.emojiFont=value;picker.savePreferences();}
            }
            RowLayout {
                visible:picker.tab==="Emoji";Layout.fillWidth:true;spacing:8
                ActionButton {label:fontInstaller.running?"Installing font…":"Install emoji font…";enabled:!fontInstaller.running;onClicked:fontDialog.open()}
                Text {Layout.fillWidth:true;text:"Use a local font you are licensed to use. Apple fonts are not bundled.";color:"#a5b9d2";font.pixelSize:11;wrapMode:Text.WordWrap}
            }
            Text {visible:picker.fontError!=="";text:picker.fontError;color:"#ffc2af";font.pixelSize:11;wrapMode:Text.WordWrap;Layout.fillWidth:true}
            Text {text:"GIFs use the internet. Emoji, symbols and kaomoji work offline.";color:"#a5b9d2";font.pixelSize:11;wrapMode:Text.WordWrap;Layout.fillWidth:true}
        }
    }
}
