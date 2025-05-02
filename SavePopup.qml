import QtQuick.Controls.Universal
import QtQuick
import "."

    AnimatedPopup {
        id: savePopup
        parent: playlistView
        anchors.centerIn: parent
        width: saveLabel.width + 40
        height: saveLabel.height + 30

        Label {
            id: saveLabel
            font.pixelSize: 14
            anchors.centerIn: parent
            text: "Playlist saved successfully"
        }

        Timer {
            id: hideTimer
            interval: 2500
            onTriggered: savePopup.close()
        }

        onOpened: hideTimer.start()
    }

    