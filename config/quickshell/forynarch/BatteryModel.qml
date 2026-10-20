import QtQuick
import Quickshell.Io

Item {
    id: model
    required property var controller
    visible: false
    readonly property bool expanded: controller.batteryOpen || (controller.settingsOpen && controller.settingsPage === "Power")
    readonly property bool needed: expanded || controller.panelShowBattery
    property var snapshot: ({batteries:[], adapters:[], capacity:null, externalPower:false, charging:false})
    property string error: ""
    property date updated: new Date(0)
    function refresh() { if (!reader.running) reader.running = true; }
    onNeededChanged: if (needed) refresh()
    onExpandedChanged: if (expanded) refresh()
    Component.onCompleted: if (needed) refresh()
    Timer { interval: model.expanded ? 3000 : 30000; running: model.needed; repeat: true; onTriggered: model.refresh() }
    Process {
        id: reader
        command: ["forynarch-battery"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (!Array.isArray(data.batteries) || !Array.isArray(data.adapters)) throw new Error("Invalid battery data");
                    model.snapshot = data;
                    model.updated = new Date();
                    model.error = "";
                } catch (error) { model.error = "Battery information is unavailable. Retrying automatically."; }
            }
        }
        onExited: (code, status) => { if (code !== 0 || status !== 0) model.error = "Battery information is unavailable. Retrying automatically."; }
    }
}
