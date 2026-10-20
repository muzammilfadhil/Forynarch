import QtQuick
import Quickshell
import "."
ShellRoot {
    id:test
    property int phase:0
    property int ticks:0
    QtObject{id:controller;property string musicPlayer:"auto";property bool widgets:true;property bool widgetMedia:true;property bool widgetEditing:false;property bool musicLyrics:false}
    QtObject{id:first;property string dbusName:"org.mpris.MediaPlayer2.browser";property string uniqueId:"first";property string trackTitle:"Browser track";property string trackArtist:"Browser artist";property string trackAlbum:"";property bool lengthSupported:true;property real length:120;property real position:0;property bool isPlaying:false;property var metadata:({})}
    QtObject{id:second;property string dbusName:"org.mpris.MediaPlayer2.mudilmusic";property string identity:"Mudil Music";property string desktopEntry:"mudilmusic";property string uniqueId:"second";property string trackTitle:"Fixture track";property string trackArtist:"Fixture artist";property string trackAlbum:"";property bool lengthSupported:true;property real length:120;property real position:0;property bool isPlaying:false;property var metadata:({})}
    QtObject{id:service;property QtObject players:QtObject{property var values:[first,second]}}
    MediaModel{id:model;controller:controller;playerService:service}
    function check(value,message){if(!value)throw new Error(message);}
    Timer{interval:12000;running:true;onTriggered:{console.error("FAIL media flow timeout phase="+test.phase);Qt.exit(1);}}
    Timer{
        interval:200;running:true;repeat:true
        onTriggered:{
            try{
                test.ticks++;
                if(test.phase===0&&test.ticks>=4){
                    check(model.state==="idle"&&!model.lyricsWanted,"Disabled lyrics started a lookup");
                    second.isPlaying=true;
                    check(model.player===second,"Auto selection did not react when Mudil started playing");
                    controller.musicLyrics=true;test.phase=1;test.ticks=0;return;
                }
                if(test.phase===1&&model.state==="ok"){
                    check(model.lines[0].text==="Synthetic lyrics","Lookup result was not displayed");
                    controller.musicLyrics=false;second.trackTitle="Next fixture track";
                    test.phase=2;test.ticks=0;return;
                }
                if(test.phase===2&&test.ticks>=4){
                    check(model.state==="idle"&&model.lines.length===0,"Disabled lyrics kept their state");
                    controller.musicLyrics=true;test.phase=3;return;
                }
                if(test.phase===3&&model.state==="ok"){
                    second.metadata=({"xesam:asText":"[offset:500]\n[00:01.00]Native lyrics fixture\n[00:03.00]Second line"});test.phase=4;test.ticks=0;return;
                }
                if(test.phase===4&&test.ticks>=4){
                    check(model.lines[0].text==="Native lyrics fixture","Embedded lyrics did not replace a lookup");
                    check(model.synced&&model.lines[0].t===0.5,"Embedded LRC timing/offset was lost");
                    second.position=2.6;
                    check(model.lineIndex===1,"Timed lyric did not follow playback position");
                    second.position=0.6;
                    check(model.lineIndex===0,"Timed lyric did not follow backward seek");
                    controller.widgets=false;second.trackTitle="Hidden widget track";
                    test.phase=5;test.ticks=0;return;
                }
                if(test.phase===5&&test.ticks>=4){
                    check(!model.lyricsWanted&&model.state==="idle","Hidden widget kept lyrics active");
                    controller.musicPlayer="mudilmusic";second.isPlaying=false;second.position=37;
                    check(model.player===second&&model.position===37,"Paused player position did not synchronize");
                    second.position=81;
                    check(model.position===81,"Seek while paused broke the position binding");
                    controller.musicPlayer=first.dbusName;first.position=19;
                    check(model.player===first&&model.position===19,"Switching player retained the previous clock");
                    first.position=0;
                    check(model.position===0,"Track restart did not reset the clock");
                    console.log("PASS player position binding, paused seek, player switch, track reset and on-demand lyrics");Qt.quit();
                }
            }catch(error){console.error("FAIL "+error);Qt.exit(1);}
        }
    }
}
