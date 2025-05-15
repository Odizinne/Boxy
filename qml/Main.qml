import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Material

import "."

ApplicationWindow {
    visible: true
    id: root
    width: 500
    height: 750
    minimumWidth: 500
    minimumHeight: 750
    title: "Boxy"
    Material.theme: BoxySettings.darkMode ? Material.Dark : Material.Light
    Material.accent: Material.Pink
    Material.primary: Material.Indigo
    color: BoxySettings.darkMode ? "#1c1c1c" : "#E3E3E3"
    property bool songLoaded: botBridge.song_loaded
    property var shufflePlayedIndices: []
    property bool connectedToAPI: botBridge.status === "Connected"
    property bool isAutoAdvancing: false
    property bool isResolvingAny: {
        for(let i = 0; i < playlistModel.count; i++) {
            if(playlistModel.get(i).isResolving) return true
        }
        return false
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
        height: 40
        ToolButton {
            id: menuButton
            height: parent.height
            text: "File"
            onClicked: mainMenu.visible = !mainMenu.visible
            Menu {
                id: mainMenu
                topMargin: 40
                title: qsTr("File")
                width: 200
                visible: false

                MenuItem {
                    text: "General settings"
                    onTriggered: generalConfigPopup.open()
                }

                MenuItem {
                    text: "Cache settings"
                    onTriggered: cacheSettingsPopup.open()
                }

                MenuItem {
                    text: "Edit token"
                    onTriggered: tokenPopup.open()
                }
                MenuSeparator {}

                MenuItem {
                    onTriggered: Qt.quit()

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        Label {
                            text: "Exit"
                            Layout.fillWidth: true
                        }

                        Label {
                            text: "Ctrl + Q"
                            opacity: 0.4
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
                topMargin: 40
                width: 200
                visible: false

                MenuItem {
                    enabled: root.connectedToAPI && playlistModel.count > 0 && !root.isResolvingAny
                    onTriggered: {
                        playlistModel.clear()
                        playlistName.text = ""
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        Label {
                            text: "New"
                            Layout.fillWidth: true
                        }

                        Label {
                            text: "Ctrl + N"
                            opacity: 0.4
                            font.pixelSize: 12
                        }
                    }
                }

                MenuItem {
                    enabled: root.connectedToAPI && !root.isResolvingAny
                    onTriggered: playlistSelectorPopup.open()

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        Label {
                            text: "Load"
                            Layout.fillWidth: true
                        }

                        Label {
                            text: "Ctrl + O"
                            opacity: 0.4
                            font.pixelSize: 12
                        }
                    }
                }

                MenuItem {
                    enabled: !root.isResolvingAny
                    onTriggered: root.savePlaylist()

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        Label {
                            text: "Save"
                            Layout.fillWidth: true
                        }

                        Label {
                            text: "Ctrl + S"
                            opacity: 0.4
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
                topMargin: 40
                width: 250
                visible: false

                MenuItem {
                    text: "Refresh Server List"
                    onTriggered: serversToolButton.refreshServerData()
                }

                MenuItem {
                    text: "Invite Boxy to server"
                    enabled: root.connectedToAPI
                    onTriggered: {
                        let link = botBridge.get_invitation_link()
                        if (link) {
                            Qt.openUrlExternally(link)
                        }
                    }
                }

                MenuItem {
                    text: "Disconnect"
                    enabled: botBridge.voice_connected
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
                    title: modelData.name

                    Instantiator {
                        id: channelInstantiator
                        model: serversToolButton.serverData.channels[modelData.id] || []

                        delegate: MenuItem {
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
                                            'import QtQuick.Controls.Material; MenuItem { text: "No channels available"; enabled: false }',
                                            serverMenu,
                                            "noChannelsPlaceholder"
                                            )
                                serverMenu.addItem(serverMenu.noChannelsItem)
                            }
                        }

                        Component.onCompleted: {
                            if (count === 0) {
                                serverMenu.noChannelsItem = Qt.createQmlObject(
                                            'import QtQuick.Controls.Material; MenuItem { text: "No channels available"; enabled: false }',
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
                                    'import QtQuick.Controls.Material; MenuItem { text: "No servers available"; enabled: false }',
                                    serversMenu,
                                    "noServersPlaceholder"
                                    )
                        serversMenu.addItem(serversToolButton.noServersItem)
                    }
                }

                Component.onCompleted: {
                    if (count === 0) {
                        serversToolButton.noServersItem = Qt.createQmlObject(
                                    'import QtQuick.Controls.Material; MenuItem { text: "No servers available"; enabled: false }',
                                    serversMenu,
                                    "noServersPlaceholder"
                                    )
                        serversMenu.addItem(serversToolButton.noServersItem)
                    }
                }
            }
        }

        Item {
            anchors.right: themeSwitch.left
            height: 24
            width: 24
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: sunImage
                anchors.fill: parent
                source: "icons/sun.png"
                opacity: !themeSwitch.checked ? 1 : 0
                rotation: themeSwitch.checked ? 360 : 0
                mipmap: true

                Behavior on rotation {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 500 }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: themeSwitch.checked = !themeSwitch.checked
                }
            }

            Image {
                anchors.fill: parent
                id: moonImage
                source: "icons/moon.png"
                opacity: themeSwitch.checked ? 1 : 0
                rotation: themeSwitch.checked ? 360 : 0
                mipmap: true

                Behavior on rotation {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 100 }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: themeSwitch.checked = !themeSwitch.checked
                }
            }
        }

        Switch {
            anchors.right: parent.right
            height: 40
            id: themeSwitch
            checked: BoxySettings.darkMode
            onClicked: BoxySettings.darkMode = checked
            Layout.rightMargin: 10
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

        function onVoiceConnectedChanged(connected) {
            if (!connected) {
                playlistView.currentIndex = 0
            }
        }

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

        function onTitleResolved(index, title, url, channelName) {
            playlistModel.setProperty(index, "resolvedTitle", title)
            playlistModel.setProperty(index, "channelName", channelName)
            if (url) {
                playlistModel.setProperty(index, "url", url)
            }
            playlistModel.setProperty(index, "isResolving", false)
        }

        //function onBatchDownloadProgressChanged(current, total, status) {
        //    playlistDownloadProgress.from = 0
        //    playlistDownloadProgress.to = total
        //    playlistDownloadProgress.value = current
        //    newItemInput.placeholderText = status
        //}

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
            if (botBridge.disconnecting) {
                return;
            }

            if (loaded) {
                isAutoAdvancing = false
            }

            if (!loaded && !botBridge.repeat_mode && botBridge.media_session_active &&
                    !playlistView.manualNavigation && !isAutoAdvancing && !botBridge.disconnecting) {

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
                    playlistView.currentIndex = 0
                    isAutoAdvancing = false
                }
            }

            playlistView.manualNavigation = false
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 20
        anchors.margins: 20
        id: appLayout

        Pane {
            Layout.fillWidth: true
            Material.background: BoxySettings.darkMode ? "#2b2b2b" : "#FFFFFF"
            Material.elevation: 6
            Material.roundedScale: Material.ExtraSmallScale
            ColumnLayout {
                id: colLayout
                anchors.fill: parent
                anchors.margins: 5
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Label {
                            id: songLabel
                            text: botBridge.song_title || "No song playing"
                            Layout.fillWidth: true
                            Layout.preferredWidth: parent.width * 0.85
                            horizontalAlignment: Text.AlignLeft
                            elide: Text.ElideRight
                            font.pixelSize: 14
                            font.bold: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                        }

                        Label {
                            id: channelLabel
                            text: botBridge.channel_name || ""
                            Layout.fillWidth: true
                            Layout.preferredWidth: parent.width * 0.85
                            horizontalAlignment: Text.AlignLeft
                            elide: Text.ElideRight
                            font.pixelSize: 14
                            font.bold: false
                            wrapMode: Text.Wrap
                            maximumLineCount: 1
                        }
                    }

                    Image {
                        id: thumbnailImage
                        Layout.rowSpan: 2
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 96
                        fillMode: Image.PreserveAspectFit
                        property string currentUrl: botBridge.thumbnail_url || ""
                        property string processedUrl: currentUrl ? botBridge.process_thumbnail(currentUrl, 96, 6) : ""
                        source: processedUrl || (Material.theme === Material.Dark ?
                                                     "icons/placeholder_light.png" : "icons/placeholder_dark.png")
                        visible: true
                        asynchronous: true
                        cache: true
                        layer.smooth: true
                        Pane {
                            visible: thumbnailImage.processedUrl
                            Material.background: "transparent"
                            Material.elevation: 6
                            anchors.fill: parent
                            z: -1
                        }
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
                        to: botBridge.duration || 0
                        value: botBridge.position || 0
                        enabled: root.songLoaded && !downloadProgress.visible

                        onPressedChanged: {
                            if (!pressed) {
                                botBridge.seek(value)
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
                    Layout.leftMargin: -5
                    Layout.rightMargin: -5
                    spacing: 0

                    RowLayout {
                        spacing: 0
                        CustomRoundButton {
                            id: stopPlaylistButton
                            icon.source: "icons/stop.png"
                            Layout.preferredWidth: height
                            icon.width: 14
                            icon.height: 14
                            enabled: botBridge.media_session_active
                            onClicked: {
                                botBridge.stop_playing()
                                playlistView.currentIndex = 0
                            }
                        }

                        CustomRoundButton {
                            id: volumeButton
                            icon.source: {
                                if (BoxySettings.volume === 0) {
                                    return "icons/volume_muted.png"
                                } else if (BoxySettings.volume <= 0.50) {
                                    return "icons/volume_down.png"
                                } else if (BoxySettings.volume <= 1) {
                                    return "icons/volume_up.png"
                                } else {
                                    return "icons/volume_up.png"
                                }
                            }

                            Layout.preferredWidth: height
                            icon.width: 18
                            icon.height: 18
                            enabled: root.connectedToAPI
                            onClicked: {
                                volumePopup.open()
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    CustomRoundButton {
                        id: playPrevButton
                        icon.source: "icons/prev.png"
                        Layout.preferredWidth: height
                        icon.width: 14
                        icon.height: 14
                        enabled: playlistView.currentIndex > 0 && botBridge.media_session_active && !downloadProgress.visible
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

                    CustomRoundButton {
                        id: pauseButton
                        Layout.preferredWidth: implicitWidth + 8
                        Layout.preferredHeight: implicitHeight + 8
                        enabled: root.songLoaded && !downloadProgress.visible
                        icon.source: botBridge.is_playing ? "icons/pause.png" : "icons/play.png"
                        icon.width: 14
                        icon.height: 14
                        onClicked: {
                            botBridge.toggle_playback()
                        }
                    }

                    CustomRoundButton {
                        id: playNextButton
                        icon.source: "icons/next.png"
                        icon.width: 14
                        icon.height: 14
                        Layout.preferredWidth: height
                        enabled: playlistView.currentIndex < (playlistModel.count - 1) && botBridge.media_session_active && !downloadProgress.visible
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
                        spacing: 0
                        CustomRoundButton {
                            id: shuffleButton
                            Layout.preferredWidth: height
                            icon.source: "icons/shuffle.png"
                            icon.width: 16
                            icon.height: 16
                            checkable: true
                            highlighted: checked
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

                        CustomRoundButton {
                            id: repeatButton
                            Layout.preferredWidth: height
                            icon.source: "icons/repeat.png"
                            icon.width: 16
                            icon.height: 16
                            checkable: true
                            highlighted: checked
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
                Item {
                    Layout.preferredHeight: 0
                }
            }
        }

        Pane {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Material.background: BoxySettings.darkMode ? "#2B2B2B" : "#FFFFFF"
            Material.elevation: 6
            Material.roundedScale: Material.ExtraSmallScale

            ColumnLayout {
                id: playListViewLayout
                spacing: 10
                anchors.fill: parent
                anchors.margins: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    MaterialButton {
                        id: downloadAllButton
                        icon.source: "icons/download.png"
                        Material.roundedScale: Material.ExtraSmallScale
                        Layout.preferredWidth: height
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
                        Layout.preferredHeight: editButton.implicitHeight
                        //implicitHeight: 30
                        text: ""
                        placeholderText: "My super playlist"
                        Layout.fillWidth: true
                        onAccepted: {
                            if (saveButton.enabled) {
                                root.savePlaylist()
                            }
                        }
                    }

                    MaterialButton {
                        id: editButton
                        text: "Edit"
                        checkable: true
                        Material.roundedScale: Material.ExtraSmallScale
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
                            text: botBridge && botBridge.valid_token_format ? "Connecting to Discord API..." : "Incorrect token format"
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
                            id: scrlBar
                            policy: playlistView.contentHeight > playlistView.height ?
                                        ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                        }

                        delegate: ItemDelegate {
                            width: scrlBar.visible ? ListView.view.width - 30 : ListView.view.width
                            height: 50
                            enabled: !downloadProgress.visible && !root.isResolvingAny && !playlistDownloadProgress.visible
                            onClicked: {
                                if (model.index !== playlistView.currentIndex || !botBridge.is_playing) {
                                    playlistView.manualNavigation = true
                                    playlistView.currentIndex = model.index
                                    let item = playlistModel.get(model.index)
                                    if (shuffleButton.checked) {
                                        shufflePlayedIndices = [model.index]
                                    }
                                    botBridge.play_url(item.url || item.userTyped)
                                }
                            }

                            Rectangle {
                                width: 3
                                height: parent.height * 0.8
                                color: Material.accent
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

                                    MaterialButton {
                                        id: moveUpButton
                                        icon.source: "icons/up.png"
                                        icon.width: 14
                                        icon.height: 14
                                        Layout.preferredHeight: 16
                                        Layout.preferredWidth: 40
                                        Material.roundedScale: Material.NotRounded
                                        enabled: model.index > 0
                                        onClicked: {
                                            let currentItem = {
                                                userTyped: playlistModel.get(model.index).userTyped,
                                                url: playlistModel.get(model.index).url,
                                                resolvedTitle: playlistModel.get(model.index).resolvedTitle,
                                                channelName: playlistModel.get(model.index).channelName,
                                                isResolving: playlistModel.get(model.index).isResolving
                                            }

                                            let aboveIndex = model.index - 1
                                            let aboveItem = {
                                                userTyped: playlistModel.get(aboveIndex).userTyped,
                                                url: playlistModel.get(aboveIndex).url,
                                                resolvedTitle: playlistModel.get(aboveIndex).resolvedTitle,
                                                channelName: playlistModel.get(aboveIndex).channelName,
                                                isResolving: playlistModel.get(aboveIndex).isResolving
                                            }

                                            playlistModel.set(aboveIndex, currentItem)
                                            playlistModel.set(model.index, aboveItem)

                                            if (playlistView.currentIndex === model.index) {
                                                playlistView.currentIndex--
                                            } else if (playlistView.currentIndex === model.index - 1) {
                                                playlistView.currentIndex++
                                            }
                                        }
                                    }

                                    MaterialButton {
                                        id: moveDownButton
                                        icon.source: "icons/down.png"
                                        icon.width: 14
                                        icon.height: 14
                                        Layout.preferredHeight: 16
                                        Layout.preferredWidth: 40
                                        Material.roundedScale: Material.NotRounded
                                        enabled: model.index < playlistModel.count - 1
                                        onClicked: {
                                            let currentItem = {
                                                userTyped: playlistModel.get(model.index).userTyped,
                                                url: playlistModel.get(model.index).url,
                                                resolvedTitle: playlistModel.get(model.index).resolvedTitle,
                                                channelName: playlistModel.get(model.index).channelName,
                                                isResolving: playlistModel.get(model.index).isResolving
                                            }

                                            let belowIndex = model.index + 1
                                            let belowItem = {
                                                userTyped: playlistModel.get(belowIndex).userTyped,
                                                url: playlistModel.get(belowIndex).url,
                                                resolvedTitle: playlistModel.get(belowIndex).resolvedTitle,
                                                channelName: playlistModel.get(belowIndex).channelName,
                                                isResolving: playlistModel.get(belowIndex).isResolving
                                            }

                                            playlistModel.set(belowIndex, currentItem)
                                            playlistModel.set(model.index, belowItem)

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
                                    Layout.preferredHeight: 36
                                    Layout.preferredWidth: 36
                                    Layout.rightMargin: 10
                                }

                                BusyIndicator {
                                    id: downloadingIndicator
                                    visible: model.isDownloading
                                    running: visible
                                    Layout.preferredHeight: 36
                                    Layout.preferredWidth: 36
                                    Layout.rightMargin: 10
                                }

                                CustomRoundButton {
                                    icon.source: "icons/delete.png"
                                    icon.width: 12
                                    icon.height: 12
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
                    visible: botBridge.placeholder_status !== "" &&
                             botBridge.placeholder_status !== "Downloading playlist items..." &&
                             botBridge.placeholder_status !== "Download complete!" &&
                             botBridge.placeholder_status !== "All items already cached"
                }

                ProgressBar {
                    id: playlistDownloadProgress
                    Layout.fillWidth: true
                    visible: botBridge.placeholder_status === "Downloading playlist items..."
                    from: 0
                    to: botBridge.bulk_total
                    value: botBridge.bulk_current
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    TextField {
                        id: newItemInput
                        Layout.preferredHeight: editButton.implicitHeight
                        Layout.fillWidth: true
                        placeholderText: botBridge.placeholder_status !== "" ? botBridge.placeholder_status : "Enter YouTube URL or search term"
                        enabled: root.connectedToAPI
                        //Material.containerStyle: Material.Filled

                        onAccepted: addButton.clicked()
                    }

                    CustomRoundButton {
                        id: addButton
                        icon.source: "icons/plus.png"
                        Layout.preferredWidth: height
                        icon.width: 16
                        icon.height: 16
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
        anchors.centerIn: parent
        parent: playlistView
    }

    LoadPopup {
        id: playlistSelectorPopup
        anchors.centerIn: parent
    }

    PlaylistPromptPopup {
        id: playlistPopup
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
        anchors.centerIn: parent
    }

    DownloadMessagePopup {
        id: downloadMessagePopup
        parent: playlistView
        anchors.centerIn: parent
    }

    CacheSettingsPopup {
        id: cacheSettingsPopup
        anchors.centerIn: parent
    }

    GeneralConfigPopup {
        id: generalConfigPopup
        anchors.centerIn: parent
    }

    IssuePopup {
        id: issuePopup
        anchors.centerIn: parent
        parent: playlistView
        Connections {
            target: botBridge

            function onIssue(message) {
                issuePopup.displayText = message
                issuePopup.open()
            }
        }
    }

    Popup {
        id: volumePopup
        x: (parent.width - width) / 2   
        y: 10                             
        height: 40
        width: implicitWidth
        Material.elevation: 10
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Slider {
            id: volumeSlider
            anchors.leftMargin: -5
            anchors.rightMargin: -5
            anchors.fill: parent
            from: 0.0
            to: 1.0
            value: BoxySettings.volume
            enabled: root.connectedToAPI
            onValueChanged: {
                BoxySettings.volume = value
                botBridge.set_volume(value)
            }
        }
    }
}