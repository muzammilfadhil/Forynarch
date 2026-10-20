import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
ColumnLayout {
    required property var controller
    spacing:10
    Text{text:"Music widget";color:"#deebfc";font.pixelSize:16;font.weight:Font.DemiBold}
    SettingRow{Layout.fillWidth:true;title:"Show music widget";description:"Turn the music card on or off"
        Toggle{checked:controller.widgetMedia;Accessible.name:"Show music widget";onClicked:controller.setWidget("media",checked)}
    }
    Choice{Layout.fillWidth:true;choices:[{label:"Forynarch",value:"classic"},{label:"MacShell",value:"macshell"}];selectedValue:controller.musicStyle;onChosen:value=>controller.setMusic("musicStyle",value)}
    Text{Layout.fillWidth:true;text:"Player";color:"#b5c9e3";font.pixelSize:12}
    Choice{Layout.fillWidth:true;choices:[{label:"Automatic",value:"auto"},{label:"Mudil Music",value:"mudilmusic"}].concat(Mpris.players.values.filter(p=>!String(p.identity).toLowerCase().includes("mudil")).map(p=>({label:p.identity||p.desktopEntry||"Music player",value:p.dbusName})));selectedValue:controller.musicPlayer;onChosen:value=>controller.setMusic("musicPlayer",value)}
    Repeater{model:[{key:"musicArtwork",title:"Album artwork",detail:"Show the current album cover"},{key:"musicCava",title:"Audio visualizer",detail:"Show Cava in the Forynarch music card"},{key:"musicLyrics",title:"Lyrics",detail:"Show lyrics below the card when available"}]
        SettingRow{required property var modelData;Layout.fillWidth:true;title:modelData.title;description:modelData.detail
            Toggle{checked:controller[modelData.key];Accessible.name:modelData.title;onClicked:controller.setMusic(modelData.key,checked)}
        }
    }
    Text{Layout.fillWidth:true;visible:controller.musicLyrics;text:"Lyrics use player-provided text when available. Otherwise, track and artist names are sent to LRCLIB while this widget is enabled.";color:"#b5c9e3";font.pixelSize:12;wrapMode:Text.WordWrap}
}
