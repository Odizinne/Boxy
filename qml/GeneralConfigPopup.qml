import QtQuick.Controls.Material
import QtQuick
import QtQuick.Layouts
import "."

Popup {
    id: generalConfigPopup
    width: configLayout.width + 40
    height: configLayout.height + 40
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property string currentUserId: ""

    onOpened: {
        userIdInput.text = BoxySettings.autoJoinUserId || ""
        currentUserId = userIdInput.text
    }

    ColumnLayout {
        id: configLayout
        anchors.centerIn: parent
        anchors.margins: 10
        spacing: 15
        width: 400

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Label {
                text: "If not connected when starting a song, try to join the person with this user ID:"
                Layout.fillWidth: true
                font.bold: true
                wrapMode: Text.WordWrap
                Layout.bottomMargin: 12
            }

            TextField {
                id: userIdInput
                Layout.fillWidth: true
                placeholderText: "Enter Discord User ID"
                selectByMouse: true
                Layout.preferredHeight: 35
                validator: RegularExpressionValidator { regularExpression: /^\d*$/ }
                
                onTextChanged: {
                    if (!/^\d*$/.test(text)) {
                        var cursorPos = cursorPosition
                        text = text.replace(/\D/g, '')
                        cursorPosition = cursorPos - (text.length - text.length)
                    }
                }
            }
            
            Label {
                text: "The Discord user ID is a unique number identifying each user. To get it, enable Developer Mode in Discord settings, then right-click a user and select 'Copy ID'."
                font.pixelSize: 12
                opacity: 0.5
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 15
            spacing: 10
            property int buttonWidth: Math.max(saveButton.implicitWidth, cancelButton.implicitWidth)

            MaterialButton {
                id: cancelButton
                text: "Cancel"
                Layout.fillWidth: true
                Layout.preferredWidth: parent.buttonWidth
                onClicked: generalConfigPopup.close()
            }

            MaterialButton {
                id: saveButton
                text: "Save"
                Layout.fillWidth: true
                Layout.preferredWidth: parent.buttonWidth
                highlighted: true
                enabled: userIdInput.text !== generalConfigPopup.currentUserId
                
                onClicked: {
                    BoxySettings.autoJoinUserId = userIdInput.text
                    generalConfigPopup.close()
                }
            }
        }
    }
}