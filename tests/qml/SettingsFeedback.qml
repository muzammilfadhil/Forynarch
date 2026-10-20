// Run through tests/run-settings-feedback.sh inside an existing Arch desktop.
// Uses the real Settings component and Process collectors, without changing settings.
import QtQuick
import Quickshell
import "."

ShellRoot {
    id:test
    property int phase:0
    QtObject {id:mockController;property bool motion:false;property color accent:"#9acbff"}
    FloatingWindow {
        implicitWidth:880;implicitHeight:620;color:"#101c2d"
        SystemPage {id:page;controller:mockController;pageTitle:"Input";width:740}
    }
    Timer {interval:15000;running:true;onTriggered:{console.error("FAIL: feedback test timed out");Qt.exit(1)}}
    Timer {
        interval:100;repeat:true;running:true
        onTriggered:{
            if(page.busy)return;
            if(test.phase===0){test.phase=1;page.execute(["printf","ok\n"]);return;}
            if(test.phase===1){
                if(page.failed||page.message!==""){console.error("FAIL: success output leaked into Settings");Qt.exit(1);return;}
                test.phase=2;page.execute(["sh","-c","printf 'Example failure' >&2; exit 7"]);return;
            }
            if(!page.failed||page.message!=="Example failure"){console.error("FAIL: action failure was hidden");Qt.exit(1);return;}
            console.log("PASS: successful CLI output is hidden; action errors remain visible");
            Qt.exit(0);
        }
    }
}
