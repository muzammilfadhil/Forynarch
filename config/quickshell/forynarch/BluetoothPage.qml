import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Bluetooth

ColumnLayout {
    id: page
    required property var controller
    property var bluetoothService: Bluetooth
    property bool pairingAvailable: true
    readonly property var adapters: bluetoothService.adapters.values
    property int adapterIndex: 0
    readonly property var adapter: adapters[Math.min(adapterIndex, adapters.length - 1)] || null
    readonly property var devices: (adapter?.devices.values || []).slice().sort((a,b) => Number(b.connected)-Number(a.connected) || Number(b.paired)-Number(a.paired) || (a.name || "").localeCompare(b.name || ""))
    property var scanOwner: null
    property bool scanning: false
    property bool healthLoaded:false
    property var health:({serviceRunning:true,softBlocked:false,hardBlocked:false})
    property string message: ""
    property var pairingDevice: null
    property var forgetDevice: null
    property var optionsDevice: null
    property string pairingPhase: "waiting"
    property string pairingCode: ""
    property var pendingConnection: null
    spacing: 12

    function stopScan() {scanTimer.stop();scanWatch.stop();if (scanOwner) scanOwner.discovering = false; scanOwner = null; scanning = false;}
    function startScan() {
        stopScan(); message = ""; if (!adapter?.enabled) return;
        scanOwner = adapter; scanOwner.discovering = true; scanning = true; scanTimer.start();scanWatch.restart();
    }
    function reply(value) {if (agent.running) agent.write(JSON.stringify(value) + "\n"); pin.clear();}
    function cancelPairing() {reply({cancel:true}); pairDialog.close();}
    function pair(device) {
        if (agent.running || !pairingAvailable || !device || device.blocked) return;
        stopScan(); message = ""; pairingDevice = device; pairingPhase = "waiting"; pairingCode = "";
        agent.command = ["forynarch-bluetooth-pair", device.dbusPath]; agent.running = true; pairDialog.open();
        startWatch.start();
    }
    function connectSaved(device) {
        stopScan(); pendingConnection = device; message = "Connecting your device…"; connectionWait.restart(); device.connect();
    }
    function received(value) {
        pairingPhase = value.type; pairingCode = value.code || "";
        if (["connected", "paired", "failed", "unavailable", "canceled"].includes(value.type)) {
            message = value.type === "connected" ? "Device paired and connected." : value.type === "paired" ? "Device paired. Switch it on and choose Connect when it is ready." : value.type === "failed" ? "Pairing failed. Put the device in pairing mode and try again." : value.type === "unavailable" ? "Pairing is unavailable. Check that Bluetooth is switched on and try again." : "Pairing canceled.";
            pairDialog.close();
        }
        if (["pin", "passkey"].includes(value.type)) pin.forceActiveFocus();
    }
    onAdapterChanged: {stopScan(); if (adapter?.enabled) startScan();}
    Component.onCompleted: {if(bluetoothService===Bluetooth)healthRead.running=true;startScan();}
    Timer {id:scanWatch;interval:1500;onTriggered:if(page.scanOwner&&!page.scanOwner.discovering){page.stopScan();page.message="Scanning could not start. Check Bluetooth power and airplane mode, then try again.";if(page.bluetoothService===Bluetooth)healthRead.running=true;}}
    Process {id:healthRead;command:["forynarch-bluetooth","status"]
        stdout:StdioCollector {onStreamFinished:{try{page.health=JSON.parse(text);page.healthLoaded=true;}catch(e){}}}
    }
    Process {id:recover;command:["pkexec","/usr/local/libexec/forynarch-bluetooth-recover"]
        onExited:(code,status)=>{healthRead.running=true;if(code===0){if(page.adapter)page.adapter.enabled=true;page.message="Bluetooth service enabled. Switch on the adapter and scan for your device.";}else page.message="Bluetooth could not be enabled. Authentication may have been cancelled.";}
    }
    Component.onDestruction: {stopScan(); reply({cancel:true}); pin.clear();}
    Timer {id: scanTimer; interval: 20000; onTriggered: page.stopScan()}
    Timer {id: startWatch; interval: 1500; onTriggered: {if (!agent.processId) {page.message = "The pairing helper is unavailable. Please try again."; pairDialog.close();}}}
    Timer {id: connectionWait; interval: 15000; onTriggered: {if (page.pendingConnection && !page.pendingConnection.connected) page.message = "Could not connect. Make sure the device is switched on and not connected to another computer."; page.pendingConnection = null;}}
    Connections {target: page.adapter; function onEnabledChanged() {if (page.adapter?.enabled) page.startScan(); else {page.stopScan(); page.cancelPairing();}}}
    Process {
        id: agent; stdinEnabled: true
        onStarted: startWatch.stop()
        stdout: SplitParser {
            onRead: value => {try {page.received(JSON.parse(value));} catch (e) {page.message = "The pairing response could not be read. Please try again."; page.cancelPairing();}}
        }
        onExited: (code,status) => {
            if (pairDialog.visible) {page.message = "The pairing helper stopped. Please try again."; pairDialog.close();}
            page.pairingCode = ""; pin.clear(); page.pairingDevice = null;
        }
    }

    SettingRow {
        Layout.fillWidth: true; title: "Bluetooth"
        description: page.adapter ? (page.adapter.enabled ? "Connect headphones, keyboards and other devices" : "Turn on Bluetooth to find nearby devices") : "No Bluetooth adapter detected"
        ConnectivityToggle {text: "Bluetooth"; checked: page.adapter?.enabled || false; enabled: !!page.adapter; accent: controller.accent; onClicked: page.adapter.enabled = checked}
    }
    Text {Layout.fillWidth:true;visible:page.healthLoaded&&page.health.hardBlocked;text:"Bluetooth is blocked by a hardware switch or firmware. Turn it on using the laptop's radio key or firmware settings.";color:"#efc2b0";font.pixelSize:13;wrapMode:Text.WordWrap}
    ActionButton {visible:page.healthLoaded&&(!page.health.serviceRunning||page.health.softBlocked)&&!page.health.hardBlocked;label:recover.running?"Enabling Bluetooth…":"Enable Bluetooth service and radio";enabled:!recover.running;onClicked:recover.running=true}
    ActionButton {visible:page.bluetoothService===Bluetooth;label:"Check Bluetooth";enabled:!healthRead.running&&!recover.running;onClicked:healthRead.running=true}
    Choice {
        visible: page.adapters.length > 1; implicitWidth: 240; implicitHeight: 44
        choices: page.adapters.map((d,i) => ({label: "Bluetooth adapter " + (i+1), value: i}))
        selectedValue: page.adapterIndex; onChosen: value => page.adapterIndex = value
    }
    Text {Layout.fillWidth: true; visible: !page.adapter; text: "This computer has no available Bluetooth adapter. Check its hardware switch or connect a supported USB adapter."; wrapMode: Text.WordWrap; color: "#b5cbe3"; font.pixelSize: 13}
    Text {Layout.fillWidth: true; visible: !!page.adapter && !page.pairingAvailable; text: "New-device pairing is not available in this preview. Saved devices can still connect."; wrapMode: Text.WordWrap; color: "#f2c5aa"; font.pixelSize: 12}
    RowLayout {
        Layout.fillWidth: true
        Text {Layout.fillWidth: true; text: page.scanning ? "Scanning for devices…" : "Your devices and nearby devices"; color: "#e2eeff"; font.pixelSize: 14}
        ActionButton {implicitHeight: 44; label: page.scanning ? "Stop scan" : "Scan"; enabled: !!page.adapter?.enabled && !agent.running; onClicked: page.scanning ? page.stopScan() : page.startScan()}
    }
    Text {Layout.fillWidth: true; visible: !!page.adapter?.enabled; text: "To add a new device, switch it to pairing mode and keep it nearby. Scanning stops automatically."; wrapMode: Text.WordWrap; color: "#b5cbe3"; font.pixelSize: 12}
    Text {Layout.fillWidth: true; visible: !!page.adapter?.enabled && page.devices.length === 0; text: page.scanning ? "Looking for devices…" : "No devices found. Turn on pairing mode, then scan again."; wrapMode: Text.WordWrap; color: "#b5cbe3"; font.pixelSize: 13}
    Text {Layout.fillWidth: true; visible: page.message !== ""; text: page.message; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: "#f2c5aa"; font.pixelSize: 13}
    Repeater {
        model: page.adapter?.enabled ? page.devices : []
        ColumnLayout {
            required property var modelData
            Layout.fillWidth: true; spacing: 4
            ConnectivityRow {
                Layout.fillWidth: true; iconName: "bluetooth"; heading: modelData.name || "Unnamed Bluetooth device"; connected: modelData.connected
                detail: modelData.blocked ? "Blocked" : modelData.connected ? "Connected" + (modelData.batteryAvailable ? " · Battery " + Math.round(modelData.battery*100) + "%" : "") : modelData.pairing ? "Pairing…" : modelData.paired ? "Saved device" : "Ready to pair"
                ActionButton {implicitHeight: 44; label: modelData.connected ? "Disconnect" : page.pendingConnection === modelData ? "Connecting…" : modelData.paired ? "Connect" : "Pair"; enabled: !agent.running && page.pendingConnection !== modelData && !modelData.pairing && !modelData.blocked && (modelData.paired || page.pairingAvailable); onClicked: {page.message = ""; if (modelData.connected) modelData.disconnect(); else if (modelData.paired) page.connectSaved(modelData); else page.pair(modelData);}}
                ActionButton {implicitHeight: 44; visible: modelData.paired; label: "Options"; quiet: true; enabled: !agent.running; onClicked: {page.optionsDevice = modelData; optionsDialog.open();}}
            }
            Connections {target: modelData; function onConnectedChanged() {if (page.pendingConnection === modelData && modelData.connected) {connectionWait.stop(); page.pendingConnection = null; page.message = "Device connected.";}}}
        }
    }

    Dialog {
        id: pairDialog; parent: Overlay.overlay; anchors.centerIn: parent
        width: Math.min(440, (parent?.width || 480)-32); padding: 24; modal: true; closePolicy: Popup.NoAutoClose
        background: Rectangle {radius: 16; color: "#14263b"; border.color: "#6483a3"}
        onClosed: {page.reply({cancel:true}); pin.clear(); page.pairingCode = "";}
        contentItem: ColumnLayout {
            spacing: 14
            Keys.onEscapePressed: page.cancelPairing()
            Text {Layout.fillWidth: true; text: "Pair " + (page.pairingDevice?.name || "Bluetooth device"); textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere; color: "#e2eeff"; font.pixelSize: 18; font.weight: Font.DemiBold}
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: "#b5cbe3"; font.pixelSize: 13
                text: page.pairingPhase === "confirm" ? "Check that this code also appears on your device. Confirm only if it matches." : page.pairingPhase === "display" ? "Enter this code on your Bluetooth device, then press Enter on that device." : ["pin", "passkey"].includes(page.pairingPhase) ? "Enter the pairing code shown on your device or in its instructions." : page.pairingPhase === "authorize" ? "Allow this device to pair and connect?" : page.pairingPhase === "connecting" ? "Paired. Connecting your device…" : "Waiting for your device. Keep it switched on and nearby."
            }
            Text {Layout.fillWidth: true; visible: page.pairingCode !== ""; text: page.pairingCode; textFormat: Text.PlainText; color: "#e2eeff"; font.pixelSize: 32; font.letterSpacing: 4; horizontalAlignment: Text.AlignHCenter; Accessible.name: "Pairing code " + text}
            ConnectivityField {id: pin; Layout.fillWidth: true; visible: ["pin", "passkey"].includes(page.pairingPhase); placeholderText: "Pairing code"; maximumLength: page.pairingPhase === "pin" ? 16 : 6; onAccepted: if (text.length) page.reply(page.pairingPhase === "pin" ? {pin:text} : {passkey:text})}
            RowLayout {
                Layout.fillWidth: true
                Item {Layout.fillWidth: true}
                ActionButton {id: cancelPair; implicitHeight: 44; label: "Cancel"; onClicked: page.cancelPairing()}
                ActionButton {implicitHeight: 44; label: "Confirm"; selected: true; accent: controller.accent; visible: ["confirm", "authorize", "pin", "passkey"].includes(page.pairingPhase); enabled: !["pin", "passkey"].includes(page.pairingPhase) || pin.text.length > 0; onClicked: page.reply(page.pairingPhase === "pin" ? {pin:pin.text} : page.pairingPhase === "passkey" ? {passkey:pin.text} : {approve:true})}
            }
        }
        onOpened: cancelPair.forceActiveFocus()
    }
    Dialog {
        id: optionsDialog; parent: Overlay.overlay; anchors.centerIn: parent
        width: Math.min(440, (parent?.width || 480)-32); padding: 24; modal: true; closePolicy: Popup.CloseOnEscape
        background: Rectangle {radius: 16; color: "#14263b"; border.color: "#6483a3"}
        onClosed: page.optionsDevice = null
        contentItem: ColumnLayout {
            spacing: 14
            Text {Layout.fillWidth: true; text: page.optionsDevice?.name || "Device options"; textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere; color: "#e2eeff"; font.pixelSize: 18}
            SettingRow {Layout.fillWidth: true; title: "Allow automatic reconnection"; description: "Only enable this for a device you trust"; ConnectivityToggle {text: "Allow automatic reconnection"; checked: page.optionsDevice?.trusted || false; accent: controller.accent; onClicked: if (page.optionsDevice) page.optionsDevice.trusted = checked}}
            RowLayout {
                Layout.fillWidth: true
                ActionButton {implicitHeight: 44; label: "Forget"; quiet: true; onClicked: {const device = page.optionsDevice; optionsDialog.close(); page.forgetDevice = device; forgetDialog.open();}}
                Item {Layout.fillWidth: true}
                ActionButton {id: deviceOptionsDone; implicitHeight: 44; label: "Done"; onClicked: optionsDialog.close()}
            }
        }
        onOpened: deviceOptionsDone.forceActiveFocus()
    }
    Dialog {
        id: forgetDialog; parent: Overlay.overlay; anchors.centerIn: parent
        width: Math.min(440, (parent?.width || 480)-32); padding: 24; modal: true; closePolicy: Popup.CloseOnEscape
        background: Rectangle {radius: 16; color: "#14263b"; border.color: "#6483a3"}
        onClosed: page.forgetDevice = null
        contentItem: ColumnLayout {
            spacing: 14
            Text {Layout.fillWidth: true; text: "Forget " + (page.forgetDevice?.name || "this device") + "?"; textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere; color: "#e2eeff"; font.pixelSize: 18}
            Text {Layout.fillWidth: true; text: "You will need to pair it again before reconnecting."; wrapMode: Text.WordWrap; color: "#b5cbe3"; font.pixelSize: 13}
            RowLayout {Layout.fillWidth: true; Item {Layout.fillWidth: true} ActionButton {id: keepDevice; implicitHeight: 44; label: "Cancel"; onClicked: forgetDialog.close()} ActionButton {implicitHeight: 44; label: "Forget device"; onClicked: {const device = page.forgetDevice; forgetDialog.close(); if (device) device.forget();}}}
        }
        onOpened: keepDevice.forceActiveFocus()
    }
}
