import QtQuick.Controls.Universal
import QtQuick
import "."

AnimatedPopup {
    id: savePopup
    width: saveLabel.width + 40
    height: saveLabel.height + 30
    property string displayText: "Playlist saved successfully"

    Label {
        id: saveLabel
        font.pixelSize: 14
        anchors.centerIn: parent
        text: savePopup.displayText
    }

    Timer {
        id: hideTimer
        interval: 2500
        onTriggered: savePopup.close()
    }

    onOpened: hideTimer.start()
}

