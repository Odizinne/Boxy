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
    Universal.accent: Universal.Green
    property bool songLoaded: false

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
        spacing: 10

        Label {
            id: statusLabel
            text: "Connecting..."
            color: text === "Connecting..." ? Universal.foreground : Universal.accent
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

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
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
                Connections {
                    target: botBridge
                    function onDownloadStatusChanged(status) {
                        urlInput.placeholderText = status === "" ? 
                            "Enter YouTube URL or search term" : status
                    }
                }
            }

            Button {
                id: playButton
                enabled: statusLabel.text === "Connected"
                Layout.preferredWidth: pauseButton.width
                text: "Go"
                onClicked: {
                    if (urlInput.text.length > 0) {
                        botBridge.play_url(urlInput.text)
                        urlInput.text = ""
                    }
                }
            }
        }

        MenuSeparator { 
            Layout.fillWidth: true
            Layout.leftMargin: -14
            Layout.rightMargin: -14
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
                id: songLabel
                text: "No song playing"
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width * 0.85
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
                font.pixelSize: 14
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 3
                Connections {
                    target: botBridge
                    function onSongChanged(songTitle) {
                        if (songTitle !== "" ) {
                            songLabel.text = songTitle
                        } else {
                            songLabel.text = "No song playing"
                        }
                        songLoaded = songTitle !== ""
                    }
                }
            }

            Image {
                id: thumbnailImage
                Layout.preferredWidth: parent.width * 0.15
                Layout.preferredHeight: thumbnailImage.Layout.preferredWidth  
                fillMode: Image.PreserveAspectCrop
                property string currentUrl: ""

                source: currentUrl || (Universal.theme === Universal.Dark ? 
                    "icons/placeholder_light.png" : "icons/placeholder_dark.png")

                Connections {
                    target: botBridge
                    function onThumbnailChanged(url) {
                        thumbnailImage.currentUrl = url
                    }
                }

                visible: true
                clip: true
                asynchronous: true 
                cache: false      


            }
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
                text: formatTime(timelineSlider.value)
                font.pixelSize: 14
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
                    if (!pressed) { 
                        botBridge.seek(value)
                    }
                }

                Connections {
                    target: botBridge
                    function onDurationChanged(duration) {
                        timelineSlider.to = duration
                    }
                    function onPositionChanged(position) {
                        if (!timelineSlider.pressed) {
                            timelineSlider.value = position
                        }
                    }
                }
            }

            Label {
                Layout.preferredWidth: pauseButton.width
                text: formatTime(timelineSlider.to)
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
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

        MenuSeparator { 
            Layout.fillWidth: true
            Layout.leftMargin: -14
            Layout.rightMargin: -14
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

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
                    if (currentValue) {
                        botBridge.set_current_server(currentValue)
                    }
                }

                Connections {
                    target: botBridge
                    function onServersChanged(servers) {
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

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

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
                    if (currentValue) {
                        botBridge.set_current_channel(currentValue)
                    }
                }

                Connections {
                    target: botBridge
                    function onChannelsChanged(channels) {
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