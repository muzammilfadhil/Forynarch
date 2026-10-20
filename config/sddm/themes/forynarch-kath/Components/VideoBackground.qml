import QtQuick
import QtMultimedia
Item {
    property url mediaSource
    property bool crop: true
    property real rate: 1
    signal started()
    signal failed()
    MediaPlayer {
        id: player
        source: mediaSource; autoPlay: true; loops: MediaPlayer.Infinite
        playbackRate: rate; videoOutput: output
        onPlayingChanged: if (player.playing) started()
        onErrorOccurred: failed()
    }
    VideoOutput {id: output; anchors.fill: parent; fillMode: crop ? VideoOutput.PreserveAspectCrop : VideoOutput.PreserveAspectFit}
}
