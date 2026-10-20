Process {id:sendProbeKey;command:["hyprctl","dispatch","hl.dsp.send_shortcut({mods=\"\",key=\"a\"})"]}
Process {id:focusDiagnosis;command:["hyprctl","-j","activewindow"];stdout:StdioCollector{onStreamFinished:console.log("Focus diagnosis: "+text)}}
Process {id:readProbe;command:["cat",Quickshell.env("FORYNARCH_FOCUS_PROBE_FILE")];stdout:StdioCollector{onStreamFinished:focusFlow.received=text}}
Timer {id:sendAfterCommit;interval:300;onTriggered:sendProbeKey.running=true}
Timer {
    id:focusFlow
    property int popup:0
    property int phase:0
    property string received:""
    interval:200;running:true;repeat:true
    onTriggered:{
        if(phase===0){
            if(popup===0)desktop.openLauncher();else if(popup===1)desktop.openSettings("Appearance");else if(popup===2)desktop.openControls();else desktop.openDrives();
            phase=1;return;
        }
        if(phase===1){
            if(popup===0){desktop.dismissLauncher();launcherClose.stop();}
            if(popup===1){desktop.dismissSettings();settingsClose.stop();}
            if(popup===2){desktop.dismissControls();controlsClose.stop();}
            if(popup===3){desktop.dismissDrives();drivesClose.stop();}
            sendAfterCommit.restart();phase=2;return;
        }
        if(phase===2){
            if(sendAfterCommit.running||sendProbeKey.running)return;
            readProbe.running=true;phase=4;return;
        }
        if(phase===4){
            if(readProbe.running)return;
            if(received!=="a".repeat(popup+1)){focusDiagnosis.running=true;console.error("FAIL: closing popup retained keyboard focus: "+popup+"; received "+JSON.stringify(received));phase=3;return;}
            desktop.clearPopups();
            if(++popup===4){console.log("PASS: search, settings, controls and drives release keyboard focus before their exit animations end");Qt.exit(0);return;}
            phase=0;
        }
        else if(phase===3)Qt.exit(1);
    }
}
Timer {interval:14000;running:true;onTriggered:{console.error("FAIL: popup focus timed out");Qt.exit(1)}}
