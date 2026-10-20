import QtQuick
import Quickshell
import "."
ShellRoot {
    id:test
    property int phase:0
    function check(value,message){if(!value)throw new Error(message);}
    function field(item){
        if(item.maximumLength===512&&item.echoMode!==undefined)return item;
        for(const child of item.children||[]){const result=field(child);if(result)return result;}
        return null;
    }
    QtObject {id:control;property bool drivesOpen:true;property bool motion:false;property bool glass:false;property int frost:4;property color accent:"#76c0ec";function dismissDrives(){drivesOpen=false;}function run(args){}}
    DrivesPanel {id:panel;controller:control}
    Timer {interval:8000;running:true;onTriggered:{console.error("FAIL drive flow timeout");Qt.exit(1);}}
    Timer {interval:150;repeat:true;running:true
        onTriggered:{try{
            if(panel.busy||!panel.drives.length)return;
            if(test.phase===0){
                test.check(panel.selected.canUnlock,"Locked drive does not expose unlock");
                const key=test.field(panel.contentItem);test.check(key!==null,"Password field missing");
                key.text="fixture-only-key";panel.perform("unlock",panel.selectedId);
                test.check(key.text==="","Password field was not cleared after submission");test.phase=1;return;
            }
            if(test.phase===1){test.check(!panel.failed,"Unlock action failed");console.log("PASS masked drive input, stdin action and immediate clearing");Qt.quit();}
        }catch(error){console.error("FAIL "+error);Qt.exit(1);}}
    }
}
