import QtQuick
import Quickshell
import Quickshell.Io
import "EmojiData.js" as Data
import "EmojiModel.js" as Model
import "WidgetLayout.js" as Layout
import "WidgetPacks.js" as Packs
ShellRoot {
    id:test
    property bool emojiOpen:false
    property bool emojiClosing:false
    property bool motion:false
    property bool motionBlur:false
    property bool glass:false
    property int frost:2
    property color accent:"#9acbff"
    property int phase:0
    function closeEmoji(){emojiOpen=false;}
    FloatingWindow {
        id:target;implicitWidth:500;implicitHeight:180;color:"#15283e"
        TextEdit {id:field;anchors.fill:parent;anchors.margins:16;color:"#ffffff";focus:true;font.pixelSize:24}
    }
    EmojiPicker {id:picker;controller:test;visible:test.emojiOpen||test.emojiClosing}
    Timer {interval:15000;running:true;onTriggered:{console.error("FAIL: emoji flow timed out");Qt.exit(1)}}
    Timer {
        interval:250;running:true;repeat:true
        onTriggered:{
            if(test.phase===0){
                if(Data.rows.length<3900||!Model.search(Data.rows,"blue heart","","Default").some(row=>row.value==="💙")){console.error("FAIL: full Unicode search");Qt.exit(1);return;}
                if(Model.recent("💙",["💙","✨"]).join("")!=="💙✨"){console.error("FAIL: deduplicated recents");Qt.exit(1);return;}
                for(var pack of Packs.packs){if(!pack.keys.every(key=>Layout.keys.includes(key))){console.error("FAIL: pack contains missing widget");Qt.exit(1);return;}}
                var invalid=Layout.valid({Virtual:{clock:{x:Infinity,y:0},media:{x:4,y:-1}}});
                if(invalid.Virtual.clock||invalid.Virtual.media.x!==1||invalid.Virtual.media.y!==0){console.error("FAIL: bounded widget positions");Qt.exit(1);return;}
                test.emojiOpen=true;test.phase=1;return;
            }
            if(test.phase===1){picker.insertText=true;picker.select("💙",false);test.phase=2;return;}
            if(test.phase===2){
                if(field.text!=="💙")return;
                if(test.emojiClosing){console.error("FAIL: picker did not release after paste");Qt.exit(1);return;}
                console.log("PASS: full Unicode search, recents, packs, bounded geometry and actual Wayland paste");Qt.exit(0);
            }
        }
    }
}
