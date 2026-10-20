import QtQuick
import Quickshell
import "."
ShellRoot {
    PanelWindow {
        implicitWidth:320;implicitHeight:220;color:"transparent"
        Item {id:fakeFrame;anchors.fill:parent;property bool hasContent:true}
        QtObject {
            id:center
            property QtObject controller:QtObject {property bool glass:true;property real frost:4}
            property var backdrop:fakeFrame
            property bool singlePanel:false
            property bool tileShaderFailed:false
            property real progress:1
            property real scrollOffset:0
            property int layoutRevision:0
        }
        MacControlSurface {id:card;center:center;x:20;y:20;width:280;height:180}
        Timer {
            interval:400;running:true
            onTriggered:{
                const base=card.children.find(child=>child.objectName==="macControlBackdrop");
                const glass=card.children.find(child=>child.backendSupported!==undefined);
                if(!base?.visible||base.color.a<0.75||!glass){console.error("FAIL: glass card lost its readable background");Qt.exit(1);return;}
                if(glass.GraphicsInfo.api===GraphicsInfo.Software&&glass.available){console.error("FAIL: software renderer advertised shader support");Qt.exit(1);return;}
                glass.failed=true;
                if(!base.visible){console.error("FAIL: failed shader removed the background");Qt.exit(1);return;}
                center.controller.glass=false;
                if(base.color.a!==1){console.error("FAIL: reduced effects left a translucent background");Qt.exit(1);return;}
                card.grabToImage(result=>{
                    result.saveToFile(Quickshell.env("FORYNARCH_GLASS_QA_IMAGE")||"/tmp/forynarch-glass-fallback.png");
                    console.log("PASS: MacShell backgrounds survive software rendering, shader failure and disabled glass");Qt.quit();
                });
            }
        }
    }
}
