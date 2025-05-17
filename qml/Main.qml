import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Effects

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
    Material.accent: Colors.accentColor
    Material.primary: Colors.primaryColor
    color: Colors.backgroundColor
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

    SmoothProgressBar {
        id: leftAudioLevelMeter
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        from: 0.0
        to: 1.0
        value: botBridge.audio_level
        visible: root.songLoaded && (BoxySettings.vumeterIndex === 1 || BoxySettings.vumeterIndex === 2)
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
                    font.bold: true
                    text: "Settings"
                    onTriggered: configurationWindow.show()
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
    }

    function formatTime(seconds) {
        var minutes = Math.floor(seconds / 60)
        var remainingSeconds = Math.floor(seconds % 60)
        return minutes + ":" + (remainingSeconds < 10 ? "0" : "") + remainingSeconds
    }

    function savePlaylist() {
        if (playlistName.text.trim() === "") {
            notificationPopup.displayText = "You must name the playlist"
            notificationPopup.visible = true
            return
        } else if (!playlistModel.count > 0) {
            notificationPopup.displayText = "Cannot save empty playlist"
            notificationPopup.visible = true
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
            notificationPopup.displayText = "Playlist saved successfully"
            notificationPopup.visible = true
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
                    !isAutoAdvancing && !botBridge.disconnecting) {

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
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 20
        anchors.margins: 20
        id: appLayout

        Pane {
            Layout.fillWidth: true
            Material.background: Colors.paneColor
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
                        RectangularShadow {
                            visible: thumbnailImage.processedUrl && (BoxySettings.vumeterIndex === 0 || BoxySettings.vumeterIndex === 2)
                            anchors.fill: parent
                            anchors.margins: -4
                            blur: 24
                            spread: 4
                            color: Material.accent
                            z: -1
                            opacity: botBridge.audio_level
                            radius: 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutQuad
                                }
                            }
                            offset: Qt.vector2d(0.0, 0.0)
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
                        enabled: root.songLoaded && !downloadProgress.visible && botBridge.seeking_enabled
                        onPressedChanged: {
                            if (pressed) {
                                botBridge.stopTimerSignal() 
                            } else {
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
                                    const prevIndex = shufflePlayedIndices[currentPos - 1]
                                    playlistView.currentIndex = prevIndex
                                    let item = playlistModel.get(prevIndex)
                                    botBridge.play_url(item.url || item.userTyped)
                                }
                            } else {
                                if (playlistView.currentIndex > 0) {
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

                                shufflePlayedIndices.push(nextIndex)
                                playlistView.currentIndex = nextIndex
                                let item = playlistModel.get(nextIndex)
                                botBridge.play_url(item.url || item.userTyped)
                            } else {
                                if (playlistView.currentIndex < (playlistModel.count - 1)) {
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
            Material.background: Colors.paneColor
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
                            notificationPopup.displayText = "Downloading any non cached files"
                            notificationPopup.visible = true
                        }
                    }

                    TextField {
                        id: playlistName
                        Layout.preferredHeight: editButton.implicitHeight
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
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {
                            id: scrlBar
                            policy: playlistView.contentHeight > playlistView.height ?
                                        ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            property bool shown: policy === ScrollBar.AlwaysOn
                        }

                        delegate: ItemDelegate {
                            width: scrlBar.shown ? ListView.view.width - 30 : ListView.view.width
                            height: 50
                            enabled: !downloadProgress.visible && !root.isResolvingAny && !playlistDownloadProgress.visible
                            MouseArea {
                                anchors.fill: parent
                                onDoubleClicked: {
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
                                radius: 8
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

                SmoothProgressBar {
                    id: downloadProgress
                    Layout.fillWidth: true
                    indeterminate: botBridge.resolving
                    visible: botBridge.resolving || botBridge.downloading
                    from: 0
                    to: botBridge.download_progress_total
                    value: botBridge.download_progress
                }

                SmoothProgressBar {
                    id: playlistDownloadProgress
                    Layout.fillWidth: true
                    visible: botBridge.bulk_current !== botBridge.bulk_total
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

    NotificationPopup {
        id: notificationPopup
        anchors.centerIn: parent
        parent: playlistView
        Connections {
            target: botBridge

            function onIssue(message) {
                notificationPopup.displayText = message
                notificationPopup.open()
            }
        }
    }

    VolumePopup {
        id: volumePopup
        x: (parent.width - width) / 2   
        y: 10                             
    }
    
    ConfigurationWindow {
        id: configurationWindow
        visible: false
    }
}