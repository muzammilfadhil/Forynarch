//@ pragma IconTheme Forynarch
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "InstallerModel.js" as Model

ShellRoot {
    FloatingWindow {
        id:app
        title:"Install Forynarch"
    implicitWidth:Math.min(1100,(screen?.width||1280)-48);implicitHeight:Math.min(720,(screen?.height||800)-96)
    minimumSize:Qt.size(760,520)
        color:"#101c2d"
        property int step:0
        property int furthest:0
        property var info:({disks:[],software:[],graphics:[],timezones:["UTC"],drivers:{choices:[]}})
        property bool inventoryReady:false
        property string error:""
        property string method:""
        property string diskId:""
        property string filesystem:"ext4"
    property string rootPartitionId:""
    property string efiPartitionId:""
    property bool registerBootEntry:true
    property bool storageGuide:false
    readonly property bool prepared:method==="install-manual"||method==="install-alongside"
    readonly property var rootPartition:(disk?.partitions||[]).find(p=>p.id===rootPartitionId)||null
    readonly property var efiPartition:(disk?.partitions||[]).find(p=>p.id===efiPartitionId)||null
    readonly property string consentText:prepared?"INSTALL "+(rootPartition?.path||""):"ERASE "+(disk?.path||"")
    onDiskIdChanged:{rootPartitionId="";efiPartitionId="";proposal=null;}
        property string timezone:"UTC"
        property string keyboard:"us"
        property string fullName:""
        property string username:""
        property string hostname:"forynarch"
        property string password:""
        property string confirmation:""
        property bool showPassword:false
    property bool passwordless:false
        property bool offline:true
        property var selectedGroups:[]
        property var selectedDrivers:[]
        property var proposal:null
        property bool cancelOpen:false
        property bool reduceMotion:false
    property bool installationComplete:false
    property string installationStage:""
    property string installationMessage:""
    property string installationError:""
    property bool installationAttempted:false
    property var installationDiskChanged:null
    property string installationFailedStage:""
    property var installationExitCode:null
    property var helperExitCode:null
    property string installationDetails:""
    property string installationLiveLog:""
    property string installationShownLog:""
    property bool showingInstallationLog:false
    property bool logPaused:false
    property string copyPayload:""
    readonly property string installationLogText:"Stage: "+(installationFailedStage||installationStage||"prepare")+"\nLog: "+(installationLogPath||"/run/forynarch-installation/installation.log")+"\nRecent output (up to 300 lines)\n\n"+(installationShownLog||"Waiting for installer output...")
    property string installationLogPath:""
    property bool detailsExpanded:false
    readonly property string diskStatus:installationComplete?"Installation complete":install.running?"Installing system":!installationAttempted?"No disk changes applied":installationDiskChanged===false?"Stopped before disk changes":installationDiskChanged===true?"Disk may have changed":"Check disk before retrying"
    readonly property string diagnosticsText:installationMessage+"\nStage: "+(installationFailedStage||installationStage||"unknown")+"\nExit code: "+(installationExitCode===null?"unknown"+(helperExitCode===null?"":" (helper "+helperExitCode+")"):installationExitCode)+"\n"+diskStatus+"\nLog: "+(installationLogPath||"/run/forynarch-installation/installation.log")+"\n\n"+(installationDetails||installationError||"No diagnostic output was received.")
    function readInstallEvent(event){
        if(event.kind==="log"){
            installationLiveLog=String(event.text||"").slice(-49152);
            if(!logPaused)installationShownLog=installationLiveLog;
            return;
        }
        installationStage=event.stage;installationMessage=event.message;
        if("diskMayHaveChanged" in event)installationDiskChanged=typeof event.diskMayHaveChanged==="boolean"?event.diskMayHaveChanged:null;
        if(event.logPath)installationLogPath=event.logPath;
        if(event.stage==="failed"){installationFailedStage=event.failedStage||"prepare";installationExitCode=event.exitCode;installationDetails=event.details||"";}
    }
    function toggleInstallationLog(){
        detailsExpanded=!(detailsExpanded&&showingInstallationLog);showingInstallationLog=true;
        if(detailsExpanded)Qt.callLater(function(){var view=scroll.contentItem;if(view&&typeof view.contentY==="number")view.contentY=Math.max(0,view.contentHeight-view.height);});
    }
    readonly property bool isBusy:discovery.running||review.running||install.running||partitionEditor.running
    readonly property bool canInstall:!!proposal?.canExecute&&!isBusy&&accountError===""
        readonly property var disk:info.disks.find(d=>d.id===diskId)||null
    readonly property string accountError:Model.accountError(fullName,username,hostname,password,confirmation,passwordless)
readonly property string storageError:Model.storageError(info,disk,method,rootPartition,efiPartition)
readonly property bool nextEnabled:inventoryReady&&!app.isBusy&&(step!==4||storageError==="")&&(step!==5||accountError==="")
        function clearSecrets(){password="";confirmation="";showPassword=false;}
    function close(){if(install.running){visible=true;return;}clearSecrets();Qt.quit();}
        function setOffline(value){offline=value;if(value){selectedGroups=[];selectedDrivers=[];}proposal=null;}
    function state(){return {method:method,revision:info.revision,diskId:diskId,offline:offline,selectedGroups:selectedGroups,filesystem:filesystem,timezone:timezone,keyboard:keyboard,fullName:fullName,username:username,hostname:hostname,selectedDrivers:selectedDrivers,passwordless:passwordless,rootPartitionId:rootPartitionId,efiPartitionId:efiPartitionId,registerBootEntry:registerBootEntry};}
        function go(value){if(install.running)return;step=value;furthest=Math.max(furthest,value);error="";if(value===8)prepare();}
        function prepare(){proposal=null;review.command=["forynarch-installer-review",JSON.stringify(Model.publicPlan(state()))];review.running=true;}
        onVisibleChanged:if(!visible)close()
        function reloadInventory(){if(!discovery.running){inventoryReady=false;error="";discovery.running=true;}}
        Component.onCompleted:reloadInventory()
    Process{
        id:partitionEditor;command:["forynarch-partitions","open"]
        stderr:StdioCollector{id:partitionErrors}
        onExited:(code)=>{
            if(code===0)app.reloadInventory();
            else{
                app.error="Partition Manager could not open. Check the Live session and try again.";
                if(partitionErrors.text.trim())console.warn(partitionErrors.text.trim());
            }
        }
    }
    Shortcut {sequence:"Escape";enabled:!app.cancelOpen&&!install.running&&!eraseDialog.opened;onActivated:app.cancelOpen=true}
    onCancelOpenChanged:if(install.running)cancelOpen=false
        IpcHandler {
            target:"installer"
            // Read-only status deliberately excludes names, disk IDs and secrets.
        function status():string{return JSON.stringify({step:app.step,page:Model.steps[app.step],inventoryReady:app.inventoryReady,method:app.method,offline:app.offline,selectedGroups:app.selectedGroups,selectedDrivers:app.selectedDrivers,canExecute:app.canInstall,installing:install.running,complete:app.installationComplete,error:app.error});}
        }
        Process {
            id:discovery;command:["forynarch-installer-info"]
            stdout:StdioCollector {onStreamFinished:{try{app.info=JSON.parse(text);app.inventoryReady=true;}catch(e){app.error="Installation information could not be read. Close and reopen the installer to retry.";}}}
            stderr:StdioCollector {onStreamFinished:if(text.trim())app.error=text.trim()}
        }
        Process {
            id:review
            stdout:StdioCollector {onStreamFinished:{try{app.proposal=JSON.parse(text);}catch(e){app.error="The storage review could not be prepared. Return to Storage and check your selection.";}}}
            stderr:StdioCollector {onStreamFinished:if(text.trim())app.error=text.trim()}
        }
    Process {
        id:install
        command:["pkexec","/usr/local/libexec/forynarch-install-system"]
        stdinEnabled:true
        onStarted:{
            app.installationAttempted=true;app.installationComplete=false;app.installationDiskChanged=null;
            app.installationStage="prepare";app.installationMessage="Checking installation request";
            app.installationFailedStage="";app.installationExitCode=null;app.helperExitCode=null;app.installationDetails="";app.detailsExpanded=false;
            app.installationLiveLog="";app.installationShownLog="";app.logPaused=false;app.showingInstallationLog=false;
            var request={plan:Model.publicPlan(app.state()),password:app.password,confirmation:app.confirmation,consent:eraseInput.text};
            install.write(JSON.stringify(request)+"\n");
            app.clearSecrets();
        }
        stdout:SplitParser {onRead:line=>{try{app.readInstallEvent(JSON.parse(line));}catch(e){app.installationError="Installation progress could not be read.";}}}
        stderr:StdioCollector {onStreamFinished:app.installationError=text.trim()}
        onExited:(code,status)=>{
            app.clearSecrets();
            app.helperExitCode=code;
            app.installationComplete=code===0&&app.installationStage==="complete";
            if(!app.installationComplete&&app.installationStage!=="failed"){
                app.installationFailedStage=app.installationStage||"prepare";
                app.installationStage="failed";app.installationDiskChanged=null;app.installationExitCode=null;
                app.installationMessage="The installation helper stopped without a final report. Keep the Live media and check the log before retrying; disk state could not be confirmed.";
                app.error="";
            }
        }
    }
    Process {
        id:copyDetails;command:["wl-copy"];stdinEnabled:true
        onStarted:{copyDetails.write(app.copyPayload);copyDetails.stdinEnabled=false;}
    }
    RowLayout {
        anchors.fill:parent;spacing:0
            Rectangle {
                Layout.preferredWidth:196;Layout.fillHeight:true;color:"#122034"
                ColumnLayout {
                    anchors.fill:parent;anchors.margins:24;spacing:8
                    Text {text:"Forynarch";color:"#e1edfc";font.pixelSize:21;font.weight:Font.DemiBold}
                    SetupText {text:"Installation";font.pixelSize:12}
                    Item {Layout.preferredHeight:12}
                    ScrollView {
                        Layout.fillWidth:true;Layout.fillHeight:true;clip:true
                        contentWidth:availableWidth
                        ScrollBar.horizontal.policy:ScrollBar.AlwaysOff
                        ColumnLayout {width:parent.width;spacing:4
                    Repeater {
                        model:Model.steps
                        AbstractButton {
                            id:stageButton
                            required property string modelData
                            required property int index
                            Layout.fillWidth:true;implicitHeight:44
                            text:modelData;enabled:index<app.step&&!install.running
                            Accessible.name:"Return to "+modelData
                            background:Rectangle {
                                color:stageButton.hovered?"#1a2e45":"transparent"
                                border.width:1;border.color:stageButton.activeFocus?"#9acbff":"transparent"
                                Rectangle {visible:app.step===index;anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter;width:2;height:20;color:"#9acbff"}
                            }
                            contentItem:Row {spacing:12;leftPadding:12
                                Text {anchors.verticalCenter:parent.verticalCenter;text:index<app.step?"✓":String(index+1);color:app.step===index?"#b4dbff":"#879db7";font.pixelSize:11}
                                Text {anchors.verticalCenter:parent.verticalCenter;text:modelData;color:app.step===index?"#e6f1ff":"#a1b8d2";font.pixelSize:13;font.weight:app.step===index?Font.DemiBold:Font.Normal}
                            }
                            onClicked:app.go(index)
                            Keys.onReturnPressed:clicked()
                            Keys.onEnterPressed:clicked()
                        }
                    }
                        }
                    }
                    SetupText {text:"Live installation";font.pixelSize:11;color:"#94a9c1"}
                }
            }
            ColumnLayout {
                Layout.fillWidth:true;Layout.fillHeight:true;Layout.margins:28;spacing:16
                RowLayout {
                    Layout.fillWidth:true
                    ColumnLayout {
                        Layout.fillWidth:true;spacing:5
                        SetupText {text:"STEP "+String(app.step+1).padStart(2,"0")+" OF 09";font.pixelSize:11;color:"#9acbff";font.weight:Font.DemiBold}
                        SetupText {text:app.step===0?"Welcome & Overview":Model.steps[app.step];font.pixelSize:13;color:"#d1e3f7"}
                    }
                SetupButton {text:install.running?(app.detailsExpanded&&app.showingInstallationLog?"Hide log":"Show log"):"Cancel";quiet:true;onClicked:{if(install.running)app.toggleInstallationLog();else app.cancelOpen=true;}}
                }
                RowLayout {
                    Layout.fillWidth:true;spacing:7
                    Repeater {
                        model:9
                        Rectangle {
                            required property int index
                            Layout.fillWidth:true;implicitHeight:5;radius:2.5
                            color:index<=app.step?"#9acbff":"#2a3b50"
                            Behavior on color {ColorAnimation {duration:app.reduceMotion?0:160}}
                            Accessible.ignored:true
                        }
                    }
                }
                ScrollView {
                    id:scroll
                    Layout.fillWidth:true;Layout.fillHeight:true;clip:true
                    contentWidth:availableWidth
                    ScrollBar.horizontal.policy:ScrollBar.AlwaysOff
                    Loader {
                        id:pageLoader
                        width:Math.min(scroll.availableWidth,app.step===0?960:740)
                        sourceComponent:[welcomePage,connectionPage,locationPage,keyboardPage,storagePage,accountPage,driversPage,softwarePage,reviewPage][app.step]
                        onLoaded:{scroll.contentItem.contentY=0;pageFade.restart();pageArrival.restart();}
                    }
                    NumberAnimation {id:pageFade;target:pageLoader;property:"opacity";from:0;to:1;duration:app.reduceMotion?0:140}
                    NumberAnimation {id:pageArrival;target:pageLoader;property:"y";from:app.reduceMotion?0:8;to:0;duration:app.reduceMotion?0:200;easing.type:Easing.OutCubic}
                }
                SetupText {visible:discovery.running;text:"Reading disks and hardware…";font.pixelSize:12}
                RowLayout {
                    visible:app.error!=="";Layout.fillWidth:true
                    SetupText {text:app.error;color:"#ffc2af"}
                    SetupButton {id:retryInventory;visible:!app.inventoryReady;text:"Retry";enabled:!discovery.running;onClicked:app.reloadInventory()}
                }
                Rectangle {Layout.fillWidth:true;height:1;color:"#2a405a"}
                RowLayout {
                    Layout.fillWidth:true;spacing:12
                SetupButton {text:"Back";quiet:true;visible:app.step>0&&!app.installationComplete;enabled:!app.isBusy;onClicked:app.go(app.step-1)}
                    SetupCheck {text:"Reduce motion";checked:app.reduceMotion;onToggled:app.reduceMotion=checked}
                    Item {Layout.fillWidth:true}
                SetupText {text:app.diskStatus;Layout.fillWidth:false;font.pixelSize:11}
                SetupButton {text:app.installationComplete?"Close":install.running?"Installing…":app.step===0?"Begin setup":app.step===8?"Install Forynarch":"Continue";primary:true;enabled:app.installationComplete||!app.isBusy&&(app.step===8?app.canInstall:app.nextEnabled);onClicked:{if(app.installationComplete)app.close();else if(app.step===8){eraseInput.text="";eraseDialog.open();}else app.go(app.step+1);}}
                }
            }
        }
        Component {id:welcomePage
            WelcomePanel {reduceMotion:app.reduceMotion;installerReady:app.info.executorAvailable===true}
        }
        Component {id:connectionPage
            ColumnLayout {spacing:18
                SetupText {text:"Choose how to install";font.pixelSize:21;color:"#e1eeff"}
                SetupText {text:"Install from the Live media, or allow downloads for the software and drivers you select."}
                SetupOption {Layout.fillWidth:true;title:"Use the offline core";description:"Install the included desktop. Additional applications and driver downloads stay off.";selected:app.offline;onChosen:app.setOffline(true)}
                SetupOption {Layout.fillWidth:true;title:"Allow selected downloads";description:"Choose additional software and drivers in the next steps. Nothing is downloaded now.";selected:!app.offline;onChosen:app.setOffline(false)}
                SetupButton {text:"Network settings";quiet:true;onClicked:Quickshell.execDetached(["forynarch-settings","Network"])}
                SetupText {text:"Additional downloads need an internet connection. You can open network settings without discarding your setup choices."}
            }
        }
        Component {id:locationPage
            ColumnLayout {spacing:16
                SetupText {text:"Where are you?";font.pixelSize:21;color:"#e1eeff"}
                SetupText {text:"Choose the timezone for the installed system. Menus and system messages remain in English."}
                SetupField {id:zoneFilter;Layout.fillWidth:true;placeholderText:"Search timezones, for example Asia/Jakarta"}
                SetupChoice {Layout.fillWidth:true;model:app.info.timezones.filter(z=>z.toLowerCase().includes(zoneFilter.text.toLowerCase()));currentIndex:model.indexOf(app.timezone);displayText:currentIndex<0?"Select a timezone":currentText;onActivated:app.timezone=model[currentIndex]}
                SetupText {text:"Selected timezone: "+app.timezone;color:"#dceaff"}
                SetupText {text:"System locale: en_US.UTF-8\nTime selection here does not change the running Live session."}
            }
        }
        Component {id:keyboardPage
            ColumnLayout {spacing:16
                SetupText {text:"Choose your keyboard";font.pixelSize:21;color:"#e1eeff"}
                SetupChoice {Layout.fillWidth:true;model:Model.keyboards;textRole:"label";currentIndex:Model.keyboards.findIndex(k=>k.id===app.keyboard);onActivated:app.keyboard=Model.keyboards[currentIndex].id}
                SetupText {text:"Selected installed layout: "+app.keyboard}
                SetupField {Layout.fillWidth:true;placeholderText:"Type here to check your current Live keyboard"}
                SetupText {text:"This test uses the current Live keyboard layout. Your selected layout is saved for the installed desktop."}
            }
        }
        Component {id:storagePage
            ColumnLayout {spacing:14
                SetupText {text:"Where should Forynarch be installed?";font.pixelSize:21;color:"#e1eeff"}
                SetupChoice {Layout.fillWidth:true;model:app.info.disks;textRole:"name";currentIndex:app.info.disks.findIndex(d=>d.id===app.diskId);displayText:app.disk?app.disk.name+" · "+(app.disk.size/1e9).toFixed(2)+" GB":"Select a disk";onActivated:app.diskId=app.info.disks[currentIndex].id}
                SetupText {text:app.disk?app.disk.path+" · "+app.disk.table+" · "+app.disk.partitions.length+" partitions":"No disk is selected. Storage is read without modifying it."}
                SetupText {text:app.info.uefi?"Live boot mode: UEFI":"Live boot mode: Legacy / BIOS";color:app.info.uefi?"#c5d8ee":"#ffc2af"}
                SetupText {visible:app.storageError!=="";text:app.storageError;color:"#ffc2af"}
                SetupText {visible:app.inventoryReady&&app.info.disks.length===0;text:"No installation disks found. Check the drive connection, then retry detection.";color:"#f2c5aa"}
                SetupButton {visible:app.inventoryReady&&app.info.disks.length===0;text:"Detect disks again";enabled:!discovery.running;onClicked:app.reloadInventory()}
                Repeater {
                    model:Model.methods
                    SetupOption {
                        required property var modelData
                        Layout.fillWidth:true;title:modelData.label;description:modelData.detail
                        selected:app.method===modelData.id;onChosen:app.method=modelData.id
                    }
                }
            RowLayout {
                Layout.fillWidth:true
                SetupButton {text:partitionEditor.running?"Partition Manager is open":"Open Partition Manager";enabled:!app.isBusy;onClicked:partitionEditor.running=true}
                SetupButton {text:"Refresh disks";enabled:!app.isBusy;onClicked:app.reloadInventory()}
                SetupButton {text:app.storageGuide?"Hide guide":"Installation guide";onClicked:app.storageGuide=!app.storageGuide}
            }
            SetupText {visible:partitionEditor.running;text:"Apply or cancel your pending changes in Partition Manager, then close it. The installer will refresh the disk list."}
            ColumnLayout {
                visible:app.storageGuide;Layout.fillWidth:true;spacing:8
                SetupText {text:"1. Back up important files and boot the Live USB in UEFI mode. Keep recovery keys for any encrypted operating system."}
                SetupText {text:"2. To keep another OS, shrink its filesystem with that OS's disk tools first. In KDE Partition Manager, use the resulting unallocated space for a Linux root partition of at least 32 GiB. Apply the changes before returning here."}
                SetupText {text:"3. Keep the existing FAT32 EFI System Partition (at least 100 MiB). Do not delete OS, reserved or recovery partitions. If using an empty second disk, create a FAT32 partition and set its ESP flag."}
                SetupText {text:"4. Select the prepared Linux root and EFI partitions below. Only root is formatted; EFI and other partitions are preserved. Kernel files are stored on Linux, so a small shared EFI partition can be reused."}
                SetupText {text:"5. Review the exact devices and choose whether to add a Forynarch firmware entry. Existing EFI systems on the chosen ESP are added to GRUB when their boot files can be identified."}
                SetupText {text:"For Windows, keep the BitLocker recovery key and use Windows Disk Management to shrink its volume. Fully shut down Windows before sharing NTFS files. Encryption is never bypassed."}
            }
            ColumnLayout {
                id:assignments;visible:app.prepared;Layout.fillWidth:true;spacing:10
                            readonly property var roots:(app.disk?.partitions||[]).filter(p=>!p.protected&&!p.mounted&&!p.readOnly&&!p.encrypted&&p.size>=34359738368&&["0fc63daf-8483-4772-8e79-3d69d8477de4","4f68bce3-e8cd-4db1-96e7-fbcaf984b709"].includes(p.partitionType)&&["unknown","ext4","btrfs","xfs",""].includes(String(p.filesystem||"").toLowerCase()))
                            readonly property var efis:(app.disk?.partitions||[]).filter(p=>p.partitionType==="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"&&p.size>=104857600&&["vfat","fat32","fat"].includes(String(p.filesystem||"").toLowerCase())&&!p.mounted&&!p.readOnly&&!p.encrypted)
                SetupText {text:"Root partition — will be formatted as ext4";color:"#ffc2af"}
                SetupChoice {Layout.fillWidth:true;model:assignments.roots;textRole:"path";currentIndex:assignments.roots.findIndex(p=>p.id===app.rootPartitionId);displayText:app.rootPartition?app.rootPartition.path+" · "+(app.rootPartition.size/1073741824).toFixed(1)+" GiB · "+app.rootPartition.filesystem:"Select an empty or Linux root partition";onActivated:app.rootPartitionId=assignments.roots[currentIndex].id}
                SetupText {text:"EFI System Partition — keep existing files"}
                SetupChoice {Layout.fillWidth:true;model:assignments.efis;textRole:"path";currentIndex:assignments.efis.findIndex(p=>p.id===app.efiPartitionId);displayText:app.efiPartition?app.efiPartition.path+" · "+(app.efiPartition.size/1048576).toFixed(0)+" MiB · FAT32":"Select the FAT32 EFI System Partition";onActivated:app.efiPartitionId=assignments.efis[currentIndex].id}
                SetupCheck {text:"Add Forynarch to the firmware boot menu";checked:app.registerBootEntry;onToggled:app.registerBootEntry=checked}
                SetupText {visible:assignments.roots.length===0||assignments.efis.length===0;text:"Prepare the missing root or EFI partition in Partition Manager, close it, and refresh. Mounted, encrypted, reserved and recovery volumes cannot be selected as root.";color:"#f2c5aa"}
            }
            SetupText {text:"Root filesystem: ext4. No disk is selected automatically. Encryption, automatic shrinking and separate /home assignment are not supported by this method."}
                SetupText {visible:!app.info.uefi;text:"This Live session uses legacy firmware. The current installer design requires booting in UEFI mode.";color:"#ffc2af"}
            }
        }
        Component {id:accountPage
            ColumnLayout {spacing:12
                SetupText {text:"Create your account";font.pixelSize:21;color:"#e1eeff"}
                SetupText {text:"This account will be used to sign in and authorize system administration. Automatic login stays off."}
                SetupText {text:"Your name";font.pixelSize:12}
                SetupField {Layout.fillWidth:true;text:app.fullName;placeholderText:"Full name";maximumLength:100;onTextEdited:app.fullName=text}
                RowLayout {Layout.fillWidth:true;spacing:16
                    ColumnLayout {Layout.fillWidth:true;Layout.preferredWidth:1;SetupText {text:"Username";font.pixelSize:12} SetupField {Layout.fillWidth:true;text:app.username;placeholderText:"username";maximumLength:31;onTextEdited:app.username=text}}
                    ColumnLayout {Layout.fillWidth:true;Layout.preferredWidth:1;SetupText {text:"Computer name";font.pixelSize:12} SetupField {Layout.fillWidth:true;text:app.hostname;maximumLength:63;onTextEdited:app.hostname=text}}
                }
            RowLayout {Layout.fillWidth:true;spacing:16;enabled:!app.passwordless
                ColumnLayout {Layout.fillWidth:true;Layout.preferredWidth:1;SetupText {text:"Password";font.pixelSize:12} SetupField {Layout.fillWidth:true;text:app.password;echoMode:app.showPassword?TextInput.Normal:TextInput.Password;onTextEdited:app.password=text}}
                    ColumnLayout {Layout.fillWidth:true;Layout.preferredWidth:1;SetupText {text:"Confirm password";font.pixelSize:12} SetupField {Layout.fillWidth:true;text:app.confirmation;echoMode:app.showPassword?TextInput.Normal:TextInput.Password;onTextEdited:app.confirmation=text}}
                }
            SetupCheck {text:"Show passwords";checked:app.showPassword;enabled:!app.passwordless;onToggled:app.showPassword=checked}
            SetupCheck {text:"Sign in without a password";checked:app.passwordless;onToggled:{app.passwordless=checked;if(checked)app.clearSecrets();}}
            SetupText {visible:app.passwordless;text:"Anyone with local access can sign in to this account. Automatic login remains off.";font.pixelSize:12;color:"#f2c5aa"}
                SetupText {text:app.accountError||"Your account details are ready for review.";color:app.accountError?"#f3c6ac":"#9bd3c4";font.pixelSize:12}
            SetupText {text:"Your password is sent privately to the installer and cleared when installation starts or you close setup.";font.pixelSize:12}
            }
        }
        Component {id:driversPage
            ColumnLayout {spacing:16
                SetupText {text:"Hardware and drivers";font.pixelSize:21;color:"#e1eeff"}
                SetupText {text:"Included core: Linux kernel drivers, Linux firmware, Mesa graphics and the desktop audio stack. Most network, Bluetooth and input drivers come from the kernel and firmware; support still depends on your hardware."}
                Repeater {model:app.info.graphics
                    SetupText {required property var modelData;text:"Detected: "+(modelData.name||"Graphics adapter");font.pixelSize:13;color:"#dceaff"}
                }
                SetupText {visible:app.info.graphics.length===0;text:"No PCI graphics device was detected. USB and platform devices need additional detection."}
                SetupText {text:app.offline?"Additional driver downloads are unavailable in offline mode.":"Optional Vulkan packages are downloaded and verified before disk changes. GPU-specific acceleration requiring further checks is listed below.";color:"#9acbff"}
                Repeater {model:app.info.drivers.choices.filter(c=>app.info.graphics.some(g=>g.vendor===c.vendor))
                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth:true;spacing:4
                        readonly property bool detected:app.info.graphics.some(g=>g.vendor===modelData.vendor)
                        SetupCheck {text:modelData.label;checked:app.selectedDrivers.includes(modelData.id);enabled:!app.offline&&detected&&!modelData.blocked;onToggled:app.selectedDrivers=Model.toggle(app.selectedDrivers,modelData.id,checked)}
                        SetupText {text:modelData.description+(!detected?" Matching hardware was not detected.":"");font.pixelSize:12}
                    }
                }
                SetupText {visible:!app.info.drivers.choices.some(c=>app.info.graphics.some(g=>g.vendor===c.vendor));text:"No additional graphics drivers are offered for this adapter.";font.pixelSize:12}
                SetupText {visible:app.info.graphics.some(g=>g.vendor==="0x10de");text:"Automatic NVIDIA installation is not supported yet. Exact GPU and kernel compatibility must be verified first.";font.pixelSize:12;color:"#f2c5aa"}
            }
        }
        Component {id:softwarePage
            ColumnLayout {spacing:14
                SetupText {text:"Choose your software";font.pixelSize:21;color:"#e1eeff"}
                SetupText {text:"Required core · Hyprland desktop, terminal, file manager, network, audio and the standard advanced partition editor.";color:"#dceaff"}
                SetupText {text:app.offline?"Offline mode: optional downloads are unavailable.":"All optional software starts unchecked. Select only what you want."}
                Repeater {model:app.info.software
                    ColumnLayout {required property var modelData;Layout.fillWidth:true;spacing:3
                    SetupCheck {text:modelData.label;checked:app.selectedGroups.includes(modelData.id);enabled:!app.offline&&modelData.available!==false;onToggled:app.selectedGroups=Model.toggle(app.selectedGroups,modelData.id,checked)}
                        SetupText {text:modelData.description;font.pixelSize:12}
                    }
                }
            }
        }
        Component {id:reviewPage
            ColumnLayout {spacing:15
                SetupText {text:"Review your installation";font.pixelSize:21;color:"#e1eeff"}
                SetupText {text:"Boot menu: GRUB · Particle Circle theme\nUEFI fallback files are installed on the reviewed disk. Firmware NVRAM entries are unchanged.";color:"#dceaff"}
                SetupText {text:"Location: "+app.timezone+" · en_US.UTF-8\nKeyboard: "+app.keyboard+"\nAccount: "+app.fullName+" ("+app.username+")\nComputer: "+app.hostname+" · "+(app.passwordless?"passwordless sign-in":"password required")+" · automatic login off";color:"#dceaff"}
                SetupText {text:"Storage: "+(Model.methods.find(m=>m.id===app.method)?.label||"Not selected")+"\nDisk: "+(app.disk?.path||"Not selected")+" · "+app.filesystem; color:app.method==="install-erase"?"#ffc2af":"#dceaff"}
                SetupText {text:"Optional software: "+(app.selectedGroups.map(id=>app.info.software.find(g=>g.id===id)?.label||id).join(", ")||"None")+"\nAdditional drivers: "+(app.selectedDrivers.map(id=>app.info.drivers.choices.find(g=>g.id===id)?.label||id).join(", ")||"None")+"\nSource: "+(app.offline?"Offline core only":"Core media and selected signed-repository downloads")}
                SetupText {text:app.proposal?.summary||"Preparing storage review…"}
                SetupText {visible:!!app.proposal;text:"Optional package plan: "+((app.proposal?.optionalPackages||[]).join(", ")||"None")+"\nAdditional driver packages: "+((app.proposal?.driverPackages||[]).join(", ")||"None");font.pixelSize:12}
                Repeater {model:app.proposal?.blockers||[];SetupText {required property string modelData;text:"• "+modelData;color:"#f3c3af";font.pixelSize:12}}
                SetupText {text:app.installationMessage||(app.info.executorAvailable?"Install to a whole disk or your reviewed root/EFI assignments. Only the operations listed in this review will be applied.":"The matching installation payload is unavailable. No disk changes can be applied from this session.");color:install.running?"#9acbff":"#f3c3af"}
                SetupText {visible:app.prepared;text:app.proposal?.layout?.summary||""}
                SetupText {visible:app.prepared;text:app.registerBootEntry?"A Forynarch firmware entry will be created. Existing boot entries are kept.":"Firmware entries will not change. Select EFI/Forynarch/grubx64.efi from your firmware's boot-file picker to start the installed system."}
                ProgressBar {
                    id:installationProgress;visible:install.running;Layout.fillWidth:true;from:0;to:10
                    value:Math.max(0,["prepare","download","partition","format","extract","packages","account","flatpak","bootloader","verify","complete"].indexOf(app.installationStage))
                    background:Rectangle {implicitHeight:6;radius:3;color:"#2a4059"}
                    contentItem:Item {implicitHeight:6;Rectangle {width:parent.width*installationProgress.visualPosition;height:6;radius:3;color:"#9acbff"}}
                }
                Flow {
                    visible:app.installationAttempted;Layout.fillWidth:true;spacing:8
                    SetupButton {text:app.detailsExpanded&&app.showingInstallationLog?"Hide installation log":"Show installation log";quiet:true;onClicked:app.toggleInstallationLog()}
                    SetupButton {visible:!install.running&&!app.installationComplete;text:app.detailsExpanded&&!app.showingInstallationLog?"Hide error details":"Show error details";quiet:true;onClicked:{app.detailsExpanded=!(app.detailsExpanded&&!app.showingInstallationLog);app.showingInstallationLog=false;}}
                    SetupButton {text:app.showingInstallationLog?"Copy log":"Copy error details";quiet:true;enabled:!copyDetails.running;onClicked:{app.copyPayload=app.showingInstallationLog?app.installationLogText:app.diagnosticsText;copyDetails.stdinEnabled=true;copyDetails.running=true;}}
                }
                SetupCheck {
                    visible:app.detailsExpanded&&app.showingInstallationLog&&(install.running||app.logPaused)
                    text:"Pause updates";checked:app.logPaused
                    onToggled:{app.logPaused=checked;if(!checked)app.installationShownLog=app.installationLiveLog;}
                }
                ScrollView {
                    id:installationLogView
                    visible:app.detailsExpanded;Layout.fillWidth:true;Layout.preferredHeight:220;clip:true
                    TextArea {
                        text:app.detailsExpanded?(app.showingInstallationLog?app.installationLogText:app.diagnosticsText):""
                        readOnly:true;selectByMouse:true;wrapMode:TextEdit.WrapAnywhere;activeFocusOnTab:true;textFormat:TextEdit.PlainText
                        color:"#dceaff";font.family:"monospace";font.pixelSize:12
                        Accessible.name:app.showingInstallationLog?"Installation log":"Installation error details"
                        selectionColor:"#305d8f";selectedTextColor:"#eef6ff"
                        background:Rectangle {color:"#0a1523";radius:5;border.color:parent.activeFocus?"#dceaff":"#405975"}
                        onTextChanged:if(app.showingInstallationLog&&!app.logPaused)Qt.callLater(function(){var view=installationLogView.contentItem;if(view&&typeof view.contentY==="number")view.contentY=Math.max(0,view.contentHeight-view.height);})
                    }
                }
                SetupButton {text:"Refresh storage review";enabled:!app.isBusy;onClicked:app.prepare()}
            }
        }
    Dialog {
        id:eraseDialog
        parent:app.contentItem;anchors.centerIn:parent;width:Math.min(560,app.width-40);padding:26
        modal:true;focus:true;closePolicy:Popup.CloseOnEscape
        onOpened:eraseCancel.forceActiveFocus()
        background:Rectangle {radius:12;color:"#20364f";border.color:"#b98377"}
        contentItem:ColumnLayout {spacing:16
            SetupText {text:app.prepared?"Format this root partition and install?":"Erase this disk and install Forynarch?";font.pixelSize:21;color:"#ffc2af"}
            SetupText {text:(app.disk?.path||"")+" · "+(app.disk?.name||"")+"\n"+(app.disk?.id||"");color:"#dceaff"}
            SetupText {text:app.prepared?("All files on "+(app.rootPartition?.path||"")+" will be erased. The EFI partition "+(app.efiPartition?.path||"")+" and other partitions are kept. Keep Live media connected."):"All files and operating systems on this disk will be erased. Other disks are not selected. Keep the Live media connected until installation finishes."}
            SetupText {text:"Type "+app.consentText+" to confirm.";color:"#ffc2af"}
            SetupField {id:eraseInput;Layout.fillWidth:true;Accessible.name:app.prepared?"Root partition installation confirmation":"Disk-specific erase confirmation"}
            RowLayout {Layout.fillWidth:true;Item {Layout.fillWidth:true}
                SetupButton {id:eraseCancel;text:"Cancel";onClicked:eraseDialog.close()}
                SetupButton {text:app.prepared?"Format root and install":"Erase disk and install";primary:true;enabled:app.canInstall&&eraseInput.text===app.consentText;onClicked:{app.installationError="";app.error="";eraseDialog.close();install.running=true;}}
            }
        }
    }
    Dialog {
        id:cancelDialog
            parent:app.contentItem;anchors.centerIn:parent
            width:Math.min(460,app.width-40);padding:26
            modal:true;focus:true;visible:app.cancelOpen
            closePolicy:Popup.CloseOnEscape
            onOpened:keepSetup.forceActiveFocus()
            onClosed:app.cancelOpen=false
            background:Rectangle {radius:10;color:"#20364f";border.color:"#4c6a89"}
            contentItem:ColumnLayout {spacing:20
                    SetupText {text:"Leave installation setup?";font.pixelSize:21;color:"#e1eeff"}
                    SetupText {text:"Your choices and passwords will be discarded. No disk changes have been made."}
                    RowLayout {Layout.fillWidth:true;Item {Layout.fillWidth:true} SetupButton {id:keepSetup;text:"Keep setting up";onClicked:app.cancelOpen=false} SetupButton {text:"Leave setup";primary:true;onClicked:app.close()}}
            }
        }
    }
}
