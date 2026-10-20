import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "PanelMetrics.js" as Metrics

ShellRoot {
    id: test
    property int phase: 0
    readonly property var keys: ["panelShowLauncher","panelShowTray","panelShowNotifications","panelShowAudio","panelShowControls","panelShowBattery","panelShowSettings","panelShowApps","panelShowWorkspaces","panelShowClock","panelShowMode","panelShowNetwork","panelShowPower","panelShowDesktop","previewLive"]
    QtObject {
        id: mock
        property bool panelShowLauncher:true
        property bool panelShowTray:true
        property bool panelShowNotifications:true
        property bool panelShowAudio:true
        property bool panelShowControls:true
        property bool panelShowBattery:true
        property bool panelShowSettings:true
        property bool panelShowApps:true
        property bool panelShowWorkspaces:true
        property bool panelShowClock:true
        property bool panelShowMode:true
        property bool panelShowNetwork:true
        property bool panelShowPower:true
        property bool panelShowDesktop:true
        property bool previewLive:true
        property bool motion:false
        property bool motionBlur:false
        property bool glass:false
        property int frost:4
        property color accent:"#9acbff"
        property var panelMetrics:Metrics.defaults()
        property bool panelCompact:false
        property int panelSpacing:12
        property int panelActualHeight:44
        property int panelReserved:54
        property bool bottomPanel:false
        property bool islands:true
        property string windowMode:"hybrid"
        property int workspace:1
        property date now:new Date()
        property string timeText:"12:34"
        property bool trayOpen:false
        property bool notificationsOpen:false
        property bool notificationsDnd:false
        property int notificationCount:0
        property var audio:null
        property var windowState:({windows:[],active:"",desktopShown:false})
        property bool settingsOpen:false
        property bool controlOpen:false
        property bool controlAudioRequested:false
        property bool batteryOpen:false
        property string batteryError:""
        property string openedPage:""
        property var batteryStatus:({capacity:50,charging:false,batteries:[{name:"Fixture BAT0",capacity:50,status:"Discharging",watts:12,seconds:7200,timeEstimated:true,energyWh:24,fullWh:48,health:80,temperatureC:null,cycles:null}],adapters:[{name:"Fixture AC",type:"Mains",online:false,watts:null}]})
        function setPanel(key,value){mock[key]=value;}
        function clearPopups(){batteryOpen=false;}
        function openBattery(){batteryOpen=!batteryOpen;}
        function dismissBattery(){batteryOpen=false;}
        function openSettings(page){openedPage=page;batteryOpen=false;}
        function run(command){}
        function openLauncher(){}
        function openNotifications(){}
        function openAdvancedAudio(){}
        function openControls(){}
        function dismissControls(){}
        function dismissSettings(){}
        function controlWindow(action,address){}
    }
    DesktopPanel { id:bar;controller:mock;implicitWidth:Number(Quickshell.env("FORYNARCH_PANEL_TEST_WIDTH")||1280);anchors.left:false;anchors.right:false;apple:Quickshell.env("FORYNARCH_PANEL_TEST_STYLE")==="macshell" }
    LazyLoader { id:popup;active:mock.batteryOpen;component:BatteryPanel{controller:mock} }
    FloatingWindow {
        id:settings
        implicitWidth:760;implicitHeight:660;color:"#111823"
        ScrollView {
            anchors.fill:parent;anchors.margins:20;contentWidth:availableWidth
            ColumnLayout {
                width:parent.width
                PanelComponents {id:components;Layout.fillWidth:true;controller:mock}
                BatteryDetails {id:details;Layout.fillWidth:true;controller:mock}
            }
        }
    }
    function all(item,predicate,result){if(predicate(item))result.push(item);for(const child of item.children||[])all(child,predicate,result);return result;}
    function check(condition,message){if(!condition)throw new Error(message);}
    Timer {
        interval:250;repeat:true;running:true
        onTriggered:{try{
            if(test.phase===0){
                const rightGroup=test.all(bar.contentItem,item=>item.objectName==="panel-right",[])[0];
                const dateButton=test.all(bar.contentItem,item=>item.hint==="Date and time",[])[0];
                const dateCard=dateButton.parent.parent;
                const dateRight=dateCard.mapToItem(bar.contentItem,dateCard.width,0).x;
                console.log("Panel geometry: width="+bar.width+" controls="+rightGroup.x+" clockEnd="+dateRight);
                test.check(rightGroup.x>=dateRight,"Panel controls overlap the clock at "+bar.width+" pixels");
                const toggles=test.all(components,item=>item.checkable===true,[]);
                test.check(toggles.length===test.keys.length,"Missing panel toggles");
                for(let i=0;i<toggles.length;i++){
                    toggles[i].click();test.check(mock[test.keys[i]]===false,"Toggle did not hide "+test.keys[i]);
                }
                test.phase=1;return;
            }
            if(test.phase===1){
                const groups=test.all(bar.contentItem,item=>["panel-left","panel-right"].includes(item.objectName),[]);
                test.check(groups.length===2&&groups.every(item=>!item.visible),"Empty panel groups remain visible");
                const toggles=test.all(components,item=>item.checkable===true,[]);
                for(let i=0;i<toggles.length;i++){toggles[i].click();test.check(mock[test.keys[i]]===true,"Toggle did not restore "+test.keys[i]);}
                test.phase=2;return;
            }
            if(test.phase===2){
                const texts=test.all(details,item=>typeof item.text==="string",[]).map(item=>item.text);
                test.check(texts.includes("12.0 W")&&texts.includes("Power drawn from the battery"),"Discharge power missing");
                test.check(texts.includes("2 hr 0 min (estimated)")&&texts.includes("Not reported"),"Estimated or unavailable fields missing");
                const button=test.all(bar.contentItem,item=>item.hint==="Battery and power",[])[0];
                test.check(button&&button.visible,"Battery indicator missing");button.clicked();test.phase=3;return;
            }
            if(test.phase===3){
                const button=test.all(popup.item.contentItem,item=>item.label==="Power settings",[])[0];
                test.check(button,"Power settings action missing");button.clicked();test.check(mock.openedPage==="Power"&&!mock.batteryOpen,"Power settings route failed");
                mock.openBattery();test.phase=4;return;
            }
            if(test.phase===4){
                const close=test.all(popup.item.contentItem,item=>item.hint==="Close battery details",[])[0];
                test.check(close,"Battery close action missing");close.clicked();test.check(!mock.batteryOpen,"Battery close failed");
                mock.batteryStatus={capacity:null,charging:false,batteries:[],adapters:[]};test.phase=5;return;
            }
            const button=test.all(bar.contentItem,item=>item.hint==="Battery and power",[])[0];
            test.check(button&&!button.visible,"Battery shown on a desktop without a battery");
            console.log("PASS: 15 panel toggles, empty groups, battery watts/time/unsupported fields, popup settings/close and no-battery state");Qt.exit(0);
        }catch(error){console.error("FAIL: "+error.message);Qt.exit(1);}}
    }
    Timer {interval:15000;running:true;onTriggered:{console.error("FAIL: battery panel flow timed out");Qt.exit(1);}}
}
