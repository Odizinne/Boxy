import QtQuick.Controls.Universal
import QtQuick
import "."

    AnimatedPopup {
        id: savePopup
        width: saveLabel.width + 40
        height: saveLabel.height + 30

        Label {
            id: saveLabel
            font.pixelSize: 14
            anchors.centerIn: parent
            text: "Downloading any non cached files"
        }

        Timer {
            id: hideTimer
            interval: 2500
            onTriggered: savePopup.close()
        }

        onOpened: hideTimer.start()
    }

    