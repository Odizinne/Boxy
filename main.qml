import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Universal

ApplicationWindow {
    visible: true
    width: colLayout.implicitWidth + 58
    height: colLayout.implicitHeight + 28
    minimumWidth: colLayout.implicitWidth + 58
    minimumHeight: colLayout.implicitHeight + 28
    maximumWidth: colLayout.implicitWidth + 58
    maximumHeight: colLayout.implicitHeight + 28
    title: "Boxy GUI"
    Universal.theme: Universal.System
    Universal.accent: Universal.Orange
    property bool songLoaded: false

    onActiveChanged: {
        if (active) {
            urlInput.forceActiveFocus()
        }
    }

    ColumnLayout {
        id: colLayout
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        Label {
            id: statusLabel
            text: "Connecting..."
            color: statusLabel.text === "Connecting..." ? "#c2802f" : "#2fc245"
            font.pixelSize: 18
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
            Connections {
                target: botBridge
                function onStatusChanged(status) {
                    statusLabel.text = status
                }
            }
        }

        Label {
            id: songLabel
            text: "No song playing"
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: 14
            Connections {
                target: botBridge
                function onSongChanged(songTitle) {
                    songLabel.text = "Now playing: " + songTitle
                    songLoaded = songTitle !== ""
                }
            }
        }

        Item {
            Layout.preferredHeight: 5
        }

        Label {
            id: downloadStatus
            text: ""
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            color: "gray"
            font.pixelSize: 12
            visible: text !== ""
            Connections {
                target: botBridge
                function onDownloadStatusChanged(status) {
                    downloadStatus.text = status
                }
            }
        }

        Item {
            Layout.preferredHeight: downloadStatus.implicitHeight
            visible: !downloadStatus.visible
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            TextField {
                id: urlInput
                enabled: statusLabel.text === "Connected"
                Layout.preferredWidth: 250
                Layout.preferredHeight: playButton.implicitHeight -1
                placeholderText: "Enter YouTube URL or search term"
                Layout.fillWidth: true
                onAccepted: {
                    playButton.clicked()
                    urlInput.text = ""
                }
            }
            Button {
                id: playButton
                enabled: statusLabel.text === "Connected"
                Layout.preferredWidth: 40
                text: "Go"
                onClicked: {
                    if (urlInput.text.length > 0) {
                        botBridge.play_url(urlInput.text)
                        urlInput.text = ""
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Button {
                id: pauseButton
                //text: botBridge.isPlaying ? "Pause" : "Resume"
                Layout.preferredWidth: pauseButton.height
                enabled: songLoaded
                onClicked: {
                    botBridge.toggle_playback()
                }
                //Connections {
                //    target: botBridge
                //    function onPlayStateChanged(isPlaying) {
                //        pauseButton.text = isPlaying ? "Pause" : "Resume"
                //    }
                //}

                Image {
                    id:pauseImage
                    anchors.centerIn: parent
                    height: 24
                    width: 24
                    source: Universal.theme === Universal.Dark ? "icons/pause_light.png" : "icons/pause_dark.png"
                    visible: false
                    Connections {
                        target: botBridge
                        function onPlayStateChanged(isPlaying) {
                            pauseImage.visible = isPlaying
                        }
                    }
                }

                Image {
                    id:playImage
                    anchors.centerIn: parent
                    height: 24
                    width: 24
                    source: Universal.theme === Universal.Dark ? "icons/play_light.png" : "icons/play_dark.png"
                    visible: true
                    Connections {
                        target: botBridge
                        function onPlayStateChanged(isPlaying) {
                            playImage.visible = !isPlaying
                        }
                    }
                }
            }

            Button {
                id: disconnectButton
                text: "Leave channel"
                Layout.fillWidth: true
                enabled: botBridge.voiceConnected
                onClicked: {
                    botBridge.disconnect_voice()
                }
            }

            Button {
                id: repeatButton
                icon.source: Universal.theme === Universal.Dark ? "icons/repeat_light.png" : "icons/repeat_dark.png"
                icon.width: 16
                icon.height: 16
                Layout.preferredWidth: playButton.width
                checkable: true
                enabled: statusLabel.text === "Connected"
                onCheckedChanged: {
                    botBridge.set_repeat_mode(checked)
                    
                }
            }
        }
    }
}