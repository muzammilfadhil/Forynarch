import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Networking

ColumnLayout {
    id: page
    required property var controller
    property var networkService: Networking
    property bool managerAvailable: true
    property bool compact:false
    readonly property var adapters: {
        const found = [];
        for (const device of networkService.devices.values)
            if (device.type === DeviceType.Wifi) found.push(device);
        return found;
    }
    readonly property var wiredAdapters: {
        const found = [];
        for (const device of networkService.devices.values)
            if (device.type === DeviceType.Wired) found.push(device);
        return found;
    }
    property int adapterIndex: 0
    readonly property var adapter: adapters[Math.min(adapterIndex, adapters.length - 1)] || null
    readonly property var networks: (adapter?.networks.values || []).slice().sort((a,b) =>
        Number(b.connected)-Number(a.connected) || Number(b.known)-Number(a.known) || b.signalStrength-a.signalStrength || a.name.localeCompare(b.name))
    property var scanOwner: null
    property bool scanning: false
    property string message: ""
    property var attempted: null
    property var passwordNetwork: null
    spacing: 12

    function stopScan() {
        scanTimer.stop(); if (scanOwner) scanOwner.scannerEnabled = false;
        scanOwner = null; scanning = false;
    }
    function startScan() {
        stopScan(); message = "";
        if (!adapter || !managerAvailable || !networkService.wifiEnabled || !networkService.wifiHardwareEnabled) return;
        scanOwner = adapter; scanOwner.scannerEnabled = true; scanning = true; scanTimer.start();
    }
    function psk(network) {return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(network.security);}
    function security(network) {
        if (network.security === WifiSecurityType.Open) return "Open network";
        if (network.security === WifiSecurityType.Owe) return "Enhanced open";
        if (psk(network)) return "Password protected";
        return "Additional sign-in required";
    }
    function passwordPrompt(network) {
        passwordNetwork = network; password.clear(); passwordDialog.open();
    }
    function connectNetwork(network) {
        message = ""; attempted = network;
        if (network.connected) {network.disconnect(); return;}
        if (!network.known && psk(network)) {passwordPrompt(network); return;}
        if (!network.known && ![WifiSecurityType.Open, WifiSecurityType.Owe].includes(network.security)) {
            controller.run(["forynarch-system", "connections"]); return;
        }
        network.connect();
    }
    function submitPassword() {
        const network = passwordNetwork;
        const secret = password.text;
        passwordDialog.close();
        if (!network || !networks.includes(network)) {message = "This network is no longer available. Scan and try again."; return;}
        attempted = network;
        try {network.connectWithPsk(secret);} catch (e) {message = "The connection could not be started. Please try again.";}
    }
    onAdapterChanged: {stopScan(); if (adapter) startScan();}
    onManagerAvailableChanged: {if (managerAvailable) startScan(); else stopScan();}
    Component.onCompleted: startScan()
    Component.onDestruction: {stopScan(); password.clear();}
    Timer {id: scanTimer; interval: 15000; onTriggered: page.stopScan()}
    Connections {
        target: page.networkService
        function onWifiEnabledChanged() {
            if (page.networkService.wifiEnabled) page.startScan();
            else {page.stopScan(); passwordDialog.close();}
        }
        function onWifiHardwareEnabledChanged() {
            if (page.networkService.wifiHardwareEnabled) page.startScan();
            else {page.stopScan(); passwordDialog.close();}
        }
    }

    SettingRow {
        visible: !page.compact
        Layout.fillWidth: true
        title: "Internet speed"
        description: "Open Fast.com in your default browser"
        ActionButton {
            label: "Run speed test"; icon: "network"
            implicitHeight: 44; animateHover: controller.motion; accent: controller.accent
            onClicked: {
                page.message = "";
                if (!Qt.openUrlExternally("https://fast.com/en/"))
                    page.message = "Could not open a browser. Install one and choose it in Settings > Default Apps.";
            }
        }
    }
    SettingRow {
        color:page.compact?"#24000000":"#192230"
        Layout.fillWidth: true; title: "Wi-Fi"
        description: page.adapter ? (page.networkService.wifiEnabled ? "Choose a network below" : "Turn on Wi-Fi to find nearby networks") : "No Wi-Fi adapter detected"
        ConnectivityToggle {
            text: "Wi-Fi"
            checked: !!page.adapter && page.networkService.wifiEnabled
            enabled: page.managerAvailable && !!page.adapter && page.networkService.wifiHardwareEnabled
            accent: controller.accent
            onClicked: page.networkService.wifiEnabled = checked
        }
    }
    Choice {
        visible: page.adapters.length > 1; implicitWidth: 240; implicitHeight: 44
        choices: page.adapters.map((d,i) => ({label: "Wi-Fi adapter " + (i+1), value: i}))
        selectedValue: page.adapterIndex; onChosen: value => page.adapterIndex = value
    }
    Text {
        Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.maximumWidth: page.width; wrapMode: Text.WordWrap; color: "#b5cbe3"; font.pixelSize: 13
        visible: !page.managerAvailable || !page.adapter || !page.networkService.wifiHardwareEnabled
        text: !page.managerAvailable ? "The network service is unavailable. Try reopening Settings or restarting the Live session." : !page.adapter ? "This computer has no available Wi-Fi adapter. If it has built-in Wi-Fi, check its hardware switch and driver support." : "Wi-Fi is blocked by a hardware switch or airplane mode. Enable wireless on your computer first."
    }
    RowLayout {
        Layout.fillWidth: true
        Text {text: page.scanning ? "Scanning for networks…" : "Nearby networks"; color: "#e2eeff"; font.pixelSize: 14; Layout.fillWidth: true}
        ActionButton {implicitHeight: 44; label: page.scanning ? "Stop scan" : "Scan"; enabled: !!page.adapter && page.managerAvailable && page.networkService.wifiEnabled && page.networkService.wifiHardwareEnabled; onClicked: page.scanning ? page.stopScan() : page.startScan()}
    }
    Text {
        Layout.fillWidth: true; visible: !!page.adapter && page.networkService.wifiEnabled && page.networks.length === 0
        text: page.scanning ? "Looking for nearby Wi-Fi networks. Keep your hotspot or router switched on." : "No networks found. Move closer to your router, then scan again."
        wrapMode: Text.WordWrap; color: "#b5cbe3"; font.pixelSize: 12
    }
    Text {Layout.fillWidth: true; visible: page.message !== ""; text: page.message; textFormat: Text.PlainText; color: "#f2c5aa"; wrapMode: Text.WordWrap; font.pixelSize: 13}
    Repeater {
        model: page.networkService.wifiEnabled ? page.networks : []
        ConnectivityRow {
            required property var modelData
            Layout.fillWidth: true
            heading: modelData.name || "Hidden network"
            iconName: modelData.signalStrength >= .65 ? "network" : modelData.signalStrength >= .35 ? "network-medium" : "network-weak"
            connected: modelData.connected
            detail: (modelData.connected ? "Connected · " : modelData.stateChanging ? "Connecting… · " : modelData.known ? "Saved · " : "") + page.security(modelData) + " · " + (modelData.signalStrength >= .65 ? "Strong signal" : modelData.signalStrength >= .35 ? "Fair signal" : "Weak signal")
            ActionButton {
                implicitHeight: 44
                label: modelData.connected ? "Disconnect" : modelData.stateChanging ? "Connecting…" : "Connect"
                enabled: !modelData.stateChanging && !!modelData.name
                onClicked: page.connectNetwork(modelData)
            }
            Connections {
                target: modelData
                function onConnectionFailed(reason) {
                    if (page.attempted !== modelData) return;
                    page.message = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout ? "Sign-in failed. Check the password and try again." : "Could not connect. Check the network and try again.";
                    if (page.psk(modelData)) page.passwordPrompt(modelData);
                }
            }
        }
    }
    Repeater {
        model: page.wiredAdapters
        ConnectivityRow {required property var modelData; Layout.fillWidth: true; iconName: "ethernet"; heading: "Ethernet"; detail: modelData.connected ? "Cable connected" : "Connect an Ethernet cable to use a wired network"; connected: modelData.connected}
    }
    ActionButton {implicitHeight: 44; label: "Advanced network settings"; quiet: true; enabled: page.managerAvailable; onClicked: controller.run(["forynarch-system", "connections"])}

    Dialog {
        id: passwordDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(440, (parent?.width || 480) - 32)
        padding: 24; modal: true; closePolicy: Popup.CloseOnEscape
        background: Rectangle {radius: 16; color: "#14263b"; border.color: "#6483a3"}
        onOpened: password.forceActiveFocus()
        onClosed: {password.clear(); page.passwordNetwork = null; showPassword.checked = false;}
        contentItem: ColumnLayout {
            spacing: 14
            Text {Layout.fillWidth: true; text: "Connect to " + (page.passwordNetwork?.name || "Wi-Fi"); textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere; color: "#e2eeff"; font.pixelSize: 18; font.weight: Font.DemiBold}
            Text {text: "Enter the Wi-Fi password"; color: "#b5cbe3"; font.pixelSize: 13}
            ConnectivityField {id: password; objectName: "wifiPassword"; Layout.fillWidth: true; placeholderText: "Password"; echoMode: showPassword.checked ? TextInput.Normal : TextInput.Password; onAccepted: if (text.length) page.submitPassword()}
            ConnectivityCheck {id: showPassword; text: "Show password"}
            Text {Layout.fillWidth: true; text: "NetworkManager remembers successful connections. In a non-persistent Live session, they are lost after restarting."; wrapMode: Text.WordWrap; color: "#b5cbe3"; font.pixelSize: 12}
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Item {Layout.fillWidth: true}
                ActionButton {implicitHeight: 44; label: "Cancel"; onClicked: passwordDialog.close()}
                ActionButton {implicitHeight: 44; label: "Connect"; selected: true; accent: controller.accent; enabled: password.text.length > 0; onClicked: page.submitPassword()}
            }
        }
    }
}
