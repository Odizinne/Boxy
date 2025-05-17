import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Material

ApplicationWindow {
    id: configurationWindow
    visible: true
    width: lyt.implicitWidth + 30 + 16
    height: 700
    minimumWidth: lyt.implicitWidth + 30 + 16
    maximumWidth: lyt.implicitWidth + 30 + 16
    minimumHeight: 700
    maximumHeight: 700
    transientParent: null
    Material.theme: BoxySettings.darkMode ? Material.Dark : Material.Light
    Material.accent: Colors.accentColor
    Material.primary: Colors.primaryColor
    color: Colors.backgroundColor
    header: ToolBar {
        height: 40
        Material.elevation: 8
        Label {
            anchors.centerIn: parent
            text: "Boxy Settings"
            font.pixelSize: 14
            font.bold: true
        }
    }

    property int totalCachedSize: 0
    property int cachedItemsCount: 0
    property string cacheLocation: ""
    property string currentToken: ""
    property string currentUserId: ""

    Component.onCompleted: {
        refreshCacheInfo()
        tokenInput.text = botBridge.get_token()
        currentToken = tokenInput.text
        userIdInput.text = BoxySettings.autoJoinUserId || ""
        currentUserId = userIdInput.text
    }

    function formatBytes(bytes) {
        if (bytes === 0) return '0 B'
        
        const k = 1024
        const sizes = ['B', 'KB', 'MB', 'GB']
        const i = Math.floor(Math.log(bytes) / Math.log(k))
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
    }
    
    function refreshCacheInfo() {
        let cacheInfo = botBridge.get_cache_info()
        totalCachedSize = cacheInfo.total_size
        cachedItemsCount = cacheInfo.file_count
        cacheLocation = cacheInfo.cache_location
    }
    
    function getFileUrl(path) {
        let cleanPath = path
        while (cleanPath.endsWith("/") || cleanPath.endsWith("\\")) {
            cleanPath = cleanPath.slice(0, -1)
        }
        
        if (cleanPath.includes(":\\")) {
            return "file:///" + cleanPath
        } else {
            return "file://" + cleanPath
        }
    }
    
    Connections {
        target: botBridge
        function onCacheInfoUpdated(size, count, location) {
            configurationWindow.totalCachedSize = size
            configurationWindow.cachedItemsCount = count
            configurationWindow.cacheLocation = location
        }

        function onStatusChanged(status) {
            if (status === "") {
                configurationWindow.refreshCacheInfo()
            }
        }
    }

    ScrollView {
        id: scrlView
        width: container.width
        height: Math.min(parent.height, container.height)
        contentWidth: container.width
        contentHeight: container.height
        anchors.fill: parent
        ScrollBar.vertical.policy: ScrollBar.AlwaysOn

        Item {
            id: container
            width: lyt.implicitWidth + 30
            height: lyt.implicitHeight + 30
            anchors.fill: parent

            ColumnLayout {
                id: lyt
                anchors.fill: parent
                anchors.margins: 15
                spacing: 20

                Label {
                    text: "Ui settings"
                    Layout.bottomMargin: -15
                    Layout.leftMargin: 10
                    color: Material.accent
                }
                Pane {
                    Layout.fillWidth: true
                    Material.background: Colors.paneColor
                    Layout.preferredWidth: 450
                    Layout.preferredHeight: implicitHeight + 20
                    Material.elevation: 6
                    Material.roundedScale: Material.ExtraSmallScale
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 15
                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "Dark mode"
                                Layout.fillWidth: true
                            }
                            Item {
                                Layout.preferredHeight: 24
                                Layout.preferredWidth: 24

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
                                id: themeSwitch
                                checked: BoxySettings.darkMode
                                onClicked: BoxySettings.darkMode = checked
                                Layout.rightMargin: -10
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Label {
                                text: "Color"
                                Layout.fillWidth: true
                            }

                            ColumnLayout {
                                spacing: 8

                                RowLayout {
                                    spacing: 8

                                    Repeater {
                                        model: 5

                                        Rectangle {
                                            width: 30
                                            height: 30
                                            radius: 5
                                            color: Colors.colorPairs[index][0] 
                                            border.width: BoxySettings.accentColorIndex === index ? 2 : 0
                                            border.color: BoxySettings.darkMode ? "#FFFFFF" : "#000000"

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: BoxySettings.accentColorIndex = index
                                                cursorShape: Qt.PointingHandCursor
                                            }

                                            Behavior on border.width {
                                                NumberAnimation { duration: 100 }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 8

                                    Repeater {
                                        model: 5

                                        Rectangle {
                                            width: 30
                                            height: 30
                                            radius: 5

                                            color: Colors.colorPairs[index + 5][0]
                                            border.width: BoxySettings.accentColorIndex === (index + 5) ? 2 : 0
                                            border.color: BoxySettings.darkMode ? "#FFFFFF" : "#000000"

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: BoxySettings.accentColorIndex = index + 5
                                                cursorShape: Qt.PointingHandCursor
                                            }

                                            Behavior on border.width {
                                                NumberAnimation { duration: 100 }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "VUMeter"
                                Layout.fillWidth: true
                            }

                            ComboBox {
                                model: ["Art shadow", "TopBar", "Art shadow + TopBar", "None"]
                                currentIndex: BoxySettings.vumeterIndex
                                onActivated: BoxySettings.vumeterIndex = currentIndex
                                Layout.preferredHeight: 35
                            }
                        }
                    }
                }
                Label {
                    text: "Cache settings"
                    Layout.bottomMargin: -15
                    Layout.leftMargin: 10
                    color: Material.accent
                }
                Pane {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 450
                    Layout.preferredHeight: implicitHeight + 20
                    Material.background: Colors.paneColor
                    Material.elevation: 6
                    Material.roundedScale: Material.ExtraSmallScale
                    ColumnLayout {
                        id: contentColumn
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 15

                        RowLayout {
                            Layout.preferredHeight: 35
                            spacing: 10

                            Label {
                                text: "Cached items:"
                                Layout.fillWidth: true
                            }
                            Label {
                                text: configurationWindow.cachedItemsCount.toString()
                            }
                        }

                        RowLayout {
                            Layout.preferredHeight: 35
                            spacing: 10

                            Label {
                                text: "Total size:"
                                Layout.fillWidth: true
                            }
                            Label {
                                text: configurationWindow.formatBytes(configurationWindow.totalCachedSize)
                            }
                        }

                        RowLayout {
                            Layout.preferredHeight: 35
                            spacing: 10

                            Label {
                                text: "Maximum cache size:"
                                Layout.preferredWidth: implicitWidth + 50
                                Layout.fillWidth: true
                            }

                            SpinBox {
                                id: cacheSizeSpinBox
                                from: 100
                                to: 10000
                                stepSize: 100
                                value: BoxySettings.maxCacheSize
                                editable: true
                                Layout.preferredHeight: 35

                                onValueModified: {
                                    BoxySettings.maxCacheSize = value
                                }

                                textFromValue: function(value, locale) {
                                    return value + " MB"
                                }

                                valueFromText: function(text, locale) {
                                    return parseInt(text)
                                }
                            }
                        }

                        RowLayout {
                            Layout.preferredHeight: 35
                            spacing: 10

                            Label {
                                text: "Parallel downloads:"
                                Layout.fillWidth: true
                            }

                            SpinBox {
                                id: parallelDownloadsSpinBox
                                from: 1
                                to: 8
                                stepSize: 1
                                Layout.preferredHeight: 35
                                value: BoxySettings.maxParallelDownloads
                                editable: true

                                onValueModified: {
                                    BoxySettings.maxParallelDownloads = value
                                }

                                textFromValue: function(value, locale) {
                                    return value.toString()
                                }

                                valueFromText: function(text, locale) {
                                    return parseInt(text)
                                }
                            }
                        }

                        RowLayout {
                            Layout.preferredHeight: 35
                            spacing: 10

                            Label {
                                text: "Clear cache on exit:"
                                Layout.fillWidth: true
                            }

                            Switch {
                                id: clearCacheSwitch
                                checked: BoxySettings.clearCacheOnExit
                                Layout.rightMargin: -5
                                onCheckedChanged: {
                                    BoxySettings.clearCacheOnExit = checked
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            property int buttonWidth: Math.max(clearBtn.implicitWidth, openBtn.implicitWidth)

                            MaterialButton {
                                id: clearBtn
                                Layout.preferredWidth: parent.buttonWidth
                                Layout.fillWidth: true
                                Material.roundedScale: Material.ExtraSmallScale
                                text: "Clear Cache Now"
                                onClicked: {
                                    botBridge.clear_cache()
                                    configurationWindow.refreshCacheInfo()
                                }
                            }

                            MaterialButton {
                                id: openBtn
                                Layout.preferredWidth: parent.buttonWidth
                                Layout.fillWidth: true
                                Material.roundedScale: Material.ExtraSmallScale
                                text: "Open cache folder"
                                onClicked: Qt.openUrlExternally(configurationWindow.getFileUrl(botBridge.get_cache_directory()))
                            }
                        }
                    }
                }
                Label {
                    text: "Discord bot token"
                    Layout.bottomMargin: -15
                    Layout.leftMargin: 10
                    color: Material.accent
                }
                Pane {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 450
                    Layout.preferredHeight: implicitHeight + 20
                    Material.background: Colors.paneColor
                    Material.elevation: 6
                    Material.roundedScale: Material.ExtraSmallScale
                    ColumnLayout {
                        id: tokenLayout
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 15

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            TextField {
                                id: tokenInput
                                Layout.fillWidth: true
                                placeholderText: "Enter your Discord bot token"
                                echoMode: TextInput.Password
                                selectByMouse: true
                                Layout.preferredHeight: 35
                            }

                            CustomRoundButton {
                                flat: true
                                icon.source: "icons/reveal.png"
                                icon.width: 20
                                icon.height: 20
                                Layout.rightMargin: -10

                                onClicked: {
                                    if (tokenInput.echoMode === TextInput.Password) {
                                        tokenInput.echoMode = TextInput.Normal
                                    } else {
                                        tokenInput.echoMode = TextInput.Password
                                    }
                                }
                            }
                        }

                        Label {
                            text: "⚠️ Never share your bot token with anyone"
                            opacity: 0.7
                            color: Material.foreground
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }

                        MaterialButton {
                            id: saveButton
                            text: "Save and reconnect"
                            Material.roundedScale: Material.ExtraSmallScale
                            highlighted: true
                            enabled: tokenInput.text.trim() !== "" && tokenInput.text !== configurationWindow.currentToken
                            onClicked: {
                                botBridge.save_token(tokenInput.text.trim())
                                configurationWindow.close()
                            }
                        }
                    }
                }
                Label {
                    text: "Auto-join user's channel"
                    Layout.bottomMargin: -15
                    Layout.leftMargin: 10
                    color: Material.accent
                }
                Pane {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 450
                    Layout.preferredHeight: implicitHeight + 20
                    Material.background: Colors.paneColor
                    Material.elevation: 6
                    Material.roundedScale: Material.ExtraSmallScale
                    ColumnLayout {
                        id: configLayout
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 15

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Label {
                                text: "If not connected when starting a song, try to join the person with this user ID:"
                                Layout.fillWidth: true
                                font.bold: true
                                wrapMode: Text.WordWrap
                                Layout.bottomMargin: 12
                            }

                            TextField {
                                id: userIdInput
                                Layout.fillWidth: true
                                placeholderText: "Enter Discord User ID"
                                selectByMouse: true
                                Layout.preferredHeight: 35
                                validator: RegularExpressionValidator { regularExpression: /^\d*$/ }
                                onTextChanged: {
                                    if (!/^\d*$/.test(text)) {
                                        var cursorPos = cursorPosition
                                        text = text.replace(/\D/g, '')
                                        cursorPosition = cursorPos - (text.length - text.length)
                                        BoxySettings.autoJoinUserId = text
                                    }
                                }
                            }

                            Label {
                                text: "The Discord user ID is a unique number identifying each user. To get it, enable Developer Mode in Discord settings, then right-click a user and select 'Copy ID'."
                                font.pixelSize: 12
                                opacity: 0.5
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }
}
