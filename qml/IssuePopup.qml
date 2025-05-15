import QtQuick.Controls.Material
import QtQuick
import "."

Popup {
    id: savePopup
    width: saveLabel.width + 40
    height: saveLabel.height + 30
    property string displayText: ""

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

