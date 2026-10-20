// Config created by Keyitdev https://github.com/Keyitdev/sddm-astronaut-theme
// Copyright (C) 2022-2025 Keyitdev
// Based on https://github.com/MarianArlt/sddm-sugar-dark
// Distributed under the GPLv3+ License https://www.gnu.org/licenses/gpl-3.0.html

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtQuick.Effects

import "Components"

Pane {
    id: root

    height: config.ScreenHeight || Screen.height
    width: config.ScreenWidth || Screen.width
    padding: config.ScreenPadding

    LayoutMirroring.enabled: config.RightToLeftLayout == "true" ? true : Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    palette.window: config.BackgroundColor
    palette.highlight: config.HighlightBackgroundColor
    palette.highlightedText: config.HighlightTextColor
    palette.buttonText: config.HoverSystemButtonsIconsColor

    font.family: config.Font
    font.pointSize: config.FontSize !== "" ? config.FontSize : parseInt(height / 80) || 13

    focus: true
    readonly property real fadeWidth: Math.max(72, Math.min(180, width * 0.09))
    readonly property bool reduceMotion: config.ReduceMotion === "true"
    readonly property bool preview: config.PreviewMode === "true"
    readonly property bool videoBackground: /\.(avi|mp4|mov|mkv|m4v|webm)$/i.test(config.Background)
    readonly property bool playingBackground: videoBackground && !reduceMotion && config.PauseBackground !== "true"
    Label {
        visible: root.preview; z: 100
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; anchors.topMargin: 12
        padding: 10; text: "Theme preview · sign-in and power actions are disabled"
        color: "#dceaff"; font.pixelSize: 12
        background: Rectangle {radius: 8; color: "#e614263b"; border.color: "#6483a3"}
    }

    property bool leftleft: config.HaveFormBackground == "true" &&
                            config.PartialBlur == "false" &&
                            config.FormPosition == "left" &&
                            config.BackgroundHorizontalAlignment == "left"

    property bool leftcenter: config.HaveFormBackground == "true" &&
                              config.PartialBlur == "false" &&
                              config.FormPosition == "left" &&
                              config.BackgroundHorizontalAlignment == "center"

    property bool rightright: config.HaveFormBackground == "true" &&
                              config.PartialBlur == "false" &&
                              config.FormPosition == "right" &&
                              config.BackgroundHorizontalAlignment == "right"

    property bool rightcenter: config.HaveFormBackground == "true" &&
                               config.PartialBlur == "false" &&
                               config.FormPosition == "right" &&
                               config.BackgroundHorizontalAlignment == "center"

    Item {
        id: sizeHelper

        height: parent.height
        width: parent.width
        anchors.fill: parent

        Rectangle {
            id: tintLayer

            height: parent.height
            width: parent.width
            anchors.fill: parent
            z: 1
            color: config.DimBackgroundColor
            opacity: config.DimBackground
        }

        Rectangle {
            id: formBackground

            height: parent.height
            width: Math.min(parent.width, form.width + root.fadeWidth)
            anchors.left: config.FormPosition === "left" ? parent.left : undefined
            anchors.right: config.FormPosition === "right" ? parent.right : undefined
            anchors.horizontalCenter: config.FormPosition === "center" ? parent.horizontalCenter : undefined
            z: 1

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {position: 0; color: config.FormPosition === "right" ? "transparent" : config.FormBackgroundColor}
                GradientStop {position: config.FormPosition === "right" ? 0.28 : 0.72; color: config.FormBackgroundColor}
                GradientStop {position: 1; color: config.FormPosition === "right" ? config.FormBackgroundColor : "transparent"}
            }
            visible: config.HaveFormBackground == "true" ? true : false
            opacity: config.PartialBlur == "true" ? 0.86 : 1
        }

        LoginForm {
            id: form
            enabled: !root.preview

            height: Math.min(parent.height - 48, implicitHeight)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(520, Math.max(360, parent.width * 0.4))
            anchors.left: config.FormPosition == "left" ? parent.left : undefined
            anchors.horizontalCenter: config.FormPosition == "center" ? parent.horizontalCenter : undefined
            anchors.right: config.FormPosition == "right" ? parent.right : undefined
            z: 1
            NumberAnimation on opacity {from: root.reduceMotion ? 1 : 0; to: 1; duration: root.reduceMotion ? 0 : 380; easing.type: Easing.OutCubic; running: true}
        transform: Translate {
            id: formArrival
            NumberAnimation on x {from: root.reduceMotion ? 0 : -16; to: 0; duration: root.reduceMotion ? 0 : 440; easing.type: Easing.OutCubic; running: true}
        }
        }

        Loader {
            id: virtualKeyboard
            source: config.HideVirtualKeyboard === "true" ? "" : "Components/VirtualKeyboard.qml"

            // x * 0.4 = x / 2.5
            width: config.KeyboardSize == "" ? parent.width * 0.4 : parent.width * config.KeyboardSize
            anchors.bottom: parent.bottom
            anchors.left: config.VirtualKeyboardPosition == "left" ? parent.left : undefined;
            anchors.horizontalCenter: config.VirtualKeyboardPosition == "center" ? parent.horizontalCenter : undefined;
            anchors.right: config.VirtualKeyboardPosition == "right" ? parent.right : undefined;
            z: 1

            state: "hidden"
            property bool keyboardActive: item ? item.active : false

            function switchState() { state = state == "hidden" ? "visible" : "hidden"}
            states: [
                State {
                    name: "visible"
                    PropertyChanges {
                        target: virtualKeyboard
                        y: root.height - virtualKeyboard.height
                        opacity: 1
                    }
                },
                State {
                    name: "hidden"
                    PropertyChanges {
                        target: virtualKeyboard
                        y: root.height - root.height/4
                        opacity: 0
                    }
                }
            ]
            transitions: [
                Transition {
                    from: "hidden"
                    to: "visible"
                    SequentialAnimation {
                        ScriptAction {
                            script: {
                                virtualKeyboard.item.activated = true;
                                Qt.inputMethod.show();
                            }
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: virtualKeyboard
                                property: "y"
                                duration: 100
                                easing.type: Easing.OutQuad
                            }
                            OpacityAnimator {
                                target: virtualKeyboard
                                duration: 100
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                },
                Transition {
                    from: "visible"
                    to: "hidden"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation {
                                target: virtualKeyboard
                                property: "y"
                                duration: 100
                                easing.type: Easing.InQuad
                            }
                            OpacityAnimator {
                                target: virtualKeyboard
                                duration: 100
                                easing.type: Easing.InQuad
                            }
                        }
                        ScriptAction {
                            script: {
                                virtualKeyboard.item.activated = false;
                                Qt.inputMethod.hide();
                            }
                        }
                    }
                }
            ]
        }

        Image {
            id: backgroundPlaceholderImage

            z: 0
            source: config.BackgroundPlaceholder
            visible: false
            anchors.fill: backgroundImage
            fillMode: config.CropBackground === "true" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            sourceSize: Qt.size(Math.min(width, 1920), Math.min(height, 1080))
            onStatusChanged: if (status === Image.Ready) blurMask.scheduleUpdate()
        }

        AnimatedImage {
            id: backgroundImage

            Loader {
                anchors.fill: parent
                active: root.playingBackground
                source: active ? "Components/VideoBackground.qml" : ""
                onLoaded: {
                    item.mediaSource = Qt.resolvedUrl(config.Background);
                    item.crop = config.CropBackground === "true";
                    item.rate = Number(config.BackgroundSpeed || 1);
                    item.started.connect(function() {backgroundPlaceholderImage.visible = false;});
                    item.failed.connect(function() {backgroundPlaceholderImage.visible = true;});
                }
                onStatusChanged: if (status === Loader.Error) backgroundPlaceholderImage.visible = true
            }

            height: parent.height
            width: config.HaveFormBackground == "true" && config.FormPosition != "center" && config.PartialBlur != "true" ? parent.width - formBackground.width : parent.width
            anchors.left: leftleft || leftcenter ? formBackground.right : undefined
            anchors.right: rightright || rightcenter ? formBackground.left : undefined

            horizontalAlignment: config.BackgroundHorizontalAlignment == "left" ?
                                 Image.AlignLeft :
                                 config.BackgroundHorizontalAlignment == "right" ?
                                 Image.AlignRight : Image.AlignHCenter

            verticalAlignment: config.BackgroundVerticalAlignment == "top" ?
                               Image.AlignTop :
                               config.BackgroundVerticalAlignment == "bottom" ?
                               Image.AlignBottom : Image.AlignVCenter

            speed: config.BackgroundSpeed == "" ? 1.0 : config.BackgroundSpeed
            paused: root.reduceMotion || config.PauseBackground === "true"
            fillMode: config.CropBackground == "true" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: true
            cache: true
            clip: true
            mipmap: false
            sourceSize: Qt.size(Math.min(width, 1920), Math.min(height, 1080))
            onStatusChanged: if (status === Image.Ready) blurMask.scheduleUpdate()

            Component.onCompleted:{
                var fileType = config.Background.substring(config.Background.lastIndexOf(".") + 1)
                const videoFileTypes = ["avi", "mp4", "mov", "mkv", "m4v", "webm"];
                if (videoFileTypes.includes(fileType)) {
                    backgroundPlaceholderImage.visible = true;
                }
                else{
                    backgroundImage.source = config.background || config.Background
                }
            }
        }

        MouseArea {
            anchors.fill: backgroundImage
            onClicked: parent.forceActiveFocus()
        }

        ShaderEffectSource {
            id: blurMask

            height: parent.height
            width: Math.min(parent.width, form.width + root.fadeWidth)
            anchors.left: config.FormPosition === "left" ? parent.left : undefined
            anchors.right: config.FormPosition === "right" ? parent.right : undefined
            anchors.horizontalCenter: config.FormPosition === "center" ? parent.horizontalCenter : undefined

            sourceItem: root.videoBackground && !root.playingBackground ? backgroundPlaceholderImage : backgroundImage
            sourceRect: Qt.rect(x,y,width,height)
            textureSize: Qt.size(Math.ceil(width/2), Math.ceil(height/2))
            live: root.playingBackground
            visible: config.FullBlur == "true" || config.PartialBlur == "true" ? true : false
        }

        MultiEffect {
            id: blur

            height: parent.height

            // width: config.FullBlur == "true" ? parent.width : form.width
            // anchors.centerIn: config.FullBlur == "true" ? parent : form

            // This solves problem when FullBlur and HaveFormBackground is set to true but PartialBlur is false and FormPosition isn't center.
            width: config.FullBlur == "true" ? parent.width : blurMask.width
            x: config.FullBlur == "true" ? 0 : blurMask.x

            source: config.FullBlur == "true" ? backgroundImage : blurMask
            blurEnabled: true
            layer.enabled: !root.playingBackground
            layer.textureSize: Qt.size(Math.ceil(width/2), Math.ceil(height/2))
            autoPaddingEnabled: false
            blur: Math.min(1, Number(config.Blur || 0.7))
            blurMax: Math.min(16, Number(config.BlurMax || 16))
            maskEnabled: config.FullBlur !== "true"
            maskSource: blendMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            visible: config.FullBlur == "true" || config.PartialBlur == "true" ? true : false
        }
        BlendMask {id: blendMask; width: blur.width; height: blur.height; reversed: config.FormPosition === "right"}
    }
}
