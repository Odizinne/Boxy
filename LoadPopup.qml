import QtQuick.Controls.Universal
import QtQuick
import QtQuick.Layouts
import "."

    AnimatedPopup {
        id: playlistSelectorPopup
        parent: playlistView
        width: 350
        height: 350
        anchors.centerIn: parent
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 10

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: playlistList.model.count > 5 ?
                                               ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

                ListView {
                    id: playlistList
                    model: ListModel {}
                    clip: true
                    highlightMoveDuration: 0
                    currentIndex: 0
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: ItemDelegate {
                        width: playlistList.width
                        height: 40
                        required property string name
                        required property string filePath
                        required property int index

                        RowLayout {
                            anchors.fill: parent
                            spacing: 10
                            anchors.leftMargin: 10

                            Label {
                                text: name
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                Layout.alignment: Qt.AlignCenter
                            }

                            Button {
                                Layout.alignment: Qt.AlignCenter
                                icon.source: "icons/delete.png"
                                icon.width: width / 3
                                icon.height: height / 3
                                visible: filePath !== ""
                                flat: true
                                onClicked: {
                                    botBridge.delete_playlist(filePath)
                                    playlistList.model.remove(index)
                                }
                            }
                        }

                        onClicked: {
                            if (filePath !== "") {
                                botBridge.load_playlist(filePath)
                                playlistSelectorPopup.close()
                            }
                        }
                    }
                }
            }

            Button {
                text: "Open Playlist Folder"
                Layout.fillWidth: true
                onClicked: {
                    Qt.openUrlExternally("file:///" + botBridge.get_playlists_directory())
                    playlistSelectorPopup.close()
                }
            }

            Button {
                text: "Close"
                Layout.fillWidth: true
                onClicked: playlistSelectorPopup.close()
            }
        }

        onVisibleChanged: {
            if (visible) {
                playlistList.model.clear()
                let playlists = botBridge.get_playlist_files()

                if (playlists.length === 0) {
                    playlistList.model.append({
                                                  name: "No playlists found",
                                                  filePath: "",
                                                  enabled: false
                                              })
                } else {
                    playlists.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()))

                    playlists.forEach(function(playlist) {
                        playlistList.model.append({
                                                      name: playlist.name,
                                                      filePath: playlist.filePath,
                                                      enabled: true
                                                  })
                    })
                }
            }
        }
    }