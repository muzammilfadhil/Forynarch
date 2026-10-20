import QtQuick
import Quickshell
import "."
ShellRoot {
    id:test
    property int phase:0
    property int ticks:0
    QtObject{id:controller;property bool motion:false;property color accent:"#9acbff"}
    FloatingWindow {
        id:window;implicitWidth:950;implicitHeight:660;color:"#101c2d"
        SystemPage{id:page;anchors.fill:parent;controller:controller;pageTitle:"Displays"}
    }
    function find(root,name){
        if(root.objectName===name)return root;
        for(const child of root.children||[]){const found=find(child,name);if(found)return found;}
        return null;
    }
    function check(value,message){if(!value)throw new Error(message);}
    Timer{interval:35000;running:true;onTriggered:{console.error("FAIL display flow timeout phase="+test.phase);Qt.exit(1);}}
    Timer{
        interval:200;running:true;repeat:true
        onTriggered:{
            try{
                if(page.busy||!page.monitor)return;
                if(test.phase===0){
                    check(page.monitor.width===1920&&page.monitor.height===1080,"Use the dedicated 1920x1080 QA output");
                    const resolution=test.find(page,"displayResolution");
                    resolution.chosen("1280x800");
                    check(page.mode.startsWith("1280x800@"),"Resolution selection did not choose a supported mode");
                    const refresh=test.find(page,"displayRefresh");
                    check(refresh.choices.length>0&&refresh.choices.every(row=>row.value.startsWith("1280x800@")),"Refresh choices include unsupported resolutions");
                    test.find(page,"previewDisplay").clicked();test.phase=1;return;
                }
                if(test.phase===1){
                    if(!page.info.displayPreview.preview)return;
                    check(page.monitor.width===1280&&page.monitor.height===800,"Native resolution did not change");
                    const keep=test.find(page.displayConfirmation.contentItem,"keepDisplay");
                    if(!(keep&&keep.visible&&keep.activeFocus)){
                        if(++test.ticks<15)return;
                        throw new Error("Display confirmation is not visible and keyboard focused: found="+!!keep+" visible="+keep?.visible+" focus="+keep?.activeFocus);
                    }
                    keep.clicked();test.phase=2;return;
                }
                if(test.phase===2){
                    if(page.info.displayPreview.preview)return;
                    test.find(page,"displayResolution").chosen("1920x1080");
                    test.find(page,"previewDisplay").clicked();test.phase=3;return;
                }
                if(test.phase===3){
                    if(!page.info.displayPreview.preview)return;
                    check(page.monitor.width===1920,"Second native preview did not apply");
                    test.phase=4;return;
                }
                if(test.phase===4){
                    if(page.info.displayPreview.preview)return;
                    check(page.monitor.width===1280&&page.monitor.height===800,"Unconfirmed native preview did not roll back");
                    console.log("PASS native resolution selection, per-resolution refresh choices, focused confirmation, keep and watchdog rollback");Qt.quit();
                }
            }catch(error){console.error("FAIL "+error);Qt.exit(1);}
        }
    }
}
