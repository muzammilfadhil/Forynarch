import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id: page
    required property var controller
    property var rows: []
    property string error: ""
    spacing: 12
    Component.onCompleted: read.running = true
    function select(category, application) {
        if (save.running) return;
        error = "";
        save.command = ["forynarch-default-apps", "set", category, application];
        save.running = true;
    }
    Process {
        id: read
        command: ["forynarch-default-apps", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const state = JSON.parse(text); page.rows = state.rows; page.controller.defaultTerminal = state.terminal; }
                catch (e) { page.error = "Default applications could not be read."; }
            }
        }
    }
    Process {
        id: save
        stderr: StdioCollector { onStreamFinished: page.error = text.trim() }
        onExited: (code, status) => {
            if (code !== 0 && !page.error) page.error = "The default application could not be saved.";
            read.running = true;
        }
    }
    Text {
        Layout.fillWidth: true
        text: "Choose which installed apps open your links, files and terminal sessions."
        color: "#a8bad2"; font.pixelSize: 13; wrapMode: Text.WordWrap
    }
    Repeater {
        model: page.rows
        SettingRow {
            required property var modelData
            Layout.fillWidth: true
            title: modelData.name
            description: modelData.key === "terminal" ? "Used by search, shortcuts and terminal applications" :
                modelData.choices.length ? "Open by default" : "Install an app to choose a default"
            Choice {
                implicitHeight: 40
                enabled: !save.running && modelData.choices.length > 0
                choices: (modelData.choices.some(app => app.id === modelData.selected) ? [] :
                    [{label: modelData.choices.length ? "Choose an app" : "No compatible app installed", value: ""}])
                    .concat(modelData.choices.map(app => ({label: app.name, value: app.id})))
                selectedValue: modelData.selected
                onChosen: value => { if (value) page.select(modelData.key, value); }
            }
        }
    }
    Text { Layout.fillWidth: true; visible: page.error !== ""; text: page.error; color: "#ffc2af"; wrapMode: Text.WordWrap }
    ActionButton { label: "Refresh installed apps"; enabled: !read.running && !save.running; onClicked: read.running = true }
}
