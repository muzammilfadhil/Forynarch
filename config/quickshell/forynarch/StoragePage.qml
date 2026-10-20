import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id:page
    required property var controller
    property var inventory:({disks:[],software:[],revision:"",live:false,uefi:false})
    property string diskId:""
    property string partitionId:""
    property string view:"disks"
    property string operation:"create"
    property string filesystem:"ext4"
    property string sizeText:"32"
    property var proposal:null
property string error:""
property bool advancedAvailable:false
    readonly property bool busy:scan.running||review.running
    readonly property var disk:inventory.disks.find(d=>d.id===diskId)||null
    readonly property var partition:disk?.partitions.find(p=>p.id===partitionId)||null
    spacing:12
    function size(bytes){return bytes>=1e12?(bytes/1e12).toFixed(2)+" TB":(bytes/1e9).toFixed(2)+" GB";}
    function refresh(){if(!busy){proposal=null;error="";scan.running=true;}}
    function prepare(kind){
        if(busy)return;error="";proposal=null;
        const request={kind:kind,revision:inventory.revision,diskId:diskId,partitionId:partitionId,filesystem:filesystem,sizeGiB:Number(sizeText),selectedGroups:[],offline:false};
        review.command=["forynarch-storage","review",JSON.stringify(request)];review.running=true;
    }
    onDiskIdChanged:{partitionId="";proposal=null;}
    onDiskChanged:{if(!disk?.partitions.some(p=>p.id===partitionId))partitionId=disk?.partitions[0]?.id||"";proposal=null;}
    onPartitionIdChanged:proposal=null
    onOperationChanged:proposal=null
    onFilesystemChanged:proposal=null
    onSizeTextChanged:proposal=null
    Component.onCompleted:{refresh();advancedStatus.running=true;}
    Process {
        id:advancedStatus;command:["forynarch-partitions","status"]
        stdout:StdioCollector {onStreamFinished:{try{page.advancedAvailable=JSON.parse(text).available===true;}catch(e){page.advancedAvailable=false;}}}
    }
    IpcHandler {target:"storage";function status():string{return JSON.stringify({view:page.view,diskCount:page.inventory.disks.length,partitionCount:page.disk?.partitions.length||0,hasProposal:!!page.proposal,canExecute:page.proposal?.canExecute===true,blockers:page.proposal?.blockers||[],error:page.error});}}
    Process {
        id:scan;command:["forynarch-storage","list"]
        stdout:StdioCollector {onStreamFinished:{try{page.inventory=JSON.parse(text);if(!page.inventory.disks.some(d=>d.id===page.diskId))page.diskId=page.inventory.disks[0]?.id||"";}catch(e){page.error="Storage information could not be read.";}}}
        stderr:StdioCollector {onStreamFinished:{if(text.trim())page.error=text.trim();}}
    }
    Process {
        id:review
        stdout:StdioCollector {onStreamFinished:{try{page.proposal=JSON.parse(text);}catch(e){page.error="The proposal could not be prepared. Refresh and try again.";}}}
        stderr:StdioCollector {onStreamFinished:{if(text.trim())page.error=text.trim();}}
    }
    RowLayout {
        Layout.fillWidth:true;spacing:8
        ActionButton {label:"Disks & partitions";selected:page.view==="disks";accent:controller.accent;onClicked:{page.view="disks";page.proposal=null;}}
        ActionButton {label:"Plan changes";selected:page.view==="changes";accent:controller.accent;onClicked:{page.view="changes";page.proposal=null;}}
        Item {Layout.fillWidth:true}
        ActionButton {icon:"folder";quiet:true;hint:"Open This Computer";onClicked:controller.openDrives()}
    }
    SettingRow {
        Layout.fillWidth:true;title:"Advanced partition manager"
        description:page.advancedAvailable?"KDE Partition Manager · Create, resize, move, format and delete partitions. Review pending operations before applying.":"KDE Partition Manager is included in new builds. It is not installed in this preview."
        ActionButton {label:"Open advanced";enabled:page.advancedAvailable;onClicked:{Quickshell.execDetached(["forynarch-partitions","open"]);controller.dismissSettings();}}
    }
    Rectangle {
        Layout.fillWidth:true;implicitHeight:72;radius:14;color:"#203249"
        ColumnLayout {anchors.fill:parent;anchors.margins:14;spacing:4
            Text {text:"Explore your storage";color:"#dfeaff";font.pixelSize:14;font.weight:Font.DemiBold}
            Text {Layout.fillWidth:true;text:page.view==="disks"?"View disks and partitions without changing their contents.":"Prepare and review a proposal. This preview cannot apply disk changes or install the system.";color:"#a0bbd8";font.pixelSize:12;wrapMode:Text.WordWrap}
        }
    }
    RowLayout {
        Layout.fillWidth:true
        Text {Layout.fillWidth:true;text:page.inventory.live?"Live session · "+(page.inventory.uefi?"UEFI":"Legacy firmware"):"Installed session";color:"#91a8c3";font.pixelSize:11}
        ActionButton {label:page.busy?"Reading…":"Refresh disks";enabled:!page.busy;onClicked:page.refresh()}
    }
    SettingRow {Layout.fillWidth:true;title:"Disk";description:page.disk?page.disk.path+" · "+page.size(page.disk.size)+" · "+page.disk.table:"No physical or virtual hard disk detected"
        Choice {implicitWidth:260;choices:page.inventory.disks.map(d=>({label:d.name+" · "+page.size(d.size),value:d.id}));selectedValue:page.diskId;enabled:page.inventory.disks.length>0&&!page.busy;onChosen:v=>page.diskId=v}
    }
    Text {Layout.fillWidth:true;visible:!page.disk;text:"This VM exposes only its attached devices. Windows host disks are not exposed. Attach a separate disposable virtual disk to test disk layouts.";color:"#91a8c3";font.pixelSize:12;wrapMode:Text.WordWrap}
    ColumnLayout {
        Layout.fillWidth:true;visible:page.view==="disks"&&!!page.disk;spacing:10
        Rectangle {
            Layout.fillWidth:true;implicitHeight:18;radius:6;color:"#26354a";clip:true
            Repeater {model:page.disk?.partitions||[]
                Rectangle {required property var modelData;x:parent.width*Math.max(0,modelData.start/(page.disk?.size||1));width:Math.max(2,parent.width*modelData.size/(page.disk?.size||1));height:parent.height;color:modelData.protected?"#8495b8":modelData.encrypted?"#bc9dca":modelData.filesystem==="ntfs"?"#729cd0":"#8bcbd0";border.width:1;border.color:"#192230"}
            }
        }
        Text {Layout.fillWidth:true;text:page.disk?(page.disk.geometryKnown?"Estimated unallocated: "+page.size(page.disk.unallocatedEstimate)+" · Partition-table verification is still required":"Unallocated regions require a verified GPT layout") : "";color:"#91a8c3";font.pixelSize:11;wrapMode:Text.WordWrap}
        Repeater {model:page.disk?.partitions||[]
            SettingRow {required property var modelData;Layout.fillWidth:true;implicitHeight:88;title:modelData.name||modelData.path;description:modelData.path+" · "+modelData.filesystem+" · "+page.size(modelData.size)+"\n"+modelData.role+(modelData.mounted?" · In use":"")+(modelData.encrypted?" · Encrypted":"")
                ActionButton {label:"Manage";onClicked:{page.partitionId=modelData.id;page.view="changes";page.operation="resize";}}
            }
        }
        Text {visible:!!page.disk&&(page.disk.partitions.length===0);text:page.disk?.wholeFilesystem?"This disk has a whole-device filesystem; do not treat it as empty.":"No partitions reported";color:"#91a8c3";font.pixelSize:12}
    }
    ColumnLayout {
        Layout.fillWidth:true;visible:page.view==="changes";spacing:10
        SettingRow {Layout.fillWidth:true;title:"Operation";description:"Review a proposed change before any future authorization"
            Choice {implicitWidth:220;choices:[{label:"Create partition",value:"create"},{label:"Resize partition",value:"resize"},{label:"Format partition",value:"format"},{label:"Delete partition",value:"delete"}];selectedValue:page.operation;onChosen:v=>page.operation=v}
        }
        SettingRow {Layout.fillWidth:true;visible:page.operation!=="create";title:"Partition";description:page.partition?page.partition.path+" · "+page.partition.role:"Select a partition"
            Choice {implicitWidth:260;choices:(page.disk?.partitions||[]).map(p=>({label:(p.name||p.path)+" · "+page.size(p.size),value:p.id}));selectedValue:page.partitionId;onChosen:v=>page.partitionId=v}
        }
        SettingRow {Layout.fillWidth:true;visible:page.operation==="create"||page.operation==="format";title:"Filesystem";description:"ext4/Btrfs for Linux · exFAT/NTFS for shared data"
            Choice {choices:["ext4","btrfs","exfat","ntfs"].map(f=>({label:f,value:f}));selectedValue:page.filesystem;onChosen:v=>page.filesystem=v}
        }
        SettingRow {Layout.fillWidth:true;visible:page.operation==="create"||page.operation==="resize";title:"Requested size";description:"GiB · A proposal, not a verified filesystem resize limit"
            TextField {implicitWidth:160;implicitHeight:38;text:page.sizeText;onTextEdited:page.sizeText=text;color:"#dceaff"
                validator:DoubleValidator {bottom:1;top:1048576;decimals:2;locale:"en_US"}
                background:Rectangle {radius:10;color:"#24374e";border.width:1;border.color:"#38506c"}
            }
        }
        Text {Layout.fillWidth:true;text:"Mounted, system, boot, recovery, encrypted and read-only partitions stay protected. Resize limits and filesystem health need an offline check.";color:"#91a8c3";font.pixelSize:12;wrapMode:Text.WordWrap}
        ActionButton {label:"Review proposed change";enabled:!!page.disk&&!page.busy;onClicked:page.prepare(page.operation)}
    }
    ColumnLayout {
        Layout.fillWidth:true;visible:!!page.proposal;spacing:10
        Text {text:"PROPOSED CHANGES";color:page.proposal?.destructive?"#f1b8a8":"#9acbff";font.pixelSize:11;font.letterSpacing:1}
        Text {Layout.fillWidth:true;text:page.proposal?.summary||"";color:"#dfe9f8";font.pixelSize:13;wrapMode:Text.WordWrap}
        SettingRow {Layout.fillWidth:true;title:"Target";description:(page.proposal?.target.disk||"")+(page.proposal?.target.partition?" · "+page.proposal.target.partition:"")}
        Repeater {model:page.proposal?.blockers||[]
            Text {required property string modelData;Layout.fillWidth:true;text:"• "+modelData;color:"#f1b8a8";font.pixelSize:12;wrapMode:Text.WordWrap}
        }
        Repeater {model:page.proposal?.checks||[]
            Text {required property string modelData;Layout.fillWidth:true;text:"• "+modelData;color:"#91a8c3";font.pixelSize:12;wrapMode:Text.WordWrap}
        }
        Text {Layout.fillWidth:true;text:"No changes applied. Your disks and existing operating systems remain unchanged.";color:"#91a8c3";font.pixelSize:12;wrapMode:Text.WordWrap}
    }
    Text {Layout.fillWidth:true;visible:page.error!=="";text:page.error;color:"#f1b8a8";font.pixelSize:12;wrapMode:Text.WordWrap}
}
