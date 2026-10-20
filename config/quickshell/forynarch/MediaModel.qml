// Player selection and on-demand lyrics flow follow MacShell's MacWidgets model (MIT).
import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import "Lyrics.js" as Lyrics
Item {
    id: model
    visible:false
    required property var controller
    property var playerService:Mpris
    readonly property var player: {
        const players=playerService.players.values;
        const preferred=controller.musicPlayer;
        if(preferred==="mudilmusic"){for(const p of players)if([p.identity,p.desktopEntry,p.dbusName].some(value=>String(value||"").toLowerCase().includes("mudil")))return p;return null;}
        if(preferred!=="auto"){for(const p of players)if(p.dbusName===preferred)return p;return null;}
        for(const p of players)if(p.isPlaying)return p;
        return players[0]||null;
    }
    readonly property bool active:controller.widgets&&controller.widgetMedia&&!controller.widgetEditing
    readonly property string trackKey:player?[player.dbusName,player.uniqueId,player.trackTitle,player.trackArtist,player.trackAlbum,player.lengthSupported?Math.round(player.length):0].join("|"):""
    readonly property string embeddedLyrics:typeof player?.metadata?.["xesam:asText"]==="string"?player.metadata["xesam:asText"]:""
    readonly property bool lyricsWanted:active&&controller.musicLyrics&&player!==null
    property var lines:[]
    property bool synced:false
    property string state:"idle"
    property string requestedKey:""
    readonly property real position:{const value=Number(player?.position??0);return Number.isFinite(value)?Math.max(0,value):0;}
    readonly property int lineIndex:{let index=-1;for(let i=0;i<lines.length;i++){if(lines[i].t>=0&&lines[i].t<=position)index=i;}return index;}
    function reset(){lines=[];synced=false;state="idle";if(lyricsWanted)delay.restart();}
    function fetch(){
        if(!lyricsWanted||request.running)return;
        const nativeText=embeddedLyrics;
        if(typeof nativeText==="string"&&nativeText.trim()){
            lines=Lyrics.parse(nativeText);synced=lines.some(line=>line.t>=0);state="ok";if(synced)return;
        }
if(!player.trackTitle){state="none";return;}
        state=lines.length?"ok":"loading";requestedKey=trackKey;
        request.command=["forynarch-media","lyrics",player.trackTitle,player.trackArtist,player.trackAlbum,String(player.lengthSupported?player.length:0)];request.running=true;
    }
    onTrackKeyChanged:reset()
    onEmbeddedLyricsChanged:{if(lyricsWanted&&embeddedLyrics.trim()){if(request.running)request.running=false;reset();}}
    onLyricsWantedChanged:{if(lyricsWanted)reset();else{lines=[];state="idle";delay.stop();if(request.running)request.running=false;}}
    Timer{id:delay;interval:500;onTriggered:model.fetch()}
    Timer{interval:model.lyricsWanted?250:500;repeat:true;running:model.active&&(model.player?.isPlaying??false)
        onTriggered:model.player.positionChanged()
    }
    Process{id:request
stdout:StdioCollector{onStreamFinished:{if(model.requestedKey!==model.trackKey||!model.lyricsWanted)return;try{const result=JSON.parse(text);if(result.synced||!model.embeddedLyrics.trim()){model.lines=result.lines;model.synced=result.synced;model.state=result.state;}}catch(e){if(!model.lines.length)model.state="unavailable";}}}
        onExited:()=>{if(model.lyricsWanted&&model.requestedKey!==model.trackKey)delay.restart();}
    }
}
