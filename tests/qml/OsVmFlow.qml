import QtQuick
import QtQuick.Controls
import Quickshell
import "."

ShellRoot {
    id:test
    property int phase:0
    QtObject {id:mockController;property bool motion:false;property color accent:"#9acbff"}
    function fail(message){console.error("FAIL_OS_VM_UI: "+message);Qt.exit(1);}
    function named(item,name){if(item.objectName===name)return item;for(const child of item.children||[]){const found=named(child,name);if(found)return found;}return null;}
    FloatingWindow {
        implicitWidth:1000;implicitHeight:800;color:"#101c2d";title:"VM settings fixture"
        ScrollView {anchors.fill:parent;anchors.margins:32;contentWidth:availableWidth;VirtualMachinesPage {id:page;width:900;controller:mockController}}
    }
    Timer {interval:60000;running:true;onTriggered:test.fail("Timed out in phase "+test.phase+": "+page.error)}
    Timer {
        interval:150;running:true;repeat:true
        onTriggered:{
            if(page.busy)return;
            if(page.error){test.fail(page.error);return;}
            switch(test.phase){
            case 0:if(page.info.cpus!==4)return;if(page.info.enabled){test.fail("Enabled by default");return;}page.execute("enable",{enabled:true});test.phase=1;break;
            case 1:if(!page.info.enabled)return;page.execute("new",{});test.phase=2;break;
            case 2:if(!page.draft)return;page.change("mode","direct");named(page,"vmGuestNetwork").checked=false;named(page,"vmGuestNetwork").clicked();named(page,"vmGuestAudio").checked=false;named(page,"vmGuestAudio").clicked();page.execute("save",{profile:page.draft});test.phase=3;break;
            case 3:if(!page.draftSaved)return;if(page.info.profiles[0].network!==false||page.info.profiles[0].audio!==false){test.fail("Guest device choices were not saved");return;}page.execute("preflight",{id:page.draft.id});test.phase=4;break;
            case 4:if(!page.review)return;if(named(page,"vmLaunchButton").enabled){test.fail("Direct launch needs consent");return;}named(page,"vmShutdownConsent").checked=true;test.phase=5;break;
            case 5:if(named(page,"vmLaunchButton").enabled){test.fail("Shutdown alone authorized direct writes");return;}named(page,"vmWriteConsent").checked=true;named(page,"vmWritePhrase").text="WRONG";test.phase=6;break;
            case 6:if(named(page,"vmLaunchButton").enabled){test.fail("Wrong phrase authorized writes");return;}named(page,"vmWritePhrase").text="USE REAL DISK";test.phase=7;break;
            case 7:if(!named(page,"vmLaunchButton").enabled){test.fail("Confirmed launch stayed disabled");return;}named(page,"vmLaunchButton").clicked();test.phase=8;break;
            case 8:if(!page.info.states.some(s=>s.active))return;console.log("VM_CONFIG_REVIEW_AND_DIRECT_CONSENT_OK");Qt.quit();break;
            }
        }
    }
}
