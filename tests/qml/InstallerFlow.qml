// Injected into an isolated copy by run-installer-flow.sh. Synthetic QA data only.
Timer {
    id:flow
    interval:100;repeat:true;running:true
    property int phase:0
    function check(value,message){if(!value){console.error("FAIL: "+message);Qt.exit(1);return false;}return true;}
    function button(item,label){
        if(item.text===label&&typeof item.click==="function")return item;
        const children=item.children||[];
        for(let child of children){const found=button(child,label);if(found)return found;}
        return null;
    }
    function input(item,value){
        if(typeof item.echoMode!=="undefined"&&item.text===value)return item;
        for(let child of item.children||[]){const found=input(child,value);if(found)return found;}
        return null;
    }
    function named(item,name){
        if(item.objectName===name)return item;
        for(let child of item.children||[]){const found=named(child,name);if(found)return found;}
        return null;
    }
    property int settledFrames:0
    onTriggered:{
        if(!app.inventoryReady){if(++phase>100){console.error("FAIL: installer inventory timeout");Qt.exit(1);}return;}
        if(++settledFrames<12)return;
        const welcome=named(app.contentItem,"installerWelcome");
        if(!check(!!welcome&&welcome.effectStatus===ShaderEffect.Compiled,"welcome shader compiled on the native renderer"))return;
        if(!check(!welcome.effectAnimating,"welcome motion settles without an idle loop"))return;
        app.reduceMotion=true;app.go(1);app.go(0);
        const still=named(app.contentItem,"installerWelcome");
        if(!check(!!still&&!still.effectAnimating,"reduced motion suppresses shader arrival"))return;
        app.reduceMotion=false;
        app.go(1);app.go(0);
        const moving=named(app.contentItem,"installerWelcome");
        if(!check(!!moving&&moving.effectAnimating,"normal motion starts the finite arrival"))return;
        app.reduceMotion=true;
        if(!check(!moving.effectAnimating,"reduce motion interrupts an active shader arrival"))return;
        app.reduceMotion=false;
        console.log("PASS: native welcome shader, finite arrival and reduced motion");
        running=false;
        if(!check(app.method===""&&app.selectedGroups.length===0&&app.selectedDrivers.length===0&&app.offline,"safe initial choices"))return;
        app.go(4);if(!check(!app.nextEnabled,"storage requires deliberate disk and method selection"))return;
        app.go(5);if(!check(!app.nextEnabled,"account validation gates Continue"))return;
        if(!check(Model.accountError("QA User","root","test-host","example-pass","example-pass")!=="","reserved username"))return;
        if(!check(Model.accountError("QA User","qauser","-bad","example-pass","example-pass")!=="","invalid hostname"))return;
        if(!check(Model.accountError("QA User","qauser","test-host","short","short")!=="","short password"))return;
        if(!check(Model.accountError("QA User","qauser","test-host","example-pass","different")!=="","password mismatch"))return;
        if(!check(Model.accountError("QA:User","qauser","test-host","example-pass","example-pass")!=="","name validation matches the privileged executor"))return;
        const storageInfo={live:true,uefi:true};
        const storageDisk={size:64*1073741824,table:"gpt",geometryKnown:true,stableIdentity:true,partitions:[]};
        if(!check(Model.storageError(storageInfo,storageDisk,"install-manual",{}, {})==="","prepared GPT layout needs no second unallocated region"))return;
        if(!check(Model.storageError({live:true,uefi:false},storageDisk,"install-manual",{},{}).includes("UEFI"),"Legacy boot is not reported as a GPT error"))return;
        if(!check(Model.storageError(storageInfo,Object.assign({},storageDisk,{geometryKnown:false}),"install-manual",{},{}).includes("boundaries"),"geometry failure is distinct from GPT type"))return;
        if(!check(Model.storageError(storageInfo,Object.assign({},storageDisk,{partitions:[{mounted:true}]}),"install-erase",null,null).includes("Unmount"),"mounted volumes block erasure before confirmation"))return;
        console.log("PASS: storage requirements, GPT and boot-mode messages, and account validation");
        app.fullName="QA User";app.username="qauser";app.hostname="qa-host";app.password="example-pass";app.confirmation="example-pass";
        if(!check(app.accountError==="","valid account"))return;
        app.go(5);app.go(6);app.go(5);
        if(!check(app.password==="example-pass"&&app.username==="qauser","Back preserves account fields"))return;
        const show=button(app.contentItem,"Show passwords");
        if(!check(!!show,"password visibility control"))return;
        show.click();if(!check(app.showPassword,"show-password toggle"))return;
        show.click();if(!check(!app.showPassword,"hide-password toggle"))return;
        const request=Model.publicPlan(app.state());
        if(!check(!JSON.stringify(request).includes("example-pass")&&!("password" in request)&&!("confirmation" in request),"secrets absent from public plan"))return;
        app.setOffline(false);app.selectedGroups=["git"];app.selectedDrivers=["intel-vulkan"];app.setOffline(true);
        if(!check(app.selectedGroups.length===0&&app.selectedDrivers.length===0,"offline clears extra downloads"))return;
        app.clearSecrets();if(!check(app.password===""&&app.confirmation==="","secrets cleared"))return;
        const motion=button(app.contentItem,"Reduce motion");
        if(!check(!!motion,"reduced-motion control"))return;
        motion.click();
        if(!check(app.reduceMotion,"reduce-motion state"))return;
        app.setOffline(false);app.go(7);
        for(let group of app.info.software){
            if(group.available===false)continue;
            const control=button(app.contentItem,group.label);
            if(!check(!!control&&control.enabled,"available optional software control"))return;
            control.click();if(!check(app.selectedGroups.includes(group.id),"software opt-in"))return;
            control.click();if(!check(!app.selectedGroups.includes(group.id),"software opt-out"))return;
        }
        const actual=app.info;
        for(let vendor of ["0x8086","0x1002"]){
            app.info=Object.assign({},actual,{graphics:[{vendor:vendor,name:"Synthetic QA adapter"}]});
            app.go(6);
            for(let driver of app.info.drivers.choices.filter(c=>c.vendor===vendor&&!c.blocked)){
                const control=button(app.contentItem,driver.label);
                if(!check(!!control&&control.enabled,"matching driver control"))return;
                control.click();if(!check(app.selectedDrivers.includes(driver.id),"driver opt-in"))return;
                control.click();if(!check(!app.selectedDrivers.includes(driver.id),"driver opt-out"))return;
            }
        }
        app.info=actual;app.setOffline(true);
        app.method="install-erase";app.diskId=app.info.disks[0]?.id||"not-selected";
        // Allow real Loaders to instantiate every page over successive frames.
        recovery.running=true;
    }
}
Timer {
    id:recovery;interval:100;repeat:true
    property int phase:0
    onTriggered:{
        if(phase===0){
            // Malformed backend output must show an error and block Continue.
            discovery.command=["sh","-c","sleep 0.2; printf '{'"];
            app.reloadInventory();phase=1;return;
        }
        if(discovery.running)return;
        if(phase===1){
            if(app.error===""||app.nextEnabled||!retryInventory.visible){console.error("FAIL: inventory error/retry state");Qt.exit(1);return;}
            discovery.command=["forynarch-installer-info"];
            retryInventory.click();phase=2;return;
        }
        if(!app.inventoryReady||app.error!==""){console.error("FAIL: inventory Retry did not recover");Qt.exit(1);return;}
        if(phase===3){running=false;cycle.running=true;return;}
        // Empty-device view uses the same real page, not invented disk data.
        const saved=app.info;
        app.info={disks:[],software:saved.software,graphics:[],timezones:saved.timezones,drivers:saved.drivers};
        app.go(4);
        if(app.disk!==null||app.nextEnabled){console.error("FAIL: empty storage state");Qt.exit(1);return;}
        const detect=flow.button(app.contentItem,"Detect disks again");
        if(!detect){console.error("FAIL: empty-state detection action");Qt.exit(1);return;}
        detect.click();phase=3;
    }
}
Timer {
    id:cycle;interval:120;repeat:true
    property int page:0
    property bool refreshed:false
    onTriggered:{
        if(page===6){
            const user=flow.input(app.contentItem,"qauser");
            const host=flow.input(app.contentItem,"qa-host");
            if(!user||!host||user.width<100||Math.abs(user.width-host.width)>1){console.error("FAIL: account columns must have equal usable widths");Qt.exit(1);return;}
        }
        if(page===Model.steps.length){
            if(review.running)return;
            if(!app.proposal||app.proposal.canExecute!==false){console.error("FAIL: review must remain non-executable");Qt.exit(1);return;}
            if(!refreshed){refreshed=true;const refresh=flow.button(app.contentItem,"Refresh storage review");if(!refresh){console.error("FAIL: missing review refresh");Qt.exit(1);return;}refresh.click();return;}
            app.cancelOpen=true;
            modalCheck.running=true;running=false;return;
        }
        app.go(page++);
    }
}
Timer {
    id:modalCheck;interval:250
    property int phase:0
    onTriggered:{
        if(phase===0){
            if(!cancelDialog.visible||!keepSetup.activeFocus){console.error("FAIL: cancellation dialog must own keyboard focus");Qt.exit(1);return;}
            phase=1;keepSetup.click();restart();return;
        }
        if(app.cancelOpen){console.error("FAIL: cancellation dialog did not close");Qt.exit(1);return;}
        console.log("PASS: standalone installer validation, secret isolation, offline reset, all pages, non-executable review and modal keyboard focus");Qt.exit(0);
    }
}
