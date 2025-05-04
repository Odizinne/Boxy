import QtQuick.Controls.Universal
import QtQuick
import QtQuick.Layouts
import "."

AnimatedPopup {
    id: playlistPopup
    height: playlistLayout.height + 30
    modal: true
    closePolicy: Popup.CloseOnEscape

    onClosed: {
        busyIndicator.visible = false
        prompt1Label.visible = true
        prompt2Label.visible = true
        extractingLabel.visible = false
        currentSongBtn.visible = true
        entireBtn.visible = true
    }

    ColumnLayout {
        id: playlistLayout
        anchors.centerIn: parent
        spacing: 14

        Label {
            id: prompt1Label
            text: "It looks like you're trying to add a playlist."
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.bold: true
            font.pixelSize: 16
        }

        Label {
            id: prompt2Label
            text: "Would you like to add the entire playlist\nor just the current song?"
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }

        Label {
            id: extractingLabel
            text: "Extracting URLs..."
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            visible: false
        }

        BusyIndicator {
            id: busyIndicator
            visible: false
            running: visible
            Layout.fillWidth: true
            Layout.preferredWidth: 50
            Layout.preferredHeight: 50
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 14

            Button {
                id: currentSongBtn
                text: "Current Song"
                onClicked: {
                    let cleanUrl = newItemInput.text.trim().split("&list=")[0]

                    let idx = playlistModel.count
                    playlistModel.append({
                                             "userTyped": cleanUrl,
                                             "url": "",
                                             "resolvedTitle": "",
                                             "channelName": "",
                                             "isResolving": true
                                         })
                    botBridge.resolve_title(idx, cleanUrl)
                    newItemInput.text = ""
                    playlistPopup.close()
                }
            }

            Button {
                id: entireBtn
                text: "Entire Playlist"
                onClicked: {
                    busyIndicator.visible = true
                    prompt1Label.visible = false
                    prompt2Label.visible = false
                    extractingLabel.visible = true
                    currentSongBtn.visible = false
                    entireBtn.visible = false
                    botBridge.extract_urls_from_playlist(newItemInput.text.trim())
                }
            }
        }
    }
}
