// MacShell Control Center control geometry, adapted under MIT.
import QtQuick
import QtQuick.Controls

Item {
    id:tile
    required property var center
    required property string controlId
    readonly property var controller:center.controller
    readonly property var quick:controller.quickControlActions
    readonly property var player:controller.player
    readonly property bool small:["bluetooth","airplane","nightshift","keepawake"].includes(controlId)
    readonly property string title:({wifi:"Wi-Fi",focus:"Focus"})[controlId]||""
    readonly property string subtitle:controlId==="wifi"?(!quick.wifiAvailable?"Unavailable":(!quick.wifiOn?"Off":quick.wifiName)):controlId==="focus"?(controller.notificationsDnd?"Do Not Disturb":"Off"):"Screen"
    readonly property string glyph:({wifi:"wifi",bluetooth:"bluetooth",airplane:"airplane",focus:"moon",nightshift:"nightshift",keepawake:"coffee"})[controlId]||""
    readonly property bool checked:({wifi:quick.wifiOn&&quick.wifiAvailable,bluetooth:quick.bluetoothOn,airplane:quick.airplane,focus:controller.notificationsDnd,nightshift:quick.nightLight,keepawake:quick.keepAwake})[controlId]??false
    readonly property bool available:controlId==="wifi"?quick.wifiAvailable:controlId==="bluetooth"?quick.bluetoothAdapters.length>0:controlId==="airplane"?(quick.wifiAvailable||quick.bluetoothAdapters.length>0):controlId==="nightshift"?quick.canNightLight:true
    readonly property string hint:controlId==="wifi"&&!available?"No Wi-Fi adapter":controlId==="bluetooth"&&!available?"No Bluetooth adapter":controlId==="nightshift"&&!available?"Night Shift requires hyprsunset":({wifi:"Toggle Wi-Fi",bluetooth:"Toggle Bluetooth",airplane:"Airplane Mode: Wi-Fi and Bluetooth",focus:"Toggle Do Not Disturb",nightshift:"Night Shift",keepawake:quick.keepAwake?"Allow idle and sleep":"Keep Awake"})[controlId]||""
    function activate(){
        if(!available)return;
        if(controlId==="wifi")quick.toggleWifi();
        else if(controlId==="bluetooth")quick.toggleBluetooth();
        else if(controlId==="airplane")quick.toggleAirplane();
        else if(controlId==="focus")quick.toggleDnd();
        else if(controlId==="keepawake")quick.toggleAwake();
        else if(controlId==="nightshift")quick.toggleNightLight();
    }
    MacControlSurface{anchors.fill:parent;center:tile.center;radius:["display","sound"].includes(tile.controlId)?26:34}
    Loader{
        anchors.fill:parent
        sourceComponent:tile.controlId==="nowplaying"?music:(["display","sound"].includes(tile.controlId)?slider:toggle)
    }
    Component{
        id:toggle
        Item{
            MacControlButton{
                center:tile.center;x:tile.small?(parent.width-width)/2:12;anchors.verticalCenter:parent.verticalCenter
                glyph:tile.glyph;label:tile.hint;checked:tile.checked;enabled:tile.available
                activeColor:"#0a84ff"
                onClicked:tile.activate()
            }
            AbstractButton{
                visible:!tile.small;x:56;width:parent.width-x;height:parent.height
                enabled:tile.controlId==="wifi"||tile.available
                Accessible.name:tile.controlId==="wifi"?"Wi-Fi settings":tile.controlId==="focus"?"Focus settings":tile.hint
                background:Rectangle{color:"transparent";radius:20;border.width:parent.activeFocus?2:0;border.color:"#f5f5f7"}
                onClicked:{if(tile.controlId==="wifi")tile.center.openWifi();else if(tile.controlId==="focus")tile.controller.openSettings("Notifications");else tile.activate();}
                Column{
                    x:6;anchors.verticalCenter:parent.verticalCenter;width:parent.width-20;spacing:1
                    Text{width:parent.width;text:tile.title;color:"#f5f5f7";font.pixelSize:13;font.weight:Font.DemiBold;elide:Text.ElideRight}
                    Text{width:parent.width;text:tile.subtitle;color:"#c5c5c9";font.pixelSize:12;elide:Text.ElideRight}
                }
                MacControlGlyph{visible:tile.controlId==="wifi";x:parent.width-18;width:12;height:12;anchors.verticalCenter:parent.verticalCenter;kind:"chevR";color:"#c5c5c9"}
            }
        }
    }
    Component{
        id:music
        Item{
            Rectangle{
                x:12;y:12;width:52;height:52;radius:10;color:"#3a3a3f"
                MacControlGlyph{visible:album.status!==Image.Ready;anchors.centerIn:parent;width:22;height:22;kind:"note";color:"#c5c5c9"}
                Image{id:album;anchors.fill:parent;source:tile.controller.musicArtwork?(tile.player?.trackArtUrl||""):"";sourceSize:Qt.size(104,104);asynchronous:true;fillMode:Image.PreserveAspectFit}
            }
            Column{
                x:12;y:66;width:parent.width-24;spacing:1
                Text{width:parent.width;text:tile.player?.trackTitle||"Now Playing";textFormat:Text.PlainText;elide:Text.ElideRight;color:tile.player?"#f5f5f7":"#c5c5c9";font.pixelSize:13;font.weight:Font.DemiBold}
                Text{visible:tile.player!==null;width:parent.width;text:tile.player?.trackArtist||"";textFormat:Text.PlainText;elide:Text.ElideRight;color:"#c5c5c9";font.pixelSize:12}
            }
            Row{
                anchors.horizontalCenter:parent.horizontalCenter;y:parent.height-38;spacing:2
                Repeater{
                    model:["prev","play","next"]
                    AbstractButton{
                        required property string modelData
                        width:32;height:30
                        enabled:tile.player!==null&&(modelData==="play"?tile.player.canTogglePlaying:(modelData==="prev"?tile.player.canGoPrevious:tile.player.canGoNext))
                        Accessible.name:modelData==="play"?"Play or pause":modelData==="prev"?"Previous track":"Next track"
                        background:Rectangle{color:"transparent";radius:8;border.width:parent.activeFocus?2:0;border.color:"#f5f5f7"}
                        MacControlGlyph{anchors.centerIn:parent;width:26;height:26;kind:parent.modelData==="play"?(tile.player?.isPlaying?"pause":"play"):parent.modelData;color:"#f5f5f7";opacity:parent.enabled?1:0.4;scale:parent.down?0.88:1;Behavior on scale{NumberAnimation{duration:tile.controller.motion?230:0;easing.type:Easing.OutBack}}}
                        onClicked:{if(modelData==="prev")tile.player.previous();else if(modelData==="next")tile.player.next();else tile.player.togglePlaying();}
                    }
                }
            }
        }
    }
    Component{
        id:slider
        Item{
            Text{x:14;y:8;text:tile.controlId==="sound"?"Sound":"Display";color:"#f5f5f7";font.pixelSize:12;font.weight:Font.DemiBold}
            MacControlSlider{
                x:12;y:28;width:parent.width-24-(tile.controlId==="sound"?36:0)
                glyph:tile.controlId==="sound"?"speaker":"sun"
                label:tile.controlId==="sound"?"Output volume":tile.quick.backlight?"Display brightness":"No brightness control is available on this display"
                value:tile.controlId==="sound"?(tile.controller.audio?.muted?0:(tile.controller.audio?.volume??0)):tile.quick.brightness/100
                enabled:tile.controlId==="sound"?tile.controller.audio!==null:tile.quick.backlight
                onMoved:{if(tile.controlId==="sound")tile.controller.setVolume(value);else tile.quick.setBrightness(value);}
            }
            MacControlButton{
                visible:tile.controlId==="sound";center:tile.center;diameter:28;compact:true
                x:parent.width-40;y:28;glyph:"speaker";label:"Mute output";checked:tile.controller.audio?.muted??false;enabled:tile.controller.audio!==null
                onClicked:tile.controller.audio.muted=!tile.controller.audio.muted
            }
        }
    }
    MouseArea{anchors.fill:parent;acceptedButtons:Qt.RightButton;enabled:controlId==="sound";onClicked:tile.center.openAudio()}
}
