import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Universal

ApplicationWindow {
    visible: true
    id: root
    width: 800
    height: appLayout.implicitHeight + 28
    minimumWidth: 800
    minimumHeight: appLayout.implicitHeight + 28
    maximumWidth: 800
    maximumHeight: appLayout.implicitHeight + 28
    title: "Boxy GUI"
    Universal.theme: Universal.System
    Universal.accent: Universal.Green
    property bool songLoaded: false

    function formatTime(seconds) {
        var minutes = Math.floor(seconds / 60)
        var remainingSeconds = Math.floor(seconds % 60)
        return minutes + ":" + (remainingSeconds < 10 ? "0" : "") + remainingSeconds
    }

    Connections {
        target: botBridge

        function onTitleResolved(index, title, url) {
            playlistModel.setProperty(index, "resolvedTitle", title)
            if (url) {
                playlistModel.setProperty(index, "url", url)
            }
            playlistModel.setProperty(index, "isResolving", false)
        }

        function onPlaylistLoaded(items, title) {
            playlistModel.clear()
            playlistName.text = title
            items.forEach(function(item) {
                playlistModel.append({
                                         "userTyped": item.userTyped,
                                         "url": item.url || "",
                                         "resolvedTitle": item.resolvedTitle || "",
                                         "isResolving": !item.resolvedTitle
                                     })

                if (!item.resolvedTitle) {
                    let idx = playlistModel.count - 1
                    botBridge.resolve_title(idx, item.userTyped)
                }
            })
        }

        function onSongLoadedChanged(loaded) {
            if (!loaded && !botBridge.repeat_mode && stopPlaylistButton.isPlaying) {
                if (playlistView.currentIndex < playlistModel.count - 1) {
                    // Auto-play next song
                    playlistView.currentIndex++
                    let item = playlistModel.get(playlistView.currentIndex)
                    botBridge.play_url(item.url || item.userTyped)
                } else {
                    // We're at the last song and it finished
                    stopPlaylistButton.isPlaying = false
                    playlistView.currentIndex = 0
                }
                playlistView.manualNavigation = false
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 10
        anchors.margins: 14
        id: appLayout


        ColumnLayout {
            id: colLayout
            Layout.fillWidth: true
            Layout.preferredWidth: parent.width * 0.4
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
                Layout.topMargin: 14

                ColumnLayout {
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
                        maximumLineCount: 1
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

                    Label {
                        id: channelLabel
                        text: ""
                        Layout.fillWidth: true
                        Layout.preferredWidth: parent.width * 0.85
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                        font.pixelSize: 14
                        font.bold: false
                        wrapMode: Text.Wrap
                        maximumLineCount: 1
                        Connections {
                            target: botBridge
                            function onChannelNameChanged(channelName) {
                                if (channelName !== "" ) {
                                    channelLabel.text = channelName
                                } else {
                                    channelLabel.text = ""
                                }
                            }
                        }
                    }
                }
                Image {
                    id: thumbnailImage
                    Layout.rowSpan: 2
                    Layout.preferredWidth: parent.width * 0.30
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
                Layout.topMargin: 14

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
                    enabled: songLoaded && !downloadProgress.visible

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
                Layout.topMargin: 14
                spacing: 10

                Button {
                    id: stopPlaylistButton
                    Layout.preferredWidth: repeatButton.width
                    property bool isPlaying: false
                    text: "s"
                    enabled: isPlaying
                    onClicked: {
                        botBridge.stop_playing()
                        playlistView.currentIndex = 0
                        isPlaying = false
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    id: playPrevButton
                    text: "<"
                    enabled: playlistView.currentIndex > 0 && stopPlaylistButton.isPlaying && !downloadProgress.visible
                    onClicked: {
                        if (playlistView.currentIndex > 0) {
                            playlistView.manualNavigation = true  // Set flag for manual navigation
                            playlistView.currentIndex--
                            let item = playlistModel.get(playlistView.currentIndex)
                            botBridge.play_url(item.url || item.userTyped)
                        }
                    }
                }

                Button {
                    id: pauseButton
                    Layout.preferredWidth: pauseButton.height
                    enabled: songLoaded && !downloadProgress.visible
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
                    id: playNextButton
                    text: ">"
                    enabled: playlistView.currentIndex < (playlistModel.count - 1) && stopPlaylistButton.isPlaying && !downloadProgress.visible
                    onClicked: {
                        if (playlistView.currentIndex < (playlistModel.count - 1)) {
                            playlistView.manualNavigation = true  // Set flag for manual navigation
                            playlistView.currentIndex++
                            let item = playlistModel.get(playlistView.currentIndex)
                            botBridge.play_url(item.url || item.userTyped)
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
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
                Layout.topMargin: 14
                Layout.bottomMargin: 14
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

            Button {
                id: disconnectButton
                text: botBridge.voiceConnected ? "Disconnect from channel" : "Connect to channel"
                Layout.fillWidth: true
                enabled: statusLabel.text === "Connected" && channelComboBox.currentValue
                onClicked: {
                    if (botBridge.voiceConnected) {
                        botBridge.disconnect_voice()
                    } else {
                        botBridge.connect_to_channel()
                    }
                }
            }
        }

        ToolSeparator {
            Layout.fillHeight: true
        }

        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: parent.width * 0.6
            spacing: 10
            Layout.fillWidth: true

            // Playlist content
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Button {
                    text: "Load"
                    onClicked: botBridge.load_playlist()
                    enabled: statusLabel.text === "Connected"
                }

                Button {
                    text: "Save"
                    enabled: playlistName.text.trim() !== "" && playlistModel.count > 0
                    onClicked: {
                        let items = []
                        for (let i = 0; i < playlistModel.count; i++) {
                            let item = playlistModel.get(i)
                            items.push({
                                           "userTyped": item.userTyped,
                                           "url": item.url || "",
                                           "resolvedTitle": item.resolvedTitle || ""
                                       })
                        }
                        botBridge.save_playlist(playlistName.text, items)
                        savePopup.visible = true
                        hideTimer.start()
                    }
                }

                TextField {
                    id: playlistName
                    text: ""
                    placeholderText: "Super playlist"
                    Layout.fillWidth: true
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: playlistView
                    anchors.fill: parent
                    model: ListModel { id: playlistModel }
                    spacing: 5
                    property bool manualNavigation: false  // Add this property


                    delegate: ItemDelegate {
                        width: ListView.view.width
                        height: 50
                        enabled: !downloadProgress.visible

                        // Add mouse area to handle double clicks
                        MouseArea {
                            anchors.fill: parent
                            onDoubleClicked: {
                                playlistView.manualNavigation = true
                                playlistView.currentIndex = model.index
                                let item = playlistModel.get(model.index)
                                if (!stopPlaylistButton.isPlaying) {
                                    stopPlaylistButton.isPlaying = true
                                }
                                botBridge.play_url(item.url || item.userTyped)
                            }
                        }

                        Rectangle {
                            // Playing indicator bar
                            width: 3
                            height: parent.height / 2
                            color: Universal.accent
                            visible: model.index === playlistView.currentIndex
                            anchors.verticalCenter: parent.verticalCenter  // Center vertically
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 5
                            anchors.leftMargin: 8
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Label {
                                    text: model.resolvedTitle || model.userTyped
                                    font.bold: model.resolvedTitle ? true : false
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            BusyIndicator {
                                id: titleFetchingIndicator
                                visible: model.isResolving
                                running: visible
                                height: 32
                                width: 32
                            }

                            Button {
                                text: "-"
                                Layout.rightMargin: 15
                                onClicked: playlistModel.remove(model.index)
                            }
                        }
                    }
                }
            }

            ProgressBar {
                id: downloadProgress
                Layout.fillWidth: true
                indeterminate: true
                Layout.bottomMargin: -5
                visible: newItemInput.placeholderText !== "Enter YouTube URL or search term"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                TextField {
                    id: newItemInput
                    Layout.fillWidth: true
                    placeholderText: "Enter YouTube URL or search term"
                    enabled: statusLabel.text === "Connected"

                    onAccepted: addButton.clicked()
                    Connections {
                        target: botBridge
                        function onDownloadStatusChanged(status) {
                            newItemInput.placeholderText = status === "" ?
                                        "Enter YouTube URL or search term" : status
                        }
                    }
                }

                Button {
                    id: addButton
                    text: "Add"
                    enabled: newItemInput.text.trim() !== ""
                    onClicked: {
                        if (newItemInput.text.trim() !== "") {
                            let idx = playlistModel.count
                            playlistModel.append({
                                                     "userTyped": newItemInput.text.trim(),
                                                     "url": "",
                                                     "resolvedTitle": "",
                                                     "isResolving": true
                                                 })
                            botBridge.resolve_title(idx, newItemInput.text.trim())
                            newItemInput.text = ""
                        }
                    }
                }
            }
        }
    }

    // Add popup at root level
    Popup {
        id: savePopup
        x: (parent.width - width) / 2
        y: parent.height - height - 50
        width: saveLabel.width + 20
        height: saveLabel.height + 20
        opacity: 0.8

        Label {
            id: saveLabel
            anchors.centerIn: parent
            text: "Playlist saved successfully"
        }

        Timer {
            id: hideTimer
            interval: 1500
            onTriggered: savePopup.close()
        }
    }
}
