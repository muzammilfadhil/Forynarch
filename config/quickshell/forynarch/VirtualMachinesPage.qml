import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id: page
    required property var controller
    property var info: ({enabled:false,profiles:[],states:[],missing:[],devices:[],live:false,cpus:1,availableMiB:0})
    property var draft: null
    property var review: null
    property var loaders: []
    property var response: ({})
    property string action: ""
    property string error: ""
    property string notice: ""
    property bool removeConfirm: false
    property bool forceConfirm: false
    readonly property var osDevice: info.devices.find(d=>d.partuuid===draft?.osPartuuid) || null
    readonly property bool encrypted: /bitlocker|crypto_bitlk/i.test(osDevice?.fstype || "")
    readonly property var currentState: info.states.find(s=>s.id===draft?.id) || ({phase:"stopped",active:false,error:""})
    readonly property bool supportReady: info.missing.length===0 && !info.live
    readonly property bool draftSaved: !!draft && info.profiles.some(p=>p.id===draft.id&&Object.keys(p).every(k=>p[k]===draft[k]))
    readonly property bool busy: operation.running
    spacing: 14
    Component.onCompleted: refresh()
    function refresh() { if(!read.running) read.running=true; }
    function change(key,value) { draft=Object.assign({},draft,{[key]:value});review=null;shutdownConsent.checked=false;writeConsent.checked=false;writePhrase.text=""; }
    function chooseProfile(key) { draft=JSON.parse(JSON.stringify(info.profiles.find(p=>p.id===key)));review=null;removeConfirm=false;forceConfirm=false;loaders=[]; }
    function execute(name,request) {
        if(operation.running)return;
        action=name;response={};error="";notice="";
        operation.command=["forynarch-vm",name];operation.payload=JSON.stringify(request||{});
        operation.stdinEnabled=true;operation.running=true;
    }
    function label(device) { return device.path+" · "+(device.label||device.fstype||"Partition")+" · "+(device.size/1073741824).toFixed(1)+" GiB"; }
    Process {
        id:read;command:["forynarch-vm","status"]
        stdout:StdioCollector {onStreamFinished:{try{page.info=JSON.parse(text);if(!page.draft&&page.info.profiles.length)page.chooseProfile(page.info.profiles[0].id);}catch(e){page.error="Virtual-machine status could not be read.";}}}
        stderr:StdioCollector {onStreamFinished:{if(text.trim()){try{page.error=JSON.parse(text).error;}catch(e){page.error="Virtual-machine status is unavailable.";}}}}
    }
    Timer {interval:3000;running:true;repeat:true;onTriggered:page.refresh()}
    Process {
        id:operation;property string payload:""
        onStarted:{write(payload);stdinEnabled=false;}
        stdout:StdioCollector {onStreamFinished:{try{page.response=JSON.parse(text);}catch(e){}}}
        stderr:StdioCollector {onStreamFinished:{if(text.trim()){try{page.error=JSON.parse(text).error;}catch(e){page.error="The operation was cancelled or could not finish.";}}}}
        onExited:(code,status)=>{
            if(code!==0){if(!page.error)page.error="The virtual-machine operation did not finish.";page.refresh();return;}
            if(page.action==="new"){page.draft=page.response.profile;page.review=null;page.loaders=[];}
            else if(page.action==="loaders"){page.loaders=page.response.loaders||[];if(page.loaders.length===0)page.notice="No supported EFI executables were found.";}
            else if(page.action==="preflight"){page.review=page.response.plan;shutdownConsent.checked=false;writeConsent.checked=false;writePhrase.text="";}
            else if(page.action==="save"){page.notice="Profile saved. Review it before starting the VM.";page.review=null;}
            else if(page.action==="remove"){page.draft=null;page.removeConfirm=false;page.review=null;}
            else if(page.action==="launch"){page.review=null;page.notice="Starting the virtual machine. You can close Settings.";}
            else if(page.action==="shutdown")page.notice="Shutdown requested. If Windows stays open, shut it down inside its window.";
            else if(page.action==="support-install")page.notice="Virtualization support is installed. A restart may be needed after the system update.";
            page.refresh();
        }
    }
    SettingRow {
        Layout.fillWidth:true;title:"Experimental virtual machines"
        description:"Run an existing EFI operating system in a window. Nothing starts automatically."
        Toggle {checked:page.info.enabled;enabled:!operation.running;accent:controller.accent;Accessible.name:"Enable experimental virtual machines";onClicked:page.execute("enable",{enabled:checked})}
    }
    Text {Layout.fillWidth:true;visible:!page.info.enabled;text:"Off by default. Enabling the feature does not open existing OS volumes or install virtualization packages.";color:"#a6bbd5";font.pixelSize:13;wrapMode:Text.WordWrap}
    Text {Layout.fillWidth:true;visible:page.info.enabled&&page.info.live;text:"Existing-OS VMs are available after installing Forynarch. You can select their optional support packages during setup.";color:"#b5cbe5";font.pixelSize:13;wrapMode:Text.WordWrap}
    Repeater {
        model:page.info.states.filter(s=>s.active&&!page.info.profiles.some(p=>p.id===s.id))
        delegate:ColumnLayout {
            required property var modelData
            Layout.fillWidth:true
            Text {Layout.fillWidth:true;text:"A VM is still active after its saved profile was removed. Shut it down before disabling virtualization.";color:"#b5cbe5";wrapMode:Text.WordWrap;font.pixelSize:13}
            RowLayout {
                ActionButton {label:"Request shutdown";enabled:!operation.running;onClicked:page.execute("shutdown",{id:modelData.id})}
                ActionButton {label:"Release inactive resources";enabled:!operation.running;onClicked:page.execute("recover",{id:modelData.id})}
            }
        }
    }
    ColumnLayout {
        visible:page.info.enabled&&!page.info.live;Layout.fillWidth:true;spacing:12
        Text {Layout.fillWidth:true;visible:!page.supportReady;text:"Virtualization support is not installed. This adds QEMU, UEFI firmware, a virtual TPM and disk-isolation tools. It does not start a background virtualization service.";color:"#b5cbe5";font.pixelSize:13;wrapMode:Text.WordWrap}
        ColumnLayout {
            visible:!page.supportReady;Layout.fillWidth:true;spacing:8
            ConnectivityCheck {Layout.fillWidth:true;id:updateConsent;text:"Install support and update the system";enabled:!operation.running}
            ActionButton {label:page.action==="support-install"&&operation.running?"Installing support…":"Install virtualization support";enabled:updateConsent.checked&&!operation.running;onClicked:page.execute("support-install",{updateConfirmed:true})}
        }
        RowLayout {
            Layout.fillWidth:true;spacing:10
            Choice {Layout.fillWidth:true;choices:page.info.profiles.length?page.info.profiles.map(p=>({label:p.name,value:p.id})):[{label:"No VM profiles",value:""}];selectedValue:page.draft?.id||"";enabled:page.info.profiles.length>0&&!operation.running;Accessible.name:"Virtual machine profile";onChosen:value=>page.chooseProfile(value)}
            ActionButton {label:"New VM";icon:"desktop";enabled:!operation.running;onClicked:page.execute("new",{})}
        }
        ColumnLayout {
            visible:page.draft!==null;Layout.fillWidth:true;spacing:10
            ConnectivityField {Layout.fillWidth:true;text:page.draft?.name||"";placeholderText:"VM name";Accessible.name:"VM name";enabled:!page.currentState.active&&!operation.running;onTextEdited:page.change("name",text)}
            Choice {Layout.fillWidth:true;choices:[{label:"Windows",value:"windows"},{label:"Other EFI OS · preview",value:"other"}];selectedValue:page.draft?.family||"windows";enabled:!page.currentState.active&&!operation.running;Accessible.name:"Guest operating system";onChosen:value=>{page.change("family",value);page.change("mode","preview");page.change("efiPath",value==="windows"?"EFI/Microsoft/Boot/bootmgfw.efi":"");}}
            Text {text:"Existing OS volume";color:"#dfebfc";font.pixelSize:13}
            Choice {
                Layout.fillWidth:true;choices:[{label:"Choose an OS volume",value:""}].concat(page.info.devices.filter(d=>String(d.parttype).toLowerCase()!=="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"&&(page.draft?.family!=="windows"||/ntfs|bitlocker|crypto_bitlk/i.test(d.fstype||""))).map(d=>({label:page.label(d),value:d.partuuid})));selectedValue:page.draft?.osPartuuid||""
                enabled:!page.currentState.active&&!operation.running;Accessible.name:"Existing OS partition"
                onChosen:value=>{page.change("osPartuuid",value);page.change("recoveryKeyReady",false);if(page.encrypted)page.change("mode","preview");}
            }
            Text {Layout.fillWidth:true;visible:(page.osDevice?.mountpoints||[]).some(p=>!!p);text:"This volume is mounted. Unmount it in Storage before reviewing a VM launch.";color:"#edc9a4";font.pixelSize:12;wrapMode:Text.WordWrap}
            Text {text:"EFI source · copied privately";color:"#dfebfc";font.pixelSize:13}
            Choice {Layout.fillWidth:true;choices:[{label:"Choose an EFI partition",value:""}].concat(page.info.devices.filter(d=>String(d.parttype).toLowerCase()==="c12a7328-f81f-11d2-ba4b-00a0c93ec93b").map(d=>({label:page.label(d),value:d.partuuid})));selectedValue:page.draft?.efiPartuuid||"";enabled:!page.currentState.active&&!operation.running;Accessible.name:"EFI source partition";onChosen:value=>{page.change("efiPartuuid",value);page.loaders=[];}}
            RowLayout {
                Layout.fillWidth:true;spacing:10
                Choice {Layout.fillWidth:true;choices:(page.loaders.length?page.loaders:[page.draft?.efiPath||""]).map(path=>({label:path||"Find an EFI loader",value:path}));selectedValue:page.draft?.efiPath||"";enabled:!page.currentState.active&&!operation.running;Accessible.name:"EFI executable";onChosen:value=>page.change("efiPath",value)}
                ActionButton {label:"Find loaders";enabled:page.supportReady&&!!page.draft?.efiPartuuid&&!page.currentState.active&&!operation.running;onClicked:page.execute("loaders",{efiPartuuid:page.draft.efiPartuuid})}
            }
            Choice {Layout.fillWidth:true;choices:page.encrypted||page.draft?.family==="other"?[{label:"Preview · discard changes on exit",value:"preview"}]:[{label:"Preview · discard changes on exit",value:"preview"},{label:"Direct · writes to the existing OS",value:"direct"}];selectedValue:page.draft?.mode||"preview";enabled:!page.currentState.active&&!operation.running;Accessible.name:"Disk access mode";onChosen:value=>page.change("mode",value)}
            Text {Layout.fillWidth:true;text:page.draft?.mode==="direct"?"Direct mode updates the selected Windows volume. The host's partitions and EFI stay separate. Use native boot for major Windows updates; do not repartition or enable BitLocker inside this VM.":"Preview leaves the original volume unchanged. Temporary OS and EFI changes are discarded when the VM exits. Only the selected OS volume is exposed; other data drives are not attached.";color:page.draft?.mode==="direct"?"#edc9a4":"#a6bbd5";font.pixelSize:12;wrapMode:Text.WordWrap}
            ColumnLayout {
                Layout.fillWidth:true;visible:page.encrypted;spacing:8
                Text {Layout.fillWidth:true;text:"BitLocker recovery";color:"#dfebfc";font.pixelSize:14;font.weight:Font.DemiBold}
                Text {Layout.fillWidth:true;text:"1. Fully shut down Windows before opening its volume here. Disable Fast Startup in Windows.\n2. Have the matching 48-digit recovery password available.\n3. Start Preview and enter the password only in the Windows recovery screen.\n4. Shut down the guest when finished. Preview changes are discarded.";color:"#b5cbe5";font.pixelSize:13;wrapMode:Text.WordWrap}
                Text {Layout.fillWidth:true;text:"The VM has its own persistent TPM 2.0 and private UEFI state. It cannot use the laptop's TPM-bound key, so recovery may be needed at every preview launch. Forynarch never asks for or stores the recovery password. Direct writes to encrypted volumes remain unavailable.";color:"#a6bbd5";font.pixelSize:12;wrapMode:Text.WordWrap}
                ActionButton {label:"Find my Microsoft recovery key";onClicked:Qt.openUrlExternally("https://account.microsoft.com/devices/recoverykey")}
                ConnectivityCheck {Layout.fillWidth:true;text:"I have the matching recovery password and will enter it only inside Windows";checked:page.draft?.recoveryKeyReady||false;enabled:!page.currentState.active&&!operation.running;onToggled:page.change("recoveryKeyReady",checked)}
            }
            RowLayout {
                Layout.fillWidth:true;spacing:12
                ColumnLayout {
                    Layout.fillWidth:true
                    Text {text:"Guest memory";color:"#c5d7ed";font.pixelSize:12}
                    Choice {Layout.fillWidth:true;choices:(page.draft?.family==="other"?[512,1024,2048,4096,6144,8192,12288,16384,24576,32768]:[2048,4096,6144,8192,12288,16384,24576,32768]).map(n=>({label:n<1024?n+" MiB":(n/1024)+" GiB",value:n}));selectedValue:page.draft?.memoryMiB||4096;enabled:!page.currentState.active&&!operation.running;onChosen:value=>page.change("memoryMiB",value);Accessible.name:"Guest memory"}
                }
                ColumnLayout {
                    Layout.fillWidth:true
                    Text {text:"Logical CPUs";color:"#c5d7ed";font.pixelSize:12}
                    Choice {Layout.fillWidth:true;choices:Array.from({length:Math.max(1,Math.min(32,page.info.cpus-1))},(_,i)=>({label:String(i+1),value:i+1}));selectedValue:page.draft?.cpus||1;enabled:!page.currentState.active&&!operation.running;onChosen:value=>page.change("cpus",value);Accessible.name:"Guest CPU count"}
                }
            }
            Text {Layout.fillWidth:true;text:(page.info.availableMiB/1024).toFixed(1)+" GiB currently available. Windows 11 normally needs at least 4 GiB; guest memory is additional to the desktop's usage.";color:"#a6bbd5";font.pixelSize:12;wrapMode:Text.WordWrap}
            SettingRow {Layout.fillWidth:true;title:"Storage controller";description:"Automatic follows SATA or NVMe; no VirtIO storage driver is required.";Choice {choices:[{label:"Automatic",value:"auto"},{label:"NVMe",value:"nvme"},{label:"SATA",value:"sata"}];selectedValue:page.draft?.controller||"auto";enabled:!page.currentState.active&&!operation.running;onChosen:value=>page.change("controller",value)}}
            SettingRow {Layout.fillWidth:true;title:"Guest network";description:"Private NAT for internet access. Turn off for an offline guest; no host folders are shared."
                Toggle {objectName:"vmGuestNetwork";Accessible.name:"Guest network";checked:page.draft?.network??true;enabled:!page.currentState.active&&!operation.running;accent:controller.accent;onClicked:page.change("network",checked)}}
            SettingRow {Layout.fillWidth:true;title:"Guest audio";description:"Play and record through the desktop audio service. Turn off to omit the virtual sound device."
                Toggle {objectName:"vmGuestAudio";Accessible.name:"Guest audio";checked:page.draft?.audio??true;enabled:!page.currentState.active&&!operation.running;accent:controller.accent;onClicked:page.change("audio",checked)}}
            RowLayout {
                Layout.fillWidth:true;spacing:10
                ActionButton {label:"Save profile";enabled:!!page.draft?.osPartuuid&&!!page.draft?.efiPartuuid&&!!page.draft?.efiPath&&!page.currentState.active&&!operation.running;onClicked:page.execute("save",{profile:page.draft})}
                ActionButton {label:"Review launch";selected:true;accent:controller.accent;enabled:page.supportReady&&page.draftSaved&&!page.currentState.active&&!operation.running;onClicked:page.execute("preflight",{id:page.draft.id})}
                Item {Layout.fillWidth:true}
                ActionButton {label:"Remove";hint:"Remove VM profile and private data";implicitWidth:76;enabled:page.info.profiles.some(p=>p.id===page.draft?.id)&&!page.currentState.active&&!operation.running;onClicked:page.removeConfirm=!page.removeConfirm}
            }
            Text {Layout.fillWidth:true;visible:page.currentState.active;text:"VM status: "+page.currentState.phase+". Closing Settings leaves it running. Release the guest mouse with Ctrl+Alt+G.";color:controller.accent;font.pixelSize:13;wrapMode:Text.WordWrap}
            RowLayout {
                visible:page.currentState.active;spacing:10
                ActionButton {label:"Request shutdown";visible:page.currentState.phase!=="cleanup-required";enabled:!operation.running;onClicked:page.execute("shutdown",{id:page.draft.id})}
                ActionButton {label:"Release resources";visible:page.currentState.phase==="cleanup-required";enabled:!operation.running;onClicked:page.execute("recover",{id:page.draft.id})}
                ActionButton {label:page.draft?.mode==="preview"?"Discard preview…":"Force stop…";visible:page.currentState.phase!=="cleanup-required";enabled:!operation.running;onClicked:{forcePhrase.text="";page.forceConfirm=!page.forceConfirm;}}
            }
            ColumnLayout {
                visible:page.forceConfirm&&page.currentState.active;Layout.fillWidth:true
                Text {Layout.fillWidth:true;text:page.draft?.mode==="preview"?"Discarding this preview loses its unsaved changes. The original OS stays unchanged. Type DISCARD PREVIEW to continue.":"Force stop can lose unsaved work and leave Windows requiring native repair. Type FORCE STOP to continue.";color:"#edc9a4";font.pixelSize:12;wrapMode:Text.WordWrap}
                ConnectivityField {id:forcePhrase;Layout.fillWidth:true;placeholderText:page.draft?.mode==="preview"?"DISCARD PREVIEW":"FORCE STOP";Accessible.name:"Force-stop confirmation"}
                ActionButton {label:page.draft?.mode==="preview"?"Discard preview":"Force stop VM";enabled:forcePhrase.text===(page.draft?.mode==="preview"?"DISCARD PREVIEW":"FORCE STOP")&&!operation.running;onClicked:page.execute("force-stop",{id:page.draft.id,confirmation:forcePhrase.text})}
            }
            ColumnLayout {
                visible:page.removeConfirm;Layout.fillWidth:true
                Text {Layout.fillWidth:true;text:"Remove this profile and its private EFI, firmware and virtual TPM data? The original OS volume is not deleted. Keep recovery keys before deleting virtual TPM state.";color:"#edc9a4";font.pixelSize:12;wrapMode:Text.WordWrap}
                ActionButton {label:"Remove VM and private data";enabled:!operation.running;onClicked:page.execute("remove",{id:page.draft.id,deleteConfirmed:true})}
            }
        }
        ColumnLayout {
            visible:page.review!==null;Layout.fillWidth:true;spacing:10
            Rectangle {Layout.fillWidth:true;Layout.preferredHeight:1;color:"#35475d"}
            Text {text:"Review this launch";color:"#e1edff";font.pixelSize:17;font.weight:Font.DemiBold}
            Text {Layout.fillWidth:true;text:page.review?("Network: "+(page.review.profile.network===false?"Off":"Private NAT")+" · Audio: "+(page.review.profile.audio===false?"Off":"On")+" · TPM 2.0: private, persistent"):"";color:"#bdd0e8";font.pixelSize:13;wrapMode:Text.WordWrap}
            Text {Layout.fillWidth:true;textFormat:Text.PlainText;text:page.review?(page.review.profile.name+" · "+(page.review.profile.mode==="direct"?"DIRECT WRITES":"PREVIEW")+"\nDisk: "+page.review.diskLabel+"\nOS volume: "+page.review.source.path+" · "+(page.review.source.size/1073741824).toFixed(1)+" GiB\nPrivate EFI copy: "+page.review.profile.efiPath+"\nResources: "+(page.review.profile.memoryMiB/1024)+" GiB RAM · "+page.review.profile.cpus+" CPUs\nOther partitions are not passed through. Original EFI and firmware settings are not modified."):"";color:"#bdd0e8";font.pixelSize:13;wrapMode:Text.WordWrap}
            ConnectivityCheck {Layout.fillWidth:true;id:shutdownConsent;objectName:"vmShutdownConsent";text:"The other operating system was shut down completely"}
            ConnectivityCheck {Layout.fillWidth:true;id:writeConsent;objectName:"vmWriteConsent";visible:page.review?.profile.mode==="direct";text:"I have a backup and accept writes to this OS volume"}
            ConnectivityField {id:writePhrase;objectName:"vmWritePhrase";visible:page.review?.profile.mode==="direct";Layout.fillWidth:true;placeholderText:"Type USE REAL DISK";Accessible.name:"Direct disk write confirmation"}
            RowLayout {
                spacing:10
                ActionButton {objectName:"vmLaunchButton";label:page.review?.profile.mode==="direct"?"Start with direct writes":"Start preview";selected:true;accent:controller.accent;enabled:!operation.running&&shutdownConsent.checked&&(page.review?.profile.mode!=="direct"||(writeConsent.checked&&writePhrase.text==="USE REAL DISK"));onClicked:page.execute("launch",{id:page.review.profile.id,digest:page.review.digest,shutdownConfirmed:shutdownConsent.checked,writeConfirmed:writeConsent.checked&&writePhrase.text==="USE REAL DISK"})}
                ActionButton {label:"Cancel";enabled:!operation.running;onClicked:page.review=null}
            }
        }
    }
    Text {Layout.fillWidth:true;visible:operation.running;text:page.action==="support-install"?"Installing support and updating the system. This may take several minutes…":"Waiting for authentication or the requested operation…";color:controller.accent;font.pixelSize:13;wrapMode:Text.WordWrap}
    Text {Layout.fillWidth:true;visible:page.notice!=="";text:page.notice;textFormat:Text.PlainText;color:"#abcadf";font.pixelSize:13;wrapMode:Text.WordWrap}
    Text {Layout.fillWidth:true;visible:(page.error||page.currentState.error)!=="";text:page.error||page.currentState.error;textFormat:Text.PlainText;color:"#f0c4ae";font.pixelSize:13;wrapMode:Text.WordWrap}
}
