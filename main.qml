import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Universal

ApplicationWindow {
    visible: true
    width: 400
    height: colLayout.implicitHeight + 28
    minimumWidth: 400
    minimumHeight: colLayout.implicitHeight + 28
    maximumWidth: 400
    maximumHeight: colLayout.implicitHeight + 28
    title: "Boxy GUI"
    Universal.theme: Universal.System
    Universal.accent: Universal.Orange
    property bool songLoaded: false


    // Add this function somewhere in your QML
    function formatTime(seconds) {
        var minutes = Math.floor(seconds / 60)
        var remainingSeconds = Math.floor(seconds % 60)
        return minutes + ":" + (remainingSeconds < 10 ? "0" : "") + remainingSeconds
    }

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
                    if (songTitle !== "" ) {
                        songLabel.text = "Now playing: " + songTitle
                    } else {
                        songLabel.text = "No song playing"
                    }
                    songLoaded = songTitle !== ""
                }
            }
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
            spacing: 10

            Label {
                text: formatTime(timelineSlider.value)
                font.pixelSize: 12
                Layout.preferredWidth: pauseButton.width
                horizontalAlignment: Text.AlignHCenter
            }

            Slider {
                id: timelineSlider
                Layout.fillWidth: true
                from: 0
                to: 1
                enabled: songLoaded

                onPressedChanged: {
                    if (!pressed) {  // Only trigger when the slider is released
                        botBridge.seek(value)
                    }
                }

                Connections {
                    target: botBridge
                    function onDurationChanged(duration) {
                        console.log("Duration changed:", duration)
                        timelineSlider.to = duration
                    }
                    function onPositionChanged(position) {
                        console.log("Position changed:", position)
                        if (!timelineSlider.pressed) {
                            timelineSlider.value = position
                        }
                    }
                }
            }

            Label {
                Layout.preferredWidth: pauseButton.width
                text: formatTime(timelineSlider.to)
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Button {
                id: pauseButton
                Layout.preferredWidth: pauseButton.height
                enabled: songLoaded
                onClicked: {
                    botBridge.toggle_playback()
                }

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
                text: "Disconnect from channel"
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
                Layout.preferredWidth: pauseButton.width
                checkable: true
                enabled: statusLabel.text === "Connected"
                onCheckedChanged: {
                    botBridge.set_repeat_mode(checked)
                    
                }
            }
        }

        // Server row
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Label {
                text: "Serv:"
                Layout.preferredWidth: pauseButton.width
                Layout.alignment: Qt.AlignVCenter
            }

            ComboBox {
                id: serverComboBox
                Layout.fillWidth: true
                enabled: statusLabel.text === "Connected"
                textRole: "name"
                valueRole: "id"
                model: []

                onCurrentValueChanged: {
                    console.log("Selected server:", currentValue)
                    if (currentValue) {
                        botBridge.set_current_server(currentValue)
                    }
                }

                Connections {
                    target: botBridge
                    function onServersChanged(servers) {
                        console.log("Servers received:", servers.length)
                        serverComboBox.model = servers
                        if (servers.length > 0) {
                            serverComboBox.currentIndex = 0
                            botBridge.set_current_server(servers[0].id)
                        }
                    }
                }

                Text {
                    visible: parent.model.length === 0 && statusLabel.text === "Connected"
                    anchors.centerIn: parent
                    text: "No servers available"
                    color: "gray"
                }
            }
        }

        // Channel row
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Label {
                id: channelListLabel
                text: "Chan:"
                Layout.preferredWidth: pauseButton.width
                Layout.alignment: Qt.AlignVCenter
            }

            ComboBox {
                id: channelComboBox
                Layout.fillWidth: true
                enabled: statusLabel.text === "Connected" && model.length > 0
                textRole: "name"
                valueRole: "id"
                model: []

                onCurrentValueChanged: {
                    console.log("Selected channel:", currentValue)
                    if (currentValue) {
                        botBridge.set_current_channel(currentValue)
                    }
                }

                Connections {
                    target: botBridge
                    function onChannelsChanged(channels) {
                        console.log("Channels received:", channels.length)
                        channelComboBox.model = channels
                        if (channels.length > 0) {
                            channelComboBox.currentIndex = 0
                            botBridge.set_current_channel(channels[0].id)
                        }
                    }
                }

                Text {
                    visible: parent.model.length === 0 && statusLabel.text === "Connected"
                    anchors.centerIn: parent
                    text: "No channels available"
                    color: "gray"
                }
            }
        }
    }
}