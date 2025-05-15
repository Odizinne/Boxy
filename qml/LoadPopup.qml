import QtQuick.Controls.Material
import QtQuick
import QtQuick.Layouts
import "."

AnimatedPopup {
    id: playlistSelectorPopup
    width: 350
    height: 350
    modal: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        ScrollView {
            id: scrlView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: playlistList.model.count > 7 ?
                                           ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            property bool scrollBarVisible: ScrollBar.vertical.policy === ScrollBar.AlwaysOn 

            ListView {
                id: playlistList
                model: ListModel {}
                clip: true
                highlightMoveDuration: 0
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds

                delegate: ItemDelegate {
                    width: scrlView.scrollBarVisible ? playlistList.width - 30: playlistList.width
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

                        CustomRoundButton {
                            Layout.alignment: Qt.AlignCenter
                            icon.source: "icons/trash.png"
                            icon.width: 16
                            icon.height: 16
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

        MaterialButton {
            text: "Open Playlist Folder"
            Layout.fillWidth: true
            onClicked: {
                let path = botBridge.get_playlists_directory()
                // Check if path starts with a slash (Linux/macOS) or has a drive letter (Windows)
                let url = path.startsWith("/") ? "file://" + path : "file:///" + path
                Qt.openUrlExternally(url)
                playlistSelectorPopup.close()
            }
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
