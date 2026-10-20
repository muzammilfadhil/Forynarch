import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

ColumnLayout {
    id: outputs
    required property var controller
    property bool input:false
    readonly property var devices: Pipewire.nodes.values.filter(node => node.audio && !node.isStream && node.isSink!==input)
    spacing: 6
    PwObjectTracker { objects: outputs.devices }
    Text { text: input?"Input device":"Output device"; color: "#dfe9f8"; font.pixelSize: 13 }
    Choice {
        Layout.fillWidth: true; implicitHeight: 40
        choices: outputs.devices.length ? outputs.devices.map(node => ({label:node.description || node.nickname || node.name,value:node.id})) : [{label:outputs.input?"No input connected":"No output connected",value:-1}]
        selectedValue: (outputs.input?Pipewire.defaultAudioSource:Pipewire.defaultAudioSink)?.id ?? -1
        enabled: outputs.devices.length > 0
        Accessible.name: outputs.input?"Default input device":"Default output device"
        onChosen: value => {
            const node = outputs.devices.find(node => node.id === value);
            if(node&&node.ready){if(outputs.input)Pipewire.preferredDefaultAudioSource=node;else Pipewire.preferredDefaultAudioSink=node;}
        }
    }
}
