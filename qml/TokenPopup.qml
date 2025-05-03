import QtQuick.Controls.Universal
import QtQuick
import QtQuick.Layouts
import "."

AnimatedPopup {
    id: tokenPopup
    width: tokenLayout.width + 40
    height: tokenLayout.height + 40
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property string currentToken: ""

    onOpened: {
        tokenInput.text = botBridge.get_token()
        currentToken = tokenInput.text
    }

    ColumnLayout {
        id: tokenLayout
        anchors.centerIn: parent
        spacing: 15
        width: 350

        Label {
            text: "Discord Bot Token"
            font.pixelSize: 16
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            
            TextField {
                id: tokenInput
                Layout.fillWidth: true
                placeholderText: "Enter your Discord bot token"
                echoMode: TextInput.Password
                selectByMouse: true
            }
            
            Button {
                Layout.preferredWidth: height
                Layout.preferredHeight: tokenInput.height
                flat: true
                icon.source: "icons/reveal.png"
                icon.width: width * 0.6
                icon.height: height * 0.6
                
                onClicked: {
                    if (tokenInput.echoMode === TextInput.Password) {
                        tokenInput.echoMode = TextInput.Normal
                    } else {
                        tokenInput.echoMode = TextInput.Password
                    }
                }
            }
        }

        Label {
            text: "⚠️ Never share your bot token with anyone"
            color: "yellow"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10
            spacing: 10
            property int buttonWidth: Math.max(saveButton.implicitWidth, cancelButton.implicitWidth)

            Button {
                id: cancelButton
                text: "Cancel"
                Layout.fillWidth: true
                Layout.preferredWidth: parent.buttonWidth
                onClicked: tokenPopup.close()
            }

            Button {
                id: saveButton
                text: "Save and reconnect"
                Layout.fillWidth: true
                Layout.preferredWidth: parent.buttonWidth
                highlighted: true
                enabled: tokenInput.text.trim() !== "" && tokenInput.text !== tokenPopup.currentToken
                
                onClicked: {
                    botBridge.save_token(tokenInput.text.trim())
                    tokenPopup.close()
                }
            }
        }
    }
}