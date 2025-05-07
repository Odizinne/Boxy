import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Universal
import Qt.labs.platform as Platform

import "."

ApplicationWindow {
    visible: true
    id: root
    width: 500
    height: 750
    minimumWidth: 500
    minimumHeight: 750
    title: "Boxy GUI"
    Universal.theme: BoxySettings.darkMode ? Universal.Dark : Universal.Light
    Universal.accent: BoxySettings.accentColor
    property bool songLoaded: false
    property var shufflePlayedIndices: []
    property bool connectedToAPI: false
    property bool isAutoAdvancing: false
    property bool isResolvingAny: {
        for(let i = 0; i < playlistModel.count; i++) {
            if(playlistModel.get(i).isResolving) return true;
        }
        return false;
    }

    Shortcut {
        sequence: "Ctrl+N"
        enabled: root.connectedToAPI && playlistModel.count > 0 && !root.isResolvingAny
        onActivated: {
            playlistModel.clear()
            playlistName.text = ""
        }
    }

    Shortcut {
        sequence: "Ctrl+O"
        enabled: root.connectedToAPI && !root.isResolvingAny
        onActivated: playlistSelectorPopup.open()
    }

    Shortcut {
        sequence: "Ctrl+S"
        enabled: !root.isResolvingAny
        onActivated: root.savePlaylist()
    }

    Shortcut {
        sequence: "Ctrl+Q"
        enabled: true
        onActivated: Qt.quit()
    }

    header: ToolBar {
        height: 30
        ToolButton {
            id: menuButton
            height: parent.height
            text: "File"
            onClicked: mainMenu.visible = !mainMenu.visible
            Menu {
                id: mainMenu
                topMargin: 30
                title: qsTr("File")
                width: 200
                visible: false
                enter: Transition {
                    NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; easing.type: Easing.Linear; duration: 110 }
                }
                exit: Transition {
                    NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; easing.type: Easing.Linear; duration: 110 }
                }

                CustomMenuItem {
                    text: "UI Config"
                    onTriggered: globalConfigPopup.open()
                }

                CustomMenuItem {
                    text: "Cache settings"
                    onTriggered: cacheSettingsPopup.open()
                }

                CustomMenuItem {
                    text: "Edit token"
                    onTriggered: tokenPopup.open()
                }
                MenuSeparator {}

                CustomMenuItem {
                    onTriggered: Qt.quit()

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        Label {
                            text: "Exit"
                            Layout.fillWidth: true
                        }

                        Label {
                            text: "Ctrl + Q"
                            opacity: 0.2
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        ToolButton {
            anchors.left: menuButton.right
            height: parent.height
            text: "Playlist"
            onClicked: playlistMenu.visible = !playlistMenu.visible
            id: playlistButton
            Menu {
                id: playlistMenu
                title: qsTr("Playlist")
                topMargin: 30
                width: 200
                visible: false
                enter: Transition {
                    NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; easing.type: Easing.Linear; duration: 110 }
                }
                exit: Transition {
                    NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; easing.type: Easing.Linear; duration: 110 }
                }

                CustomMenuItem {
                    enabled: root.connectedToAPI && playlistModel.count > 0 && !root.isResolvingAny
                    onTriggered: {
                        playlistModel.clear()
                        playlistName.text = ""
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        Label {
                            text: "New"
                            Layout.fillWidth: true
                        }

                        Label {
                            text: "Ctrl + N"
                            opacity: 0.2
                            font.pixelSize: 12
                        }
                    }
                }

                CustomMenuItem {
                    enabled: root.connectedToAPI && !root.isResolvingAny
                    onTriggered: playlistSelectorPopup.open()

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        Label {
                            text: "Load"
                            Layout.fillWidth: true
                        }

                        Label {
                            text: "Ctrl + O"
                            opacity: 0.2
                            font.pixelSize: 12
                        }
                    }
                }

                CustomMenuItem {
                    enabled: !root.isResolvingAny
                    onTriggered: root.savePlaylist()

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        Label {
                            text: "Save"
                            Layout.fillWidth: true
                        }

                        Label {
                            text: "Ctrl + S"
                            opacity: 0.2
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        ToolButton {
            id: serversToolButton
            text: "Servers"
            height: parent.height
            anchors.left: playlistButton.right
            property var serverData: ({servers: [], channels: {}})
            property var noServersItem: null

            function refreshServerData() {
                serverData = botBridge.get_servers_with_channels()
                serverMenuInstantiator.model = serverData.servers
            }

            onClicked: serversMenu.visible = !serversMenu.visible

            Connections {
                target: botBridge
                function onStatusChanged(status) {
                    if (status === "Connected") {
                        serversToolButton.refreshServerData()
                    }
                }
            }

            Menu {
                id: serversMenu
                title: qsTr("Servers")
                topMargin: 30
                width: 250
                visible: false
                enter: Transition {
                    NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; easing.type: Easing.Linear; duration: 110 }
                }
                exit: Transition {
                    NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; easing.type: Easing.Linear; duration: 110 }
                }

                CustomMenuItem {
                    text: "Refresh Server List"
                    onTriggered: serversToolButton.refreshServerData()
                }

                CustomMenuItem {
                    text: "Invite Boxy to server"
                    onTriggered: {
                        let link = botBridge.get_invitation_link()
                        if (link) {
                            Qt.openUrlExternally(link)
                        }
                    }
                }

                CustomMenuItem {
                    text: "Disconnect"
                    enabled: botBridge.voiceConnected
                    onTriggered: botBridge.disconnect_voice()
                }

                MenuSeparator {}
            }

            Instantiator {
                id: serverMenuInstantiator
                model: serversToolButton.serverData.servers

                delegate: Menu {
                    id: serverMenu
                    required property int index
                    required property var modelData
                    property var noChannelsItem: null
                    enter: Transition {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; easing.type: Easing.Linear; duration: 110 }
                    }
                    exit: Transition {
                        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; easing.type: Easing.Linear; duration: 110 }
                    }
                    title: modelData.name

                    Instantiator {
                        id: channelInstantiator
                        model: serversToolButton.serverData.channels[modelData.id] || []

                        delegate: CustomMenuItem {
                            required property int index
                            required property var modelData

                            text: modelData.name

                            onTriggered: {
                                botBridge.connect_to_channel(serverMenu.modelData.id, modelData.id)
                                serversMenu.close()
                            }
                        }

                        onObjectAdded: function(index, object) {
                            if (serverMenu.noChannelsItem) {
                                serverMenu.removeItem(serverMenu.noChannelsItem)
                                serverMenu.noChannelsItem = null
                            }
                            serverMenu.addItem(object)
                        }

                        onObjectRemoved: function(index, object) {
                            serverMenu.removeItem(object)
                            if (channelInstantiator.count === 0) {
                                serverMenu.noChannelsItem = Qt.createQmlObject(
                                    'import "." as Custom; Custom.CustomMenuItem { text: "No channels available"; enabled: false }',
                                    serverMenu,
                                    "noChannelsPlaceholder"
                                )
                                serverMenu.addItem(serverMenu.noChannelsItem)
                            }
                        }

                        Component.onCompleted: {
                            if (count === 0) {
                                serverMenu.noChannelsItem = Qt.createQmlObject(
                                    'import "." as Custom; Custom.CustomMenuItem { text: "No channels available"; enabled: false }',
                                    serverMenu,
                                    "noChannelsPlaceholder"
                                )
                                serverMenu.addItem(serverMenu.noChannelsItem)
                            }
                        }
                    }
                }

                onObjectAdded: function(index, object) {
                    if (serversToolButton.noServersItem) {
                        serversMenu.removeItem(serversToolButton.noServersItem)
                        serversToolButton.noServersItem = null
                    }
                    serversMenu.insertMenu(index + 4, object)
                }

                onObjectRemoved: function(index, object) {
                    serversMenu.removeMenu(object)
                    if (serverMenuInstantiator.count === 0) {
                        serversToolButton.noServersItem = Qt.createQmlObject(
                            'import "." as Custom; Custom.CustomMenuItem { text: "No servers available"; enabled: false }',
                            serversMenu,
                            "noServersPlaceholder"
                        )
                        serversMenu.addItem(serversToolButton.noServersItem)
                    }
                }

                Component.onCompleted: {
                    if (count === 0) {
                        serversToolButton.noServersItem = Qt.createQmlObject(
                            'import "." as Custom; Custom.CustomMenuItem { text: "No servers available"; enabled: false }',
                            serversMenu,
                            "noServersPlaceholder"
                        )
                        serversMenu.addItem(serversToolButton.noServersItem)
                    }
                }
            }
        }
    }

    function formatTime(seconds) {
        var minutes = Math.floor(seconds / 60)
        var remainingSeconds = Math.floor(seconds % 60)
        return minutes + ":" + (remainingSeconds < 10 ? "0" : "") + remainingSeconds
    }

    function savePlaylist() {
        if (playlistName.text.trim() === "") {
            savePopup.displayText = "You must name the playlist"
            savePopup.visible = true
            return
        } else if (!playlistModel.count > 0) {
            savePopup.displayText = "Cannot save empty playlist"
            savePopup.visible = true
            return
        } else {
            let items = []
            for (let i = 0; i < playlistModel.count; i++) {
                let item = playlistModel.get(i)
                items.push({
                               "userTyped": item.userTyped,
                               "url": item.url || "",
                               "resolvedTitle": item.resolvedTitle || "",
                               "channelName": item.channelName || ""
                           })
            }
            botBridge.save_playlist(playlistName.text, items)
            savePopup.displayText = "Playlist saved successfully"
            savePopup.visible = true
        }
    }

    Connections {
        target: botBridge

        function onItemDownloadStarted(url, index) {
            if (index < playlistModel.count) {
                playlistModel.setProperty(index, "isDownloading", true)
            }
        }

        function onItemDownloadCompleted(url, index) {
            if (index < playlistModel.count) {
                playlistModel.setProperty(index, "isDownloading", false)
            }
        }

        function onStatusChanged(status) {
            if (status === "Connected") {
                root.connectedToAPI = true
            } else {
                root.connectedToAPI = false
            }
        }

        function onTitleResolved(index, title, url, channelName) {
            playlistModel.setProperty(index, "resolvedTitle", title)
            playlistModel.setProperty(index, "channelName", channelName)
            if (url) {
                playlistModel.setProperty(index, "url", url)
            }
            playlistModel.setProperty(index, "isResolving", false)
        }

        function onBatchDownloadProgressChanged(current, total, status) {
            playlistDownloadProgress.from = 0
            playlistDownloadProgress.to = total
            playlistDownloadProgress.value = current
            newItemInput.placeholderText = status
        }

        function onPlaylistLoaded(items, title) {
            playlistModel.clear()
            playlistName.text = title
            items.forEach(function(item) {
                playlistModel.append({
                                         "userTyped": item.userTyped,
                                         "url": item.url || "",
                                         "resolvedTitle": item.resolvedTitle || "",
                                         "channelName": item.channelName || "",
                                         "isResolving": !item.resolvedTitle || !item.url || !item.channelName,
                                         "isDownloading": false
                                     })

                if (!item.resolvedTitle || !item.url || !item.channelName) {
                    let idx = playlistModel.count - 1
                    botBridge.resolve_title(idx, item.userTyped)
                }
            })
        }

        function onSongLoadedChanged(loaded) {
            if (loaded) {
                isAutoAdvancing = false
            }

            if (!loaded && !botBridge.repeat_mode && stopPlaylistButton.isPlaying &&
                    !playlistView.manualNavigation && !isAutoAdvancing) {

                if (playlistView.currentIndex < playlistModel.count - 1) {
                    isAutoAdvancing = true

                    if (shuffleButton.checked) {
                        let availableIndices = []
                        for (let i = 0; i < playlistModel.count; i++) {
                            if (!shufflePlayedIndices.includes(i)) {
                                availableIndices.push(i)
                            }
                        }

                        if (availableIndices.length === 0) {
                            shufflePlayedIndices = []
                            stopPlaylistButton.isPlaying = false
                            playlistView.currentIndex = 0
                            isAutoAdvancing = false
                            return
                        }

                        const randomIndex = Math.floor(Math.random() * availableIndices.length)
                        const nextIndex = availableIndices[randomIndex]

                        shufflePlayedIndices.push(nextIndex)

                        playlistView.currentIndex = nextIndex
                        let item = playlistModel.get(nextIndex)
                        botBridge.play_url(item.url || item.userTyped)
                    } else {
                        playlistView.currentIndex++
                        let item = playlistModel.get(playlistView.currentIndex)
                        botBridge.play_url(item.url || item.userTyped)
                    }
                } else {
                    stopPlaylistButton.isPlaying = false
                    playlistView.currentIndex = 0
                    isAutoAdvancing = false
                }
            }

            playlistView.manualNavigation = false
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14
        anchors.margins: 14
        id: appLayout

        Frame {
            //Layout.fillHeight: true
            Layout.fillWidth: true
            //Layout.preferredWidth: parent.width * 0.45

            ColumnLayout {
                id: colLayout
                anchors.fill: parent
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

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
                            maximumLineCount: 2
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
                        property int idealSize: (parent.width * 0.30) / 2
                        Layout.preferredWidth: 128
                        Layout.preferredHeight: 128
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

                    RowLayout {
                        Layout.preferredWidth: controlLyt.implicitWidth
                        Button {
                            id: stopPlaylistButton
                            icon.source: "icons/stop.png"
                            Layout.preferredWidth: height
                            property bool isPlaying: false
                            enabled: isPlaying
                            onClicked: {
                                botBridge.stop_playing()
                                playlistView.currentIndex = 0
                                isPlaying = false
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Button {
                        id: playPrevButton
                        icon.source: "icons/prev.png"
                        Layout.preferredWidth: height
                        enabled: playlistView.currentIndex > 0 && stopPlaylistButton.isPlaying && !downloadProgress.visible
                        onClicked: {
                            if (shuffleButton.checked) {
                                const currentPos = shufflePlayedIndices.indexOf(playlistView.currentIndex)
                                if (currentPos > 0) {
                                    playlistView.manualNavigation = true
                                    const prevIndex = shufflePlayedIndices[currentPos - 1]
                                    playlistView.currentIndex = prevIndex
                                    let item = playlistModel.get(prevIndex)
                                    botBridge.play_url(item.url || item.userTyped)
                                }
                            } else {
                                if (playlistView.currentIndex > 0) {
                                    playlistView.manualNavigation = true
                                    playlistView.currentIndex--
                                    let item = playlistModel.get(playlistView.currentIndex)
                                    botBridge.play_url(item.url || item.userTyped)
                                }
                            }
                        }
                    }

                    Button {
                        id: pauseButton
                        Layout.preferredWidth: height
                        enabled: songLoaded && !downloadProgress.visible
                        icon.source: "icons/play.png"
                        onClicked: {
                            botBridge.toggle_playback()
                        }

                        Connections {
                            target: botBridge
                            function onPlayStateChanged(isPlaying) {
                                pauseButton.icon.source = isPlaying ? "icons/pause.png" : "icons/play.png"
                            }
                        }
                    }

                    Button {
                        id: playNextButton
                        icon.source: "icons/next.png"
                        Layout.preferredWidth: height
                        enabled: playlistView.currentIndex < (playlistModel.count - 1) && stopPlaylistButton.isPlaying && !downloadProgress.visible
                        onClicked: {
                            if (shuffleButton.checked) {
                                let availableIndices = []
                                for (let i = 0; i < playlistModel.count; i++) {
                                    if (!shufflePlayedIndices.includes(i)) {
                                        availableIndices.push(i)
                                    }
                                }

                                if (availableIndices.length === 0) {
                                    shufflePlayedIndices = []
                                    stopPlaylistButton.isPlaying = false
                                    playlistView.currentIndex = 0
                                    return
                                }

                                const randomIndex = Math.floor(Math.random() * availableIndices.length)
                                const nextIndex = availableIndices[randomIndex]

                                playlistView.manualNavigation = true
                                shufflePlayedIndices.push(nextIndex)
                                playlistView.currentIndex = nextIndex
                                let item = playlistModel.get(nextIndex)
                                botBridge.play_url(item.url || item.userTyped)
                            } else {
                                if (playlistView.currentIndex < (playlistModel.count - 1)) {
                                    playlistView.manualNavigation = true
                                    playlistView.currentIndex++
                                    let item = playlistModel.get(playlistView.currentIndex)
                                    botBridge.play_url(item.url || item.userTyped)
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        id: controlLyt
                        Button {
                            id: shuffleButton
                            Layout.preferredWidth: height
                            icon.source: "icons/shuffle.png"
                            icon.width: 16
                            icon.height: 16
                            checkable: true
                            enabled: root.connectedToAPI
                            onCheckedChanged: {
                                if (checked && repeatButton.checked) {
                                    repeatButton.checked = false
                                }
                                BoxySettings.shuffle = checked
                            }
                            Component.onCompleted: {
                                checked = BoxySettings.shuffle
                            }
                        }

                        Button {
                            id: repeatButton
                            Layout.preferredWidth: height
                            icon.source: "icons/repeat.png"
                            icon.width: 16
                            icon.height: 16
                            checkable: true
                            enabled: root.connectedToAPI
                            onCheckedChanged: {
                                botBridge.set_repeat_mode(checked)
                                if (checked && shuffleButton.checked) {
                                    shuffleButton.checked = false
                                }
                                BoxySettings.repeat = checked
                            }
                            Component.onCompleted: {
                                checked = BoxySettings.repeat
                            }
                        }
                    }
                }
            }
        }

        Frame {
            Layout.fillHeight: true
            //Layout.preferredWidth: parent.width * 0.55
            Layout.fillWidth: true
            Layout.rowSpan: 2

            ColumnLayout {
                id: playListViewLayout
                spacing: 10
                anchors.fill: parent

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        id: downloadAllButton
                        icon.source: "icons/download.png"
                        enabled: root.connectedToAPI && playlistModel.count > 0 && !root.isResolvingAny && !downloadProgress.visible && !playlistDownloadProgress.visible
                        onClicked: {
                            stopPlaylistButton.click()
                            let urls = []
                            for (let i = 0; i < playlistModel.count; i++) {
                                let item = playlistModel.get(i)
                                urls.push(item.url || item.userTyped)
                            }
                            botBridge.download_all_playlist_items(urls)
                            downloadMessagePopup.visible = true
                        }
                    }

                    TextField {
                        id: playlistName
                        Layout.preferredHeight: addButton.height
                        text: ""
                        placeholderText: "My super playlist"
                        Layout.fillWidth: true
                        onAccepted: {
                            if (saveButton.enabled) {
                                root.savePlaylist()
                            }
                        }
                    }

                    Button {
                        id: editButton
                        text: "Edit"
                        checkable: true
                        enabled: checked ? true : playlistModel.count >= 2
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        visible: !root.connectedToAPI
                        anchors.fill: parent
                        spacing: 14

                        Item {
                            Layout.fillHeight: true
                        }

                        BusyIndicator {
                            id: connectIndicator
                            Layout.preferredHeight: 60
                            Layout.preferredWidth: 60
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.connectedToAPI === false && connectingLabel.text === "Connecting to Discord API..."
                        }

                        Image {
                            Layout.preferredHeight: 60
                            Layout.preferredWidth: 60
                            source: "icons/warning.png"
                            Layout.alignment: Qt.AlignHCenter
                            mipmap: true
                            visible: connectingLabel.text === "Incorrect token format"
                        }

                        Label {
                            id: connectingLabel
                            text: botBridge && botBridge.validTokenFormat ? "Connecting to Discord API..." : "Incorrect token format"
                            Layout.alignment: Qt.AlignHCenter
                            font.pixelSize: 18
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    ListView {
                        id: playlistView
                        anchors.fill: parent
                        model: ListModel { id: playlistModel }
                        spacing: 5
                        property bool manualNavigation: false
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {
                            policy: playlistView.contentHeight > playlistView.height ?
                                        ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                        }

                        delegate: ItemDelegate {
                            width: ListView.view.width
                            height: 50
                            enabled: !downloadProgress.visible && !root.isResolvingAny && !playlistDownloadProgress.visible

                            MouseArea {
                                anchors.fill: parent
                                onDoubleClicked: {
                                    playlistView.manualNavigation = true
                                    playlistView.currentIndex = model.index
                                    let item = playlistModel.get(model.index)

                                    if (shuffleButton.checked) {
                                        shufflePlayedIndices = [model.index]
                                    }
                                    if (!stopPlaylistButton.isPlaying) {
                                        stopPlaylistButton.isPlaying = true
                                    }
                                    botBridge.play_url(item.url || item.userTyped)
                                }
                            }

                            Rectangle {
                                width: 3
                                height: parent.height * 0.8
                                color: Universal.accent
                                visible: model.index === playlistView.currentIndex
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 5
                                anchors.leftMargin: 8
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillHeight: true
                                    spacing: 4
                                    visible: editButton.checked

                                    Button {
                                        id: moveUpButton
                                        icon.source: "icons/up.png"
                                        Layout.preferredHeight: width * 0.5
                                        enabled: model.index > 0
                                        onClicked: {
                                            // Store the current item data
                                            let currentItem = {
                                                userTyped: playlistModel.get(model.index).userTyped,
                                                url: playlistModel.get(model.index).url,
                                                resolvedTitle: playlistModel.get(model.index).resolvedTitle,
                                                channelName: playlistModel.get(model.index).channelName,
                                                isResolving: playlistModel.get(model.index).isResolving
                                            }

                                            // Store the item above
                                            let aboveIndex = model.index - 1
                                            let aboveItem = {
                                                userTyped: playlistModel.get(aboveIndex).userTyped,
                                                url: playlistModel.get(aboveIndex).url,
                                                resolvedTitle: playlistModel.get(aboveIndex).resolvedTitle,
                                                channelName: playlistModel.get(aboveIndex).channelName,
                                                isResolving: playlistModel.get(aboveIndex).isResolving
                                            }

                                            // Swap the items
                                            playlistModel.set(aboveIndex, currentItem)
                                            playlistModel.set(model.index, aboveItem)

                                            // Update currentIndex if needed
                                            if (playlistView.currentIndex === model.index) {
                                                playlistView.currentIndex--
                                            } else if (playlistView.currentIndex === model.index - 1) {
                                                playlistView.currentIndex++
                                            }
                                        }
                                    }

                                    Button {
                                        id: moveDownButton
                                        icon.source: "icons/down.png"
                                        Layout.preferredHeight: width * 0.5
                                        enabled: model.index < playlistModel.count - 1
                                        onClicked: {
                                            // Store the current item data
                                            let currentItem = {
                                                userTyped: playlistModel.get(model.index).userTyped,
                                                url: playlistModel.get(model.index).url,
                                                resolvedTitle: playlistModel.get(model.index).resolvedTitle,
                                                channelName: playlistModel.get(model.index).channelName,
                                                isResolving: playlistModel.get(model.index).isResolving
                                            }

                                            // Store the item below
                                            let belowIndex = model.index + 1
                                            let belowItem = {
                                                userTyped: playlistModel.get(belowIndex).userTyped,
                                                url: playlistModel.get(belowIndex).url,
                                                resolvedTitle: playlistModel.get(belowIndex).resolvedTitle,
                                                channelName: playlistModel.get(belowIndex).channelName,
                                                isResolving: playlistModel.get(belowIndex).isResolving
                                            }

                                            // Swap the items
                                            playlistModel.set(belowIndex, currentItem)
                                            playlistModel.set(model.index, belowItem)

                                            // Update currentIndex if needed
                                            if (playlistView.currentIndex === model.index) {
                                                playlistView.currentIndex++
                                            } else if (playlistView.currentIndex === model.index + 1) {
                                                playlistView.currentIndex--
                                            }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Label {
                                        text: model.resolvedTitle || model.userTyped
                                        font.bold: model.resolvedTitle ? true : false
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        text: model.channelName
                                        visible: model.channelName ? true : false
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.pixelSize: 12
                                        font.weight: 35
                                    }
                                }

                                BusyIndicator {
                                    id: titleFetchingIndicator
                                    visible: model.isResolving
                                    running: visible
                                    height: 16
                                    width: 16
                                    Layout.rightMargin: 10
                                }

                                BusyIndicator {
                                    id: downloadingIndicator
                                    visible: model.isDownloading
                                    running: visible
                                    height: 16
                                    width: 16
                                    Layout.rightMargin: 10
                                }

                                Button {
                                    icon.source: "icons/delete.png"
                                    icon.width: width / 3
                                    icon.height: height / 3
                                    Layout.rightMargin: 15
                                    visible: editButton.checked
                                    onClicked: playlistModel.remove(model.index)
                                    flat: true
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
                    visible: newItemInput.placeholderText !== "Enter YouTube URL or search term" &&
                             newItemInput.placeholderText !== "Cannot join empty channel" &&
                             newItemInput.placeholderText !== "Downloading playlist items..." &&
                             newItemInput.placeholderText !== "Download complete!" &&
                             newItemInput.placeholderText !== "All items already cached"
                }

                ProgressBar {
                    id: playlistDownloadProgress
                    Layout.fillWidth: true
                    Layout.bottomMargin: -5
                    visible: newItemInput.placeholderText === "Downloading playlist items..."
                    from: 0
                    to: 100
                    value: 0
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    TextField {
                        id: newItemInput
                        Layout.preferredHeight: addButton.height
                        Layout.fillWidth: true
                        placeholderText: "Enter YouTube URL or search term"
                        enabled: root.connectedToAPI

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
                        icon.source: "icons/plus.png"
                        Layout.preferredWidth: height
                        enabled: newItemInput.text.trim() !== ""
                        onClicked: {
                            if (newItemInput.text.trim() !== "") {
                                if (newItemInput.text.includes("&list=") ||
                                        newItemInput.text.includes("/playlist?list=")) {
                                    playlistPopup.open()
                                } else {
                                    let idx = playlistModel.count
                                    playlistModel.append({
                                                             "userTyped": newItemInput.text.trim(),
                                                             "url": "",
                                                             "resolvedTitle": "",
                                                             "channelName": "",
                                                             "isResolving": true,
                                                             "isDownloading": false
                                                         })
                                    botBridge.resolve_title(idx, newItemInput.text.trim())
                                    newItemInput.text = ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    SavePopup {
        id: savePopup
        parent: playlistView
        anchors.centerIn: parent
    }

    LoadPopup {
        id: playlistSelectorPopup
        parent: playlistView
        anchors.centerIn: parent
    }

    PlaylistPromptPopup {
        id: playlistPopup
        parent: playlistView
        anchors.centerIn: parent
        Connections {
            target: botBridge
            function onUrlsExtractedSignal(urls) {
                for (let url of urls) {
                    let idx = playlistModel.count
                    playlistModel.append({
                                             "userTyped": url,
                                             "url": "",
                                             "resolvedTitle": "",
                                             "channelName": "",
                                             "isResolving": true,
                                             "isDownloading": false
                                         })
                    botBridge.resolve_title(idx, url)
                }
                newItemInput.text = ""
                playlistPopup.close()
            }
        }
    }

    TokenPopup {
        id: tokenPopup
        parent: playlistView
        anchors.centerIn: parent
    }

    DownloadMessagePopup {
        id: downloadMessagePopup
        parent: playlistView
        anchors.centerIn: parent
    }

    CacheSettingsPopup {
        id: cacheSettingsPopup
        parent: playlistView
        anchors.centerIn: parent
    }

    GlobalConfigPopup {
        id: globalConfigPopup
        parent: playlistView
        anchors.centerIn: parent
    }
}
