import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

ColumnLayout {
    id:details
    required property var center
    readonly property var controller:center.controller
    readonly property var outputs:Pipewire.nodes.values.filter(node=>node.audio&&!node.isStream&&node.isSink)
    readonly property var inputs:Pipewire.nodes.values.filter(node=>node.audio&&!node.isStream&&!node.isSink)
    readonly property var streams:Pipewire.nodes.values.filter(node=>node.audio&&node.isStream&&node.isSink)
    readonly property var applications:{
        const groups=[];
        for(const node of streams){
            if(!node.ready)continue;
            const properties=node.properties||{};
            const key=properties["application.id"]||properties["application.process.binary"]||properties["application.name"]||String(node.id);
            let group=groups.find(group=>group.key===key);
            if(!group){group={key:key,name:properties["application.name"]||node.description||node.name,icon:properties["application.icon-name"]||"",streams:[]};groups.push(group);}
            group.streams.push(node);
        }
        return groups;
    }
    spacing:12
    PwObjectTracker{objects:details.outputs.concat(details.inputs,details.streams)}
    RowLayout{
        Layout.fillWidth:true;spacing:8
        MacControlButton{center:details.center;diameter:28;compact:true;glyph:"chevL";label:"Back to Control Center";onClicked:details.center.closeAudio()}
        Text{Layout.fillWidth:true;text:"Sound";font.pixelSize:15;font.weight:Font.DemiBold;color:"#f5f5f7"}
    }
    Repeater{
        model:[{title:"Output",nodes:details.outputs,input:false},{title:"Input",nodes:details.inputs,input:true}]
        ColumnLayout{
            id:section;required property var modelData
            readonly property var current:modelData.input?Pipewire.defaultAudioSource:Pipewire.defaultAudioSink
            Layout.fillWidth:true;spacing:6
            Text{text:section.modelData.title;color:"#f5f5f7";font.pixelSize:13;font.weight:Font.DemiBold}
            Text{visible:section.modelData.nodes.length===0;text:"No "+section.modelData.title.toLowerCase()+" devices";font.pixelSize:12;color:"#c5c5c9"}
            Repeater{
                model:section.modelData.nodes
                AbstractButton{
                    id:device;required property var modelData
                    readonly property bool selected:section.current===modelData
                    Layout.fillWidth:true;implicitHeight:46;enabled:modelData.ready
                    Accessible.name:(modelData.description||modelData.nickname||modelData.name)+(selected?", default":"")
                    Accessible.checkable:true;Accessible.checked:selected
                    background:Rectangle{radius:14;color:device.hovered?"#24ffffff":"transparent";border.width:device.activeFocus?2:0;border.color:"#f5f5f7"}
                    contentItem:RowLayout{
                        spacing:10
                        Rectangle{
                            Layout.preferredWidth:30;Layout.preferredHeight:30;radius:15;color:device.selected?"#0a84ff":"#3a3a3f"
                            MacControlGlyph{anchors.centerIn:parent;width:16;height:16;kind:section.modelData.input?"mic":"speaker";color:"#f5f5f7"}
                        }
                        Text{Layout.fillWidth:true;text:device.modelData.description||device.modelData.nickname||device.modelData.name;textFormat:Text.PlainText;color:"#f5f5f7";font.pixelSize:13;elide:Text.ElideRight}
                        MacControlGlyph{visible:device.selected;Layout.preferredWidth:14;Layout.preferredHeight:14;kind:"check";color:"#f5f5f7"}
                    }
                    onClicked:{if(section.modelData.input)Pipewire.preferredDefaultAudioSource=modelData;else Pipewire.preferredDefaultAudioSink=modelData;}
                }
            }
            RowLayout{
                Layout.fillWidth:true;visible:section.current?.audio!==null&&section.current?.audio!==undefined
                MacControlSlider{
                    Layout.fillWidth:true;glyph:section.modelData.input?"mic":"speaker";label:section.modelData.title+" volume";value:section.current?.audio?.volume??0
                    onMoved:if(section.current?.audio)section.current.audio.volume=value
                }
                MacControlButton{center:details.center;diameter:28;compact:true;glyph:section.modelData.input?"mic":"speaker";label:section.modelData.input?"Mute microphone":"Mute output";checked:section.current?.audio?.muted??false;onClicked:if(section.current?.audio)section.current.audio.muted=!section.current.audio.muted}
            }
        }
    }
    Rectangle{Layout.fillWidth:true;implicitHeight:1;color:"#5085858d"}
    Text{text:"Applications";color:"#f5f5f7";font.pixelSize:13;font.weight:Font.DemiBold}
    Text{visible:details.applications.length===0;Layout.fillWidth:true;text:"Apps appear here while they have an audio stream.";color:"#c5c5c9";font.pixelSize:12;wrapMode:Text.WordWrap}
    Repeater{
        model:details.applications
        ColumnLayout{
            id:app;required property var modelData
            readonly property real volume:modelData.streams.reduce((total,node)=>total+node.audio.volume,0)/modelData.streams.length
            readonly property bool muted:modelData.streams.every(node=>node.audio.muted)
            Layout.fillWidth:true;spacing:4
            RowLayout{
                Layout.fillWidth:true;spacing:8
                Image{visible:app.modelData.icon!=="";source:Quickshell.iconPath(app.modelData.icon,true);sourceSize:Qt.size(24,24);Layout.preferredWidth:22;Layout.preferredHeight:22}
                Text{Layout.fillWidth:true;text:app.modelData.name;textFormat:Text.PlainText;elide:Text.ElideRight;color:"#f5f5f7";font.pixelSize:13}
                MacControlButton{center:details.center;diameter:28;compact:true;glyph:"speaker";label:app.muted?"Unmute "+app.modelData.name:"Mute "+app.modelData.name;checked:app.muted;onClicked:{const mute=!app.muted;for(const node of app.modelData.streams)if(node.ready)node.audio.muted=mute;}}
            }
            MacControlSlider{Layout.fillWidth:true;glyph:"speaker";label:app.modelData.name+" volume";value:app.volume;onMoved:{for(const node of app.modelData.streams)if(node.ready)node.audio.volume=value;}}
            AudioAppRoutes{Layout.fillWidth:true;controller:details.controller;applicationKey:app.modelData.key}
        }
    }
    AudioAppRoutes{Layout.fillWidth:true;controller:details.controller;excludeKeys:details.applications.map(app=>app.key)}
    Text{Layout.fillWidth:true;text:"Choose System default, let the app manage its devices, or select an input and output here.";color:"#c5c5c9";font.pixelSize:11;wrapMode:Text.WordWrap}
}
