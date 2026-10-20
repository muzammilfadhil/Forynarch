import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

ColumnLayout {
    id: mixer
    required property var controller
    readonly property var streams: Pipewire.nodes.values.filter(node => node.audio && node.isStream && node.isSink)
    readonly property var applications: {
        const groups = [];
        streams.forEach(node => {
            if (!node.ready) return;
            const props = node.properties || {};
            const key = props["application.id"] || props["application.process.binary"] || props["application.name"] || String(node.id);
            let group = groups.find(item => item.key === key);
            if (!group) {
                group = {key:key, name:props["application.name"] || node.description || node.name,
                         icon:props["application.icon-name"] || "multimedia-volume-control", streams:[]};
                groups.push(group);
            }
            group.streams.push(node);
        });
        return groups;
    }
    spacing: 10
    PwObjectTracker { objects: mixer.streams }
    Text { text: "Volume mixer"; color: "#e1edff"; font.pixelSize: 15; font.weight: Font.DemiBold }
    Text { Layout.fillWidth: true; text: "App volume changes keep each app’s selected output."; color: "#91a8c3"; font.pixelSize: 12; wrapMode: Text.WordWrap }
    Text { Layout.fillWidth: true; visible: mixer.applications.length === 0; text: "Apps appear here while they have an audio stream."; color: "#91a8c3"; font.pixelSize: 12; wrapMode: Text.WordWrap }
    Repeater {
        model: mixer.applications
        ColumnLayout {
            id: app
            required property var modelData
            readonly property real volume: modelData.streams.reduce((total, node) => total + node.audio.volume, 0) / modelData.streams.length
            readonly property bool muted: modelData.streams.every(node => node.audio.muted)
            Layout.fillWidth: true; spacing: 6
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Image { Layout.preferredWidth: 22; Layout.preferredHeight: 22; source: Quickshell.iconPath(app.modelData.icon, true); sourceSize: Qt.size(24,24) }
                Text { Layout.fillWidth: true; text: app.modelData.name; textFormat: Text.PlainText; color: "#dfe9f8"; font.pixelSize: 13; elide: Text.ElideRight }
                Text { text: Math.round(app.volume * 100) + "%"; color: controller.accent; font.pixelSize: 12 }
                ActionButton {
                    icon: app.muted ? "mute" : "volume"; implicitWidth: 34; implicitHeight: 32
                    hint: app.muted ? "Unmute app" : "Mute app"
                    onClicked: { const muted = !app.muted; app.modelData.streams.forEach(node => { if (node.ready) node.audio.muted = muted; }); }
                }
            }
            ThemedSlider {
                Layout.fillWidth: true; from: 0; to: 1; value: app.volume; accent: controller.accent
                Accessible.name: app.modelData.name + " volume"
                onMoved: { const volume = value; app.modelData.streams.forEach(node => { if (node.ready) node.audio.volume = volume; }); }
            }
            AudioAppRoutes {Layout.fillWidth:true;controller:mixer.controller;applicationKey:app.modelData.key}
        }
    }
    AudioAppRoutes {Layout.fillWidth:true;controller:mixer.controller;excludeKeys:mixer.applications.map(app=>app.key)}
}
