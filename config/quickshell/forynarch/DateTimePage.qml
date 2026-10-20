import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id: page
    required property var controller
    property var clockState: ({timezone:"UTC", ntp:false, synced:false, canNtp:false})
    property var zones: []
    property string selectedZone: ""
    property string error: ""
    property date currentTime: new Date()
    spacing: 12
    Component.onCompleted: { read.running = true; zoneList.running = true; }
    function apply(action, value) {
        if (operation.running) return;
        error = ""; operation.command = ["forynarch-date-time", action, value]; operation.running = true;
    }
    Process {
        id: read; command: ["forynarch-date-time", "status"]
        stdout: StdioCollector { onStreamFinished: { try { page.clockState = JSON.parse(text); if (!page.selectedZone) page.selectedZone = page.clockState.timezone; } catch(e) { page.error = "Date and time information could not be read."; } } }
        stderr: StdioCollector { onStreamFinished: { if (text.trim()) page.error = text.trim(); } }
    }
    Process {
        id: zoneList; command: ["forynarch-date-time", "zones"]
        stdout: StdioCollector { onStreamFinished: { try { page.zones = JSON.parse(text); } catch(e) { page.error = "Timezones could not be loaded."; } } }
    }
    Process {
        id: operation
        stderr: StdioCollector { onStreamFinished: page.error = text.trim() }
        onExited: (code, status) => { if (code !== 0 && !page.error) page.error = "The time change was not applied."; read.running = true; }
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: page.currentTime = new Date() }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: { if (!read.running && !operation.running) read.running = true; } }
    Text { Layout.fillWidth: true; text: Qt.formatDateTime(page.currentTime, "dddd, dd MMMM yyyy"); color: "#dfe9f8"; font.pixelSize: 20; wrapMode: Text.WordWrap }
    Text { text: Qt.formatDateTime(page.currentTime, controller.clock12 ? "h:mm:ss AP" : "HH:mm:ss"); color: controller.accent; font.pixelSize: 30; font.weight: Font.Light }
    SettingRow {
        Layout.fillWidth: true; title: "Automatic date and time"
        description: page.clockState.ntp ? (page.clockState.synced ? "Synchronized with network time" : "Waiting for network time") : "Clock is set manually"
        Toggle { checked: page.clockState.ntp; enabled: page.clockState.canNtp && !operation.running; accent: controller.accent; Accessible.name: "Automatic network time"; onClicked: page.apply("ntp", checked ? "on" : "off") }
    }
    SettingRow {
        Layout.fillWidth: true; title: "Time format"; description: "Applies to the panel clock"
        Choice { choices: [{label:"24-hour",value:false},{label:"12-hour",value:true}]; selectedValue: controller.clock12; onChosen: value => controller.setClock12(value) }
    }
    Text { text: "Timezone"; color: "#dfe9f8"; font.pixelSize: 15; font.weight: Font.DemiBold }
    Text { Layout.fillWidth: true; text: "Current: " + page.clockState.timezone + ". Interface language stays English."; color: "#91a8c3"; font.pixelSize: 12; wrapMode: Text.WordWrap }
    TextField {
        id: zoneSearch; Layout.fillWidth: true; implicitHeight: 40; placeholderText: "Search city or timezone"; color: "#dceaff"; placeholderTextColor: "#91a8c3"
        background: Rectangle { radius: 10; color: "#203249"; border.width: 1; border.color: "#38506c" }
    }
    RowLayout {
        Layout.fillWidth: true
        Choice {
            Layout.fillWidth: true; implicitHeight: 40
            choices: page.zones.filter(zone => zone.toLowerCase().includes(zoneSearch.text.toLowerCase())).map(zone => ({label:zone.replace(/_/g," "),value:zone}))
            selectedValue: page.selectedZone
            enabled: !operation.running; Accessible.name: "Timezone"
            onChosen: value => page.selectedZone = value
        }
        ActionButton { label: "Apply timezone"; enabled: !operation.running && page.selectedZone !== page.clockState.timezone && page.zones.includes(page.selectedZone); onClicked: page.apply("timezone", page.selectedZone) }
    }
    Text { text: "Manual date and time"; color: "#dfe9f8"; font.pixelSize: 15; font.weight: Font.DemiBold }
    RowLayout {
        Layout.fillWidth: true
        TextField {
            id: manualTime; Layout.fillWidth: true; implicitHeight: 40; placeholderText: "YYYY-MM-DD HH:MM:SS"; color: "#dceaff"; placeholderTextColor: "#91a8c3"; enabled: !page.clockState.ntp && !operation.running
            background: Rectangle { radius: 10; color: "#203249"; border.width: 1; border.color: "#38506c" }
        }
        ActionButton { label: "Set time"; enabled: !page.clockState.ntp && !operation.running && manualTime.text.trim().length >= 16; onClicked: page.apply("time", manualTime.text.trim()) }
    }
    Text { Layout.fillWidth: true; text: "Turn automatic time off to set the clock manually. System authentication may be required."; color: "#91a8c3"; font.pixelSize: 12; wrapMode: Text.WordWrap }
    Text { Layout.fillWidth: true; visible: page.error !== ""; text: page.error; color: "#ffc2af"; wrapMode: Text.WordWrap }
}
