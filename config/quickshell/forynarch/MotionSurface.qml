import QtQuick

Item {
    id: surface
    required property var controller
    property bool shown: true
    property real progress: 0
    readonly property bool animating: transition.running
    readonly property bool blurActive: body.layer.enabled
    default property alias content: body.data
    scale:0.97+0.03*progress
    opacity:progress
    transform:Translate {y:(1-surface.progress)*16}
    function animate() {
        if (!controller.motion) {transition.stop();progress=shown ? 1 : 0;return;}
        transition.to=shown ? 1 : 0;
        transition.duration=shown ? 180 : 150;
        transition.restart();
    }
    onShownChanged:animate()
    Component.onCompleted:animate()
    data: [
        Connections {target:surface.controller;function onMotionChanged(){surface.animate();}},
        Item {
            id:body;anchors.fill:parent
            layer.enabled:surface.animating && surface.controller.motionBlur
            layer.samplerName:"source"
            layer.effect:ShaderEffect {
                property var source
                property vector2d extent:Qt.vector2d(width,height)
                property real smear:(1-surface.progress)*1.4
                fragmentShader:Qt.resolvedUrl("shaders/motion.frag.qsb")
            }
        },
        NumberAnimation {id:transition;target:surface;property:"progress";easing.type:Easing.OutCubic}
    ]
}
