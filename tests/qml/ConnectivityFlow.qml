import QtQuick
import Quickshell
import Quickshell.Networking
import "."
ShellRoot {
    id: test
    property int phase: 0
    QtObject {id: mockController; property bool motion: false; property color accent: "#9acbff"; property var lastCommand: []; function run(command) {lastCommand = command;}}
    QtObject {
        id: secured
        property string name: "QA secured network"
        property bool connected: false; property bool known: false; property bool stateChanging: false
        property real signalStrength: .85; property int security: WifiSecurityType.Wpa2Psk
        property int secretLength: 0
        signal connectionFailed(int reason)
        function connect() {connected = true;}
        function disconnect() {connected = false;}
        function connectWithPsk(value) {secretLength = value.length; connected = true; known = true;}
    }
    QtObject {
        id: enterprise
        property string name: "QA enterprise network"
        property bool connected: false; property bool known: false; property bool stateChanging: false
        property real signalStrength: .50; property int security: WifiSecurityType.Wpa2Eap
        signal connectionFailed(int reason)
        function connect() {console.error("FAIL: enterprise network used a PSK flow"); Qt.exit(1);}
    }
    QtObject {id: wifiAdapter; property int type: DeviceType.Wifi; property bool scannerEnabled: false; property QtObject networks: QtObject {property var values: [enterprise, secured]}}
    QtObject {id: mockNetworkService; property bool wifiEnabled: true; property bool wifiHardwareEnabled: true; property QtObject devices: QtObject {property var values: [wifiAdapter]}}
    QtObject {
        id: savedDevice
        property string name: "QA saved headphones"; property bool paired: true; property bool connected: false; property bool blocked: false; property bool pairing: false; property bool trusted: false; property bool batteryAvailable: false
        property int forgetCalls: 0
        function connect() {connected = true;}
        function disconnect() {connected = false;}
        function forget() {forgetCalls++; paired = false;}
    }
    QtObject {
        id: nearby
        property string name: "QA pairing keyboard"; property string dbusPath: "/org/bluez/hci0/dev_00_11_22_33_44_55"
        property bool paired: false; property bool connected: false; property bool blocked: false; property bool pairing: false; property bool trusted: false; property bool batteryAvailable: false
    }
    QtObject {id: btAdapter; property bool enabled: true; property bool discovering: false; property QtObject devices: QtObject {property var values: [nearby, savedDevice]}}
    QtObject {id: mockBluetoothService; property QtObject adapters: QtObject {property var values: [btAdapter]}}
    FloatingWindow {
        id: window; title: "Connectivity test fixtures"; implicitWidth: 1000; implicitHeight: 720; color: "#101c2d"
        Loader {id: loader; anchors.fill: parent; anchors.margins: 24; sourceComponent: wifi}
    }
    Component {id: wifi; NetworkPage {controller: mockController; networkService: mockNetworkService}}
    Component {id: bluetooth; BluetoothPage {controller: mockController; bluetoothService: mockBluetoothService}}
    function check(value, message) {if (!value) {console.error("FAIL: " + message); Qt.exit(1); return false;} return true;}
    function find(root, predicate) {
        const queue = [root], seen = new Set();
        while (queue.length) {
            const item = queue.shift(); if (!item || seen.has(item)) continue; seen.add(item);
            if (predicate(item)) return item;
            for (let child of item.children || []) queue.push(child);
            for (let child of item.data || []) queue.push(child);
            if (item.contentItem) queue.push(item.contentItem);
        }
        return null;
    }
    function button(root, label) {return find(root, item => item.label === label && typeof item.clicked === "function");}
    Timer {interval: 25000; running: true; onTriggered: {console.error("FAIL: connectivity flow timed out at phase " + test.phase); Qt.exit(1);}}
    Timer {
        interval: 150; repeat: true; running: true
        onTriggered: {
            const page = loader.item;
            if (!page) return;
            if (test.phase === 0) {
                if (!test.check(wifiAdapter.scannerEnabled && page.scanning, "Wi-Fi discovery starts on the selected adapter")) return;
                if (!test.check(page.networks[0] === secured, "nearby networks sort by signal")) return;
                page.connectNetwork(secured); test.phase++; return;
            }
            if (test.phase === 1) {
                const field = test.find(window.contentItem, item => item.objectName === "wifiPassword");
                if (!test.check(!!field && field.activeFocus, "Wi-Fi password prompt receives keyboard focus")) return;
                field.text = "synthetic-qa-password";
                page.submitPassword();
                if (!test.check(secured.secretLength === 21 && field.text === "", "PSK submitted directly and input cleared")) return;
                page.connectNetwork(enterprise);
                if (!test.check(mockController.lastCommand.join(" ") === "forynarch-system connections", "enterprise setup uses the advanced editor")) return;
                mockNetworkService.wifiEnabled = false;
                if (!test.check(!wifiAdapter.scannerEnabled && !page.scanning, "radio-off stops discovery")) return;
                mockNetworkService.wifiEnabled = true;
                loader.sourceComponent = bluetooth; test.phase++; return;
            }
            if (test.phase === 2) {
                if (!test.check(!wifiAdapter.scannerEnabled && btAdapter.discovering, "page change stops Wi-Fi and starts Bluetooth discovery")) return;
                if (!test.check(page.devices[0] === savedDevice, "saved Bluetooth devices precede discoveries")) return;
                const row = test.find(page, item => item.heading === savedDevice.name);
                test.button(row, "Connect").clicked();
                if (!test.check(savedDevice.connected, "saved device connects directly")) return;
                test.button(row, "Options").clicked();
                test.phase = 21; return;
            }
            if (test.phase === 21) {
                const forget = test.button(window.contentItem, "Forget");
                if (!forget) return;
                forget.clicked(); test.phase = 3; return;
            }
            if (test.phase === 3) {
                if (!test.check(savedDevice.forgetCalls === 0, "forget requires confirmation")) return;
                const confirmation = test.find(window.contentItem, item => item.label === "Forget device");
                if (!test.check(!!confirmation, "forget confirmation is visible")) return;
                confirmation.clicked();
                if (!test.check(savedDevice.forgetCalls === 1 && !savedDevice.paired, "confirmed forget removes the saved pairing")) return;
                page.pair(nearby); test.phase++; return;
            }
            if (test.phase === 4) {
                if (page.pairingPhase !== "confirm") return;
                if (!test.check(page.pairingCode === "123456", "native pairing code is displayed")) return;
                const confirm = test.button(window.contentItem, "Confirm");
                if (!test.check(!!confirm, "pairing confirmation has a graphical action")) return;
                confirm.clicked(); test.phase++; return;
            }
            if (test.phase === 5) {
                if (page.message !== "Device paired and connected.") return;
                if (!test.check(page.pairingCode === "", "pairing code cleared after success")) return;
                page.startScan(); loader.active = false; test.phase++; return;
            }
        }
    }
    Timer {
        interval: 150; repeat: true; running: true
        onTriggered: if (test.phase === 6) {
            if (!test.check(!btAdapter.discovering && !wifiAdapter.scannerEnabled, "closing the page releases both scanners")) return;
            console.log("PASS: native connectivity discovery, sorting, password isolation, advanced routing, pair confirmation and scanner cleanup");
            Qt.exit(0);
        }
    }
}
