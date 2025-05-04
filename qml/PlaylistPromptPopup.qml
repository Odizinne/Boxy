import QtQuick.Controls.Universal
import QtQuick
import QtQuick.Layouts
import "."

AnimatedPopup {
    id: playlistPopup
    height: playlistLayout.height + 30
    modal: true
    closePolicy: Popup.CloseOnEscape

    ColumnLayout {
        id: playlistLayout
        anchors.centerIn: parent
        spacing: 14

        Label {
            text: "It looks like you're trying to add a playlist."
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.bold: true
            font.pixelSize: 16
        }

        Label {
            text: "Would you like to add the entire playlist\nor just the current song?"
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 14

            Button {
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
                text: "Entire Playlist"
                onClicked: {
                    let urls = botBridge.extract_urls_from_playlist(newItemInput.text.trim())
                    for (let url of urls) {
                        let idx = playlistModel.count
                        playlistModel.append({
                                                 "userTyped": url,
                                                 "url": "",
                                                 "resolvedTitle": "",
                                                 "channelName": "",
                                                 "isResolving": true
                                             })
                        botBridge.resolve_title(idx, url)
                    }
                    newItemInput.text = ""
                    playlistPopup.close()
                }
            }
        }
    }
}
