import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Universal
import Qt.labs.platform as Platform
import QtCore
import QtQuick.Templates as T

import "."

ApplicationWindow {
    visible: true
    id: root
    width: 850
    height: 446
    minimumWidth: 850
    minimumHeight: 486
    title: "Boxy GUI"
    Universal.theme: Universal.Dark
    Universal.accent: Universal.Orange
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
        enabled: playlistName.text.trim() !== "" && playlistModel.count > 0 && !root.isResolvingAny
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
            height: 30
            text: "File"
            onClicked: mainMenu.visible = !mainMenu.visible
            Menu {
                id: mainMenu
                title: qsTr("File")
                width: 150
                visible: false
                enter: Transition {
                    NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; easing.type: Easing.Linear; duration: 110 }
                }
                exit: Transition {
                    NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; easing.type: Easing.Linear; duration: 110 }
                }

                CustomMenuItem {
                    height: 35
                    text: "Cache settings"
                    onTriggered: cacheSettingsPopup.open()
                }

                CustomMenuItem {
                    height: 35
                    text: "Edit token"
                    onTriggered: tokenPopup.open()
                }
                MenuSeparator {}

                CustomMenuItem {
                    height: 35
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
            height: 30
            text: "Playlist"
            onClicked: playlistMenu.visible = !playlistMenu.visible
            Menu {
                id: playlistMenu
                title: qsTr("Playlist")
                width: 150
                visible: false
                enter: Transition {
                    NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; easing.type: Easing.Linear; duration: 110 }
                }
                exit: Transition {
                    NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; easing.type: Easing.Linear; duration: 110 }
                }

                CustomMenuItem {
                    height: 35
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
                    height: 35
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
                    height: 35
                    enabled: playlistName.text.trim() !== "" && playlistModel.count > 0 && !root.isResolvingAny
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
    }

    function formatTime(seconds) {
        var minutes = Math.floor(seconds / 60)
        var remainingSeconds = Math.floor(seconds % 60)
        return minutes + ":" + (remainingSeconds < 10 ? "0" : "") + remainingSeconds
    }

    function savePlaylist() {
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
        savePopup.visible = true
    }

    Connections {
        target: botBridge

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
                                         "isResolving": !item.resolvedTitle || !item.url || !item.channelName
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

    GridLayout {
        anchors.fill: parent
        columnSpacing: 20
        rowSpacing: 20
        anchors.margins: 14
        columns: 2
        rows: 2
        id: appLayout

        Frame {
            Layout.fillHeight: true
            Layout.preferredWidth: parent.width * 0.55
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
                             newItemInput.placeholderText !== "Downloading playlist items..."
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
        }

        Frame {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: parent.width * 0.45

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
                        property int idealSize: parent.width * 0.30
                        Layout.preferredWidth: idealSize
                        Layout.preferredHeight: idealSize
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
                        icon.width: 24
                        icon.height: 24

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

        Frame {
            Layout.preferredHeight: implicitHeight
            Layout.fillWidth: true
            GridLayout {
                anchors.fill: parent
                columnSpacing: 10
                rowSpacing: 10
                columns: 2

                Label {
                    text: "Serv:"
                    Layout.preferredWidth: pauseButton.width
                    Layout.alignment: Qt.AlignVCenter
                }

                ComboBox {
                    id: serverComboBox
                    Layout.fillWidth: true
                    enabled: root.connectedToAPI
                    textRole: "name"
                    valueRole: "id"
                    model: []

                    onCurrentValueChanged: {
                        if (currentValue) {
                            botBridge.set_current_server(currentValue)
                        }
                    }

                    onActivated: {
                        if (currentText) {
                            BoxySettings.lastServer = currentText
                        }
                    }

                    Connections {
                        target: botBridge
                        function onServersChanged(servers) {
                            serverComboBox.model = servers
                            if (servers.length > 0) {
                                let lastServerIndex = servers.findIndex(server => server.name === BoxySettings.lastServer)
                                serverComboBox.currentIndex = lastServerIndex >= 0 ? lastServerIndex : 0
                                botBridge.set_current_server(servers[serverComboBox.currentIndex].id)
                            }
                        }
                    }
                }

                Label {
                    id: channelListLabel
                    text: "Chan:"
                    Layout.preferredWidth: pauseButton.width
                    Layout.alignment: Qt.AlignVCenter
                }

                ComboBox {
                    id: channelComboBox
                    Layout.fillWidth: true
                    enabled: root.connectedToAPI && model.length > 0
                    textRole: "name"
                    valueRole: "id"
                    model: []

                    onCurrentValueChanged: {
                        if (currentValue) {
                            botBridge.set_current_channel(currentValue)
                        }
                    }

                    onActivated: {
                        if (currentText) {
                            BoxySettings.lastChannel = currentText
                        }
                    }

                    Connections {
                        target: botBridge
                        function onChannelsChanged(channels) {
                            channelComboBox.model = channels
                            if (channels.length > 0) {
                                let lastChannelIndex = channels.findIndex(channel => channel.name === BoxySettings.lastChannel)
                                channelComboBox.currentIndex = lastChannelIndex >= 0 ? lastChannelIndex : 0
                            }
                        }
                    }
                }

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

                Button {
                    id: disconnectButton
                    text: botBridge && botBridge.voiceConnected ? "Disconnect from channel" : "Connect to channel"
                    Layout.fillWidth: true
                    enabled: root.connectedToAPI && channelComboBox.currentValue !== undefined && channelComboBox.currentValue !== null
                    onClicked: {
                        if (botBridge.voiceConnected) {
                            botBridge.disconnect_voice()
                        } else {
                            botBridge.connect_to_channel()
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
                        "isResolving": true
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
}
