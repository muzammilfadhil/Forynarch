Timer {
    id:widgetFlow
    property int phase:0
    interval:200;running:true;repeat:true
    function fail(message){console.error("FAIL: "+message);Qt.exit(1);}
    onTriggered:{
        if(phase===0){
            desktop.editWidgets();desktop.applyWidgetPack("focus");
            if(!desktop.widgetEnabled("focus")||desktop.widgetMedia){fail("focus pack selection");return;}
            desktop.placeWidget("Virtual-1","focus",399,207,1280,800,1);
            if(!desktop.widgetPositions["Virtual-1"].focus){fail("drag position missing");return;}
            desktop.finishWidgetEdit(false);
            if(desktop.widgetExtras.focus||Object.keys(desktop.widgetPositions).length||!desktop.widgetMedia){fail("Cancel must restore flags, pack and geometry");return;}
            desktop.editWidgets();desktop.applyWidgetPack("laptop");desktop.placeWidget("Virtual-1","battery",399,207,1280,800,1);desktop.finishWidgetEdit(true);phase=1;return;
        }
        if(phase===1){
            if(!desktop.widgetEnabled("battery")||desktop.widgetEnabled("focus")||!desktop.widgetPositions["Virtual-1"]?.battery){fail("saved pack or geometry changed");return;}
            desktop.setWidgets(false);
            if(cavaProcess.running){fail("hidden widgets must stop Cava");return;}
            desktop.setMotion(false);phase=2;return;
        }
        if(phase===2){console.log("PASS: widget pack selection, Cancel restoration, Save persistence and hidden Cava shutdown");Qt.exit(0);}
    }
}
Timer {interval:12000;running:true;onTriggered:{console.error("FAIL: widget flow timed out");Qt.exit(1)}}
