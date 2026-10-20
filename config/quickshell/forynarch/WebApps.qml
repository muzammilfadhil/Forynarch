import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
PanelWindow {
    id:window
    required property var controller
    property var inventory:({apps:[],browsers:[]})
    property string message:""
    property string removing:""
    property string engine:inventory.browsers[0]||""
    anchors {left:true;right:true;top:true;bottom:true}
    color:"transparent";exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"forynarch-webapps"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.Exclusive
    Process {id:inventoryRequest;command:["forynarch-webapps","list"];running:true;stdout:StdioCollector{onStreamFinished:{try{window.inventory=JSON.parse(text);}catch(e){window.message="Web apps could not be loaded.";}}}}
    Process {
        id:create;command:["forynarch-webapps","create"];stdinEnabled:true
        onStarted:{write(JSON.stringify({name:name.text,url:address.text,icon:iconUrl.text,browser:window.engine}));stdinEnabled=false;}
        stdout:StdioCollector{onStreamFinished:{try{var result=JSON.parse(text);window.message=result.error||"Web app added. Find it in Search.";if(result.created){name.clear();address.clear();iconUrl.clear();}}catch(e){window.message="This web app could not be added.";}}}
        onExited:inventoryRequest.running=true
    }
    Process {id:remove;command:["forynarch-webapps","remove",window.removing];onExited:{window.removing="";window.message="Shortcut removed. Its account profile is kept on this computer.";inventoryRequest.running=true;}}
    MouseArea {anchors.fill:parent;onClicked:if(!create.running&&!remove.running)controller.webAppsOpen=false}
    MotionSurface {
        controller:window.controller;shown:controller.webAppsOpen;anchors.centerIn:parent
        width:Math.min(parent.width-32,660);height:Math.min(parent.height-40,720)
        GlassCard {anchors.fill:parent;glass:controller.glass;frost:controller.frost;radius:22}
        MouseArea {anchors.fill:parent}
        ColumnLayout {
            anchors.fill:parent;anchors.margins:24;spacing:12
            RowLayout {
                Text {text:"Your web apps";font.family:"Adwaita Sans";font.pixelSize:22;color:"#e5efff";Layout.fillWidth:true}
                ActionButton {icon:"close";hint:"Close web apps";enabled:!create.running&&!remove.running;onClicked:controller.webAppsOpen=false}
            }
            Text {text:"Give each account its own window. Cookies and site storage stay separate for every web app you create.";color:"#b5c9e3";wrapMode:Text.WordWrap;Layout.fillWidth:true;font.pixelSize:13}
            ConnectivityField {id:name;Layout.fillWidth:true;placeholderText:"App name, for example Work mail";Accessible.name:"Web app name";maximumLength:80}
            ConnectivityField {id:address;Layout.fillWidth:true;placeholderText:"https://example.com";Accessible.name:"Web app address";maximumLength:2048}
            ConnectivityField {id:iconUrl;Layout.fillWidth:true;placeholderText:"PNG icon URL · optional";Accessible.name:"Web app icon URL";maximumLength:2048}
            Choice {Layout.fillWidth:true;choices:window.inventory.browsers.map(value=>({label:({chromium:"Chromium · app window",chrome:"Google Chrome · app window",vivaldi:"Vivaldi · app window",firefox:"Firefox · browser window","chrome-flatpak":"Google Chrome · Flatpak app window","zen-flatpak":"Zen · Flatpak browser window"})[value],value:value}));selectedValue:window.engine;Accessible.name:"Web app browser";onChosen:value=>window.engine=value}
            RowLayout {
                ActionButton {label:create.running?"Adding…":"Add web app";selected:true;implicitHeight:44;enabled:!create.running&&name.text.trim()!==""&&address.text.startsWith("https://")&&window.engine!=="";onClicked:{create.stdinEnabled=true;create.running=true;}}
                Text {text:window.inventory.browsers.length?"No browser or extra background service is added.":"Install Chromium, Vivaldi or Firefox to add a web app.";color:"#a5b9d2";wrapMode:Text.WordWrap;Layout.fillWidth:true;font.pixelSize:11}
            }
            Text {text:window.message;visible:text!=="";color:"#9acbff";wrapMode:Text.WordWrap;Layout.fillWidth:true}
            ListView {
                Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:8;model:window.inventory.apps
                ScrollBar.vertical:ScrollBar{}
                delegate:Rectangle {
                    required property var modelData;width:ListView.view.width;height:72;radius:12;color:"#1d3048"
                    RowLayout {
                        anchors.fill:parent;anchors.margins:12;spacing:10
                        ColumnLayout {Layout.fillWidth:true;spacing:4
                            Text {text:modelData.name;textFormat:Text.PlainText;color:"#e5efff";font.pixelSize:14;Layout.fillWidth:true;elide:Text.ElideRight}
                            Text {text:modelData.url;textFormat:Text.PlainText;color:"#a5b9d2";font.pixelSize:11;Layout.fillWidth:true;elide:Text.ElideRight}
                        }
                        ActionButton {label:"Open";onClicked:controller.run(["forynarch-webapps","launch",modelData.id])}
                        ActionButton {label:window.removing===modelData.id?"Confirm remove":"Remove";hint:"Remove shortcut; keep account data";onClicked:{if(window.removing===modelData.id)remove.running=true;else window.removing=modelData.id;}}
                    }
                }
            }
            Text {text:"Icons are fetched from the site's apple-touch-icon.png, or your PNG address. Dashboard Icons PNG URLs also work. Each account profile uses browser memory while open.";color:"#a5b9d2";font.pixelSize:11;Layout.fillWidth:true;wrapMode:Text.WordWrap}
        }
        Keys.onEscapePressed:if(!create.running&&!remove.running)controller.webAppsOpen=false
    }
}
