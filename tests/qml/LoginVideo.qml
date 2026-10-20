import QtQuick
import Quickshell
import "."

FloatingWindow {
    implicitWidth: 640
    implicitHeight: 400
    property int previousPosition: -1
    property bool advanced: false
    property bool failedSource: false
    property int ticks: 0
    VideoBackground {
        id: video
        anchors.fill: parent
        mediaSource: Qt.resolvedUrl("kath.mp4")
        onFailed: {console.error("FAIL: supplied video did not play"); Qt.exit(1)}
    }
    VideoBackground {
        visible: false
        mediaSource: Qt.resolvedUrl("missing-video.mp4")
        onFailed: failedSource = true
    }
    Timer {
        interval: 250; repeat: true; running: true
        onTriggered: {
            ticks++;
            const player = video.data[0];
            const position = player.position;
            if (position > 500) advanced = true;
            if (advanced && position < previousPosition && failedSource) {
                console.log("PASS: supplied Kath MP4 advances, loops and reports missing-source failure");
                Qt.quit();
            }
            previousPosition = position;
            if (ticks > 140) {
                console.error("FAIL: video loop/error observation timed out");
                Qt.exit(1);
            }
        }
    }
}
