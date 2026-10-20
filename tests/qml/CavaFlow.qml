Timer {
    id:cavaFlow
    property int phase:0
    interval:200;repeat:true;running:true
    onTriggered:{
        if(!desktop.player||desktop.player.trackTitle!=="Blue Hour QA")return;
        if(phase===0){if(!cavaProcess.running||desktop.cavaValues.length!==16||!desktop.cavaValues.some(value=>value>0))return;console.log("PASS: MPRIS metadata and real PipeWire/Cava spectrum frames");desktop.player.togglePlaying();phase=1;return;}
        if(phase===1){if(cavaProcess.running||desktop.cavaValues.length)return;desktop.player.togglePlaying();desktop.setWidgets(false);phase=2;return;}
        if(phase===2){if(cavaProcess.running){console.error("FAIL: hidden widgets kept Cava running");Qt.exit(1);return;}desktop.setWidgets(true);desktop.setMotion(false);phase=3;return;}
        if(phase===3){if(cavaProcess.running){console.error("FAIL: reduced motion kept Cava running");Qt.exit(1);return;}console.log("PASS: pause, hidden widgets and reduced motion stop Cava");Qt.exit(0);}
    }
}
Timer {interval:14000;running:true;onTriggered:{console.error("FAIL: MPRIS/Cava integration timed out");Qt.exit(1)}}
