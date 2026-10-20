// MacShell's Liquid Glass shader, adapted for a bounded, one-frame screen capture.
import QtQuick
Item {
    id: surface
    required property var backdrop
    property rect sampleRect:Qt.rect(x,y,width,height)
    property bool enabledEffect:true
    property real cornerRadius:24
    property real frost:4
    property real opticalThickness:22
    property real refractionStrength:1
    property real shadowStrength:0.45
    property bool failed:false
readonly property bool backendSupported:GraphicsInfo.api!==GraphicsInfo.Software
readonly property bool available:enabledEffect&&backendSupported&&!failed&&(backdrop?.hasContent??false)
    Loader {
        anchors.fill:parent;active:surface.available
        sourceComponent:Item {
            ShaderEffectSource {
                id:sample
                sourceItem:surface.backdrop
                sourceRect:Qt.rect(surface.sampleRect.x-10,surface.sampleRect.y-10,surface.width+20,surface.height+20)
                textureSize:Qt.size(Math.max(1,Math.ceil(sourceRect.width/2)),Math.max(1,Math.ceil(sourceRect.height/2)))
                live:true;mipmap:true;visible:false
            }
            ShaderEffect {
                x:-10;y:-10;width:parent.width+20;height:parent.height+20
                fragmentShader:Qt.resolvedUrl("shaders/liquid.frag.qsb")
                onStatusChanged:if(status===ShaderEffect.Error)surface.failed=true
                property variant src:sample
                property vector2d itemSize:Qt.vector2d(width,height)
                property vector2d glassSize:Qt.vector2d(surface.width,surface.height)
                property vector2d srcSize:Qt.vector2d(sample.sourceRect.width,sample.sourceRect.height)
                property vector2d srcOffset:Qt.vector2d(0,0)
                property real pad:10
                property real radius:surface.cornerRadius
                property real bezel:22
                property real thickness:surface.opticalThickness*surface.refractionStrength
                property real dispersion:0.025
                property real blurPx:surface.frost+2
                property real tintMix:0.80
                property real saturation:1
                property real dark:1
                property real debug:0
                property real rim:0.45
                property real grain:0.015
                property real magnify:0.025
                property real shadowAmt:surface.shadowStrength
            }
        }
    }
}
