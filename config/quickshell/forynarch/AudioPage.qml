import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

ColumnLayout {
    id:page
    required property var controller
    readonly property var devices:Pipewire.nodes.values.filter(n=>!!n.audio&&!n.isStream)
    readonly property var outputs:devices.filter(n=>n.isSink)
    readonly property var inputs:devices.filter(n=>!n.isSink)
    spacing:12
    PwObjectTracker {objects:page.devices}

    function isDefault(node) {
        return node===(node.isSink?Pipewire.defaultAudioSink:Pipewire.defaultAudioSource);
    }
    function chooseDefault(node) {
        if(!node||!node.ready||!page.devices.includes(node))return;
        if(node.isSink)Pipewire.preferredDefaultAudioSink=node;
        else Pipewire.preferredDefaultAudioSource=node;
    }

    Repeater {
        model:[{title:"Output devices",detail:"Speakers, headphones and other playback devices",output:true},
               {title:"Input devices",detail:"Microphones and other recording devices",output:false}]
        ColumnLayout {
            id:section
            required property var modelData
            readonly property var nodes:modelData.output?page.outputs:page.inputs
            Layout.fillWidth:true;spacing:10
            RowLayout {
                Layout.fillWidth:true;Layout.topMargin:4;spacing:10
                Text {text:section.modelData.title;color:"#dfe9f8";font.pixelSize:15;font.weight:Font.DemiBold}
                Text {text:section.nodes.length;color:"#91a8c3";font.pixelSize:12}
                Item {Layout.fillWidth:true}
            }
            Text {Layout.fillWidth:true;text:section.modelData.detail;color:"#91a8c3";font.pixelSize:12;wrapMode:Text.WordWrap}
            Text {Layout.fillWidth:true;visible:section.nodes.length===0;text:Pipewire.ready?(section.modelData.output?"No output devices detected":"No input devices detected"):"Connecting to audio service…";color:"#91a8c3";font.pixelSize:12}
            Repeater {
                model:section.nodes
                Rectangle {
                    id:device
                    required property var modelData
                    readonly property bool currentDefault:page.isDefault(modelData)
                    Layout.fillWidth:true;implicitHeight:118;radius:14
                    color:currentDefault?"#202f43":"#192230"
                    border.width:currentDefault?1:0;border.color:"#3a5676"
                    ColumnLayout {
                        anchors.fill:parent;anchors.margins:16;spacing:8
                        RowLayout {
                            Layout.fillWidth:true;spacing:12
                            ColumnLayout {
                                Layout.fillWidth:true;spacing:4
                                Text {Layout.fillWidth:true;text:device.modelData.description||device.modelData.nickname||device.modelData.name;textFormat:Text.PlainText;elide:Text.ElideRight;color:"#e1edff";font.pixelSize:14}
                                Text {text:device.currentDefault?(section.modelData.output?"Default output":"Default input"):"Available";color:device.currentDefault?controller.accent:"#91a8c3";font.pixelSize:11}
                            }
                            ActionButton {animateHover:controller.motion;label:"Set default";visible:!device.currentDefault;enabled:device.modelData.ready;onClicked:page.chooseDefault(device.modelData)}
                            Icon {visible:device.currentDefault;name:"check";ink:controller.accent;size:18}
                        }
                        RowLayout {
                            Layout.fillWidth:true;spacing:12
                            Text {Layout.preferredWidth:70;text:Math.round((device.modelData.audio?.volume||0)*100)+"%";color:"#b5cbe4";font.pixelSize:12}
                            ThemedSlider {Layout.fillWidth:true;from:0;to:1;value:device.modelData.audio?.volume||0;enabled:device.modelData.ready;accent:controller.accent;Accessible.name:(section.modelData.output?"Output volume: ":"Input volume: ")+(device.modelData.description||device.modelData.name);onMoved:device.modelData.audio.volume=value}
                            Text {text:"Mute";color:"#a3bad4";font.pixelSize:11}
                            Toggle {checked:device.modelData.audio?.muted||false;enabled:device.modelData.ready;accent:controller.accent;Accessible.name:"Mute "+(device.modelData.description||device.modelData.name);onClicked:device.modelData.audio.muted=checked}
                        }
                    }
                }
            }
            Item {Layout.preferredHeight:6}
        }
    }
    AudioHardware {Layout.fillWidth:true;controller:page.controller}
    AudioMixer {Layout.fillWidth:true;controller:page.controller}
}
