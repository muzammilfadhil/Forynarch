Timer {
    id:executionFlow
    property int phase:0
property string copiedInstallLog:""
property string expectedLogCopy:""
property bool logClipboardChecked:false
property Process clipboardReader: Process {
    id:logClipboard;command:["wl-paste","--no-newline"]
    stdout:StdioCollector {onStreamFinished:{executionFlow.copiedInstallLog=text;executionFlow.logClipboardChecked=true;}}
}
    interval:150;running:true;repeat:true
    function find(item,label){if(item.text===label&&typeof item.click==="function")return item;for(var child of item.children||[]){var result=find(child,label);if(result)return result;}return null;}
    function fail(message){console.error("FAIL: "+message);Qt.exit(1);}
    onTriggered:{
        if(phase===0){
            if(!app.inventoryReady||discovery.running)return;
            app.info=Object.assign({},app.info,{executorAvailable:true,revision:"fixture",disks:[{id:"serial:fixture-only",path:"/dev/qa-not-a-real-disk",name:"Fixture disk",stableIdentity:true,containsSystem:false,readOnly:false}]});
            app.diskId="serial:fixture-only";app.method="install-erase";app.filesystem="ext4";
            app.fullName="QA Account";app.username="qatest";app.hostname="qa-host";app.password="Fixture password 123!";app.confirmation=app.password;
            app.step=8;app.proposal={canExecute:true,summary:"Fixture disk only",blockers:[]};phase=1;return;
        }
        if(phase===1){
            var begin=find(app.contentItem,"Install Forynarch");if(!begin||!begin.enabled){fail("review action missing");return;}
            begin.click();phase=2;return;
        }
        if(phase===2){
            if(!eraseDialog.visible||!eraseCancel.activeFocus){fail("Cancel must own erase-dialog focus");return;}
            var confirm=find(eraseDialog.contentItem,"Erase disk and install");
            eraseInput.text="ERASE /dev/wrong-disk";if(confirm.enabled){fail("wrong disk accepted");return;}
            eraseInput.text="ERASE /dev/qa-not-a-real-disk";phase=3;return;
        }
        if(phase===3){var confirm=find(eraseDialog.contentItem,"Erase disk and install");if(!confirm.enabled){fail("confirmed disk action disabled");return;}confirm.click();phase=4;return;}
        if(phase===4){
            if(!install.running){fail("fixture executor did not start");return;}
            if(app.password||app.confirmation){fail("password fields not cleared after private handoff");return;}
            var logButton=find(app.contentItem,"Show log");
            if(!logButton||!logButton.enabled){fail("live log cannot open while installing");return;}
            logButton.click();
            if(!app.detailsExpanded||!app.showingInstallationLog){fail("live log did not open");return;}
            app.go(4);if(app.step!==8){fail("navigation unlocked during installation");return;}
            var pause=find(app.contentItem,"Pause updates");if(!pause||!pause.enabled){fail("pause control unavailable");return;}pause.click();
            if(!app.logPaused){fail("pause control did not pause");return;}var frozen=app.installationShownLog;
            app.readInstallEvent({kind:"log",text:"Fixture paused output"});
            if(app.installationShownLog!==frozen){fail("paused output changed");return;}
            pause.click();expectedLogCopy="Fixture resumed output "+Date.now();app.readInstallEvent({kind:"log",text:expectedLogCopy});
            if(app.installationShownLog!==expectedLogCopy||app.installationLogText.indexOf(expectedLogCopy)<0){fail("live log did not resume");return;}
            var copy=find(app.contentItem,"Copy log");if(!copy||!copy.enabled){fail("copy log disabled while installing");return;}copy.click();
            phase=5;return;
        }
        if(phase===5){
            if(install.running)return;
            if(!executionFlow.logClipboardChecked){if(!logClipboard.running)logClipboard.running=true;return;}
            if(executionFlow.copiedInstallLog.indexOf(expectedLogCopy)<0){fail("copied log does not match displayed output");return;}
            var failure=Quickshell.env("FORYNARCH_EXECUTE_FIXTURE_FAILURE");
            if(failure){
                if(failure==="transport"){
                    if(app.installationComplete||app.installationFailedStage!=="download"||app.helperExitCode!==23||app.installationExitCode!==null){fail("missing-report exit state incorrect");return;}
                    if(app.diskStatus!=="Check disk before retrying"||app.error){fail("missing final report claimed an unchanged disk or duplicated error");return;}
                    var show=find(app.contentItem,"Show error details");if(!show){fail("missing-report details action absent");return;}show.click();
                    if(app.diagnosticsText.indexOf("helper 23")<0||app.diagnosticsText.indexOf("fixture helper failed")<0){fail("helper failure details missing");return;}
                    console.log("PASS: helper interruption keeps disk state unknown and preserves helper exit/details");Qt.exit(0);return;
                }
                if(app.installationComplete||app.installationFailedStage!==failure||app.installationExitCode!==17){fail("failure event was lost");return;}
                if(app.diskStatus!==(failure==="flatpak"?"Disk may have changed":"Stopped before disk changes")){fail("incorrect disk status after failure");return;}
                var details=find(app.contentItem,"Show error details");if(!details){fail("error details action missing");return;}
                details.click();
                if(!app.detailsExpanded||app.diagnosticsText.indexOf("fixture download unavailable")<0||app.diagnosticsText.indexOf("Fixture password 123!")>=0){fail("diagnostic output missing or secret leaked");return;}
                if(app.error){fail("failure duplicated in global error banner");return;}
                if(failure==="download"){
                    app.installationDiskChanged=null;
                    if(app.diskStatus!=="Check disk before retrying"){fail("unknown state claimed an unchanged disk");return;}
                }
                console.log("PASS: native "+failure+" failure, accurate disk status, expandable diagnostics and cleared secrets");Qt.exit(0);return;
            }
            if(!app.installationComplete||app.error){fail("completion not tied to successful executor exit");return;}
            console.log("PASS: native erase confirmation, Cancel focus, private stdin handoff, real Process progress and completion");Qt.exit(0);
        }
    }
}
Timer {interval:15000;running:true;onTriggered:{console.error("FAIL: executable UI flow timed out");Qt.exit(1)}}
