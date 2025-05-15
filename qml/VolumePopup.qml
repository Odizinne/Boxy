import QtQuick.Controls.Material

Popup {
    id: control
    height: 40
    width: implicitWidth
    Material.elevation: 10
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Slider {
        id: volumeSlider
        anchors.leftMargin: -5
        anchors.rightMargin: -5
        anchors.fill: parent
        from: 0.0
        to: 1.0
        value: BoxySettings.volume
        onValueChanged: {
            BoxySettings.volume = value
            botBridge.set_volume(value)
        }
    }
}