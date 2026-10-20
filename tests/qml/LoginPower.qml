import QtQuick
import Quickshell
import "Components"
ShellRoot {
    id: test
    property var config: ({HideSystemButtons:"false"})
    property int phase: 0
    QtObject {
        id: sddm
        property bool canPowerOff: true
        property bool canSuspend: true
        property bool canHibernate: false
        property bool canReboot: true
        property var calls: []
        function powerOff() {calls = calls.concat("off");}
        function suspend() {calls = calls.concat("sleep");}
        function hibernate() {calls = calls.concat("hibernate");}
        function reboot() {calls = calls.concat("restart");}
    }
    FloatingWindow {
        id: window; title: "Inert login power test"; implicitWidth: 880; implicitHeight: 620; color: "#101c2d"
        ForynarchPowerButtons {id: power; anchors.centerIn: parent}
    }
    function find(root, predicate) {
        const queue=[root], seen=new Set();
        while(queue.length) {
            const item=queue.shift(); if(!item||seen.has(item))continue;seen.add(item);
            if(predicate(item))return item;
            for(let child of item.children||[])queue.push(child);
            for(let child of item.data||[])queue.push(child);
            if(item.contentItem)queue.push(item.contentItem);
        }
        return null;
    }
    function button(root,text) {return find(root,item=>item.text===text&&typeof item.clicked==="function");}
    function check(value,message) {if(!value){console.error("FAIL: "+message);Qt.exit(1);return false;}return true;}
    Timer {interval:15000;running:true;onTriggered:{console.error("FAIL: login power test timeout");Qt.exit(1);}}
    Timer {
        interval:150;repeat:true;running:true
        onTriggered:{
            const dialog=test.find(power,item=>item.objectName==="loginPowerConfirmation");
            if(!dialog)return;
            if(test.phase===0){
                for(let text of ["Shut down","Sleep","Hibernate","Restart"])if(!test.check(!!test.button(power,text),"all four actions are present"))return;
                if(!test.check(!test.button(power,"Hibernate").enabled,"unsupported hibernate stays disabled"))return;
                test.button(power,"Shut down").clicked();test.phase++;return;
            }
            if(test.phase===1){
                const cancel=test.button(dialog,"Cancel");
                if(!test.check(dialog.visible&&cancel.activeFocus&&sddm.calls.length===0,"power confirmation defaults to Cancel without executing"))return;
                cancel.clicked();test.phase++;return;
            }
            if(test.phase===2){
                if(!test.check(!dialog.visible&&sddm.calls.length===0,"cancellation leaves power unchanged"))return;
                test.button(power,"Restart").clicked();sddm.canReboot=false;power.perform();
                if(!test.check(sddm.calls.length===0,"capability changes are rechecked at execution"))return;
                dialog.close();sddm.canReboot=true;test.phase++;return;
            }
            if(test.phase>=3&&test.phase<=6){
                const index=test.phase-3;
                sddm.canHibernate=true;
                const labels=["Shut down","Sleep","Hibernate","Restart"];
                test.button(power,labels[index]).clicked();
                test.button(dialog,labels[index]).clicked();
                if(!test.check(sddm.calls.length===index+1,"confirmed power action calls only the inert backend"))return;
                test.phase++;return;
            }
            if(!test.check(sddm.calls.join(",")==="off,sleep,hibernate,restart","all action mappings are correct"))return;
            console.log("PASS: all four login power actions, capability gating, modal focus, cancellation and inert execution mappings");
            Qt.exit(0);
        }
    }
}
