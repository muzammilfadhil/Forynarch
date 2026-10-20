import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
Item {
    id: widget
    required property var controller
    width:224;height:controller.musicLyrics?(controller.musicStyle==="macshell"?190:246):130
    readonly property var player:controller.player
    Loader{anchors.left:parent.left;anchors.right:parent.right;height:controller.musicStyle==="macshell"?widget.height:130;sourceComponent:controller.musicStyle==="macshell"?macCard:classicCard}
    Component{id:macCard
        MacPlayerCard {
            width:224;height:widget.height;size:"medium";fam:"Adwaita Sans"
            style:controller.glass?"liquid":"dark";tintOverride:controller.accent
            showArtwork:controller.musicArtwork;motionEnabled:controller.motion
            hasPlayer:widget.player!==null
            title:widget.player?.trackTitle||"Nothing playing"
            artist:widget.player?.trackArtist||(controller.musicPlayer==="mudilmusic"?"Open Mudil Music to play":"Choose a music player")
            album:widget.player?.trackAlbum||"";artUrl:controller.musicArtwork?(widget.player?.trackArtUrl||""):""
            playing:widget.player?.isPlaying??false;position:controller.mediaModel.position
            length:widget.player?.lengthSupported?widget.player.length:0
            canSeek:(widget.player?.canSeek??false)&&(widget.player?.positionSupported??false)
            canShuffle:widget.player?.shuffleSupported??false;canLoop:widget.player?.loopSupported??false
            shuffle:widget.player?.shuffle??false;loop:widget.player?.loopState??0
            lyricsOn:controller.musicLyrics
            lyrics:controller.mediaModel.lines
            lyricsState:controller.mediaModel.lines.length?"ok":controller.mediaModel.state==="loading"?"loading":"none"
            lyricsSynced:controller.mediaModel.synced
            onLyricsToggled:on=>controller.setMusic("musicLyrics",on)
            onTogglePlaying:if(widget.player?.canTogglePlaying)widget.player.togglePlaying()
            onNextTrack:if(widget.player?.canGoNext)widget.player.next()
            onPreviousTrack:if(widget.player?.canGoPrevious)widget.player.previous()
            onSeek:seconds=>{if(canSeek)widget.player.position=seconds;}
            onToggleShuffle:if(canShuffle)widget.player.shuffle=!widget.player.shuffle
            onCycleLoop:if(canLoop)widget.player.loopState=(widget.player.loopState+1)%3
        }
    }
    Component{id:classicCard
        GlassCard {
            width:224;height:130;radius:24;glass:controller.glass;frost:controller.frost
            Column {anchors.fill:parent;anchors.margins:14;spacing:8
                Row {spacing:8
                    Image {visible:controller.musicArtwork&&source!=="";source:controller.musicArtwork?(widget.player?.trackArtUrl||""):"";width:34;height:34;sourceSize:Qt.size(68,68);fillMode:Image.PreserveAspectCrop;asynchronous:true}
                    Icon{visible:!controller.musicArtwork||!(widget.player?.trackArtUrl);name:"music";size:18;ink:controller.accent}
                    Column{spacing:2
                        Text{text:widget.player?.trackTitle||"Nothing playing";textFormat:Text.PlainText;width:controller.musicArtwork&&widget.player?.trackArtUrl?150:160;elide:Text.ElideRight;color:"#deebfc";font.pixelSize:12;font.weight:Font.Medium}
                        Text{text:widget.player?.trackArtist||"Your music appears here";textFormat:Text.PlainText;width:150;elide:Text.ElideRight;color:"#b5c9e3";font.pixelSize:11}
                    }
                }
                CavaMeter{controller:widget.controller;active:controller.musicCava&&!controller.widgetEditing&&controller.widgets&&controller.widgetMedia&&(widget.player?.isPlaying??false);width:190;height:22}
                Row{anchors.horizontalCenter:parent.horizontalCenter;spacing:8
                    ActionButton{animateHover:controller.motion;icon:"previous";hint:"Previous track";implicitWidth:38;implicitHeight:28;quiet:true;enabled:widget.player?.canGoPrevious??false;onClicked:widget.player.previous()}
                    ActionButton{animateHover:controller.motion;icon:widget.player?.isPlaying?"pause":"play";hint:"Play or pause";implicitWidth:52;implicitHeight:28;accent:controller.accent;enabled:widget.player?.canTogglePlaying??false;onClicked:widget.player.togglePlaying()}
                    ActionButton{animateHover:controller.motion;icon:"next";hint:"Next track";implicitWidth:38;implicitHeight:28;quiet:true;enabled:widget.player?.canGoNext??false;onClicked:widget.player.next()}
                }
            }
        }
    }
    GlassCard {
        visible:controller.musicLyrics&&controller.musicStyle!=="macshell";x:0;y:138;width:224;height:108;radius:16;glass:controller.glass
Flickable{anchors.fill:parent;anchors.margins:14;clip:true;contentWidth:width;contentHeight:lyricText.implicitHeight;boundsBehavior:Flickable.StopAtBounds
onContentHeightChanged:contentY=0
Text{id:lyricText;width:parent.width;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:"#deebfc";font.pixelSize:13
text:{const media=controller.mediaModel;if(media.state==="loading")return "Loading lyrics…";if(media.state==="unavailable")return "Lyrics are unavailable offline.";if(media.lines.length===0)return widget.player?"No lyrics available for this track.":"Play a track to see lyrics.";const index=media.synced?Math.max(0,media.lineIndex):0;return media.lines.slice(index,media.synced?index+3:media.lines.length).map(line=>line.text).join("\n");}
}
        }
    }
}
