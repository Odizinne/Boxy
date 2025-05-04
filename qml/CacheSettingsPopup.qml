import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import "."

AnimatedPopup {
    property int totalCachedSize: 0
    property int cachedItemsCount: 0
    property string cacheLocation: ""
    modal: true
    
    Component.onCompleted: {
        refreshCacheInfo()
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
    
    Connections {
        target: botBridge
        function onCacheInfoUpdated(size, count, location) {
            totalCachedSize = size
            cachedItemsCount = count
            cacheLocation = location
        }

        function onDownloadStatusChanged(status) {
            if (status === "") {
                refreshCacheInfo()
            }
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: 20

        Frame {
            Layout.fillWidth: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 15

                RowLayout {
                    Layout.preferredHeight: 30
                    spacing: 10

                    Label {
                        text: "Cached items:"
                        Layout.fillWidth: true
                    }
                    Label {
                        text: cachedItemsCount.toString()
                        font.bold: true
                    }
                }

                RowLayout {
                    Layout.preferredHeight: 30
                    spacing: 10

                    Label {
                        text: "Total size:"
                        Layout.fillWidth: true
                    }
                    Label {
                        text: formatBytes(totalCachedSize)
                        font.bold: true
                    }
                }

                RowLayout {
                    Layout.preferredHeight: 30
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

                        onValueModified: {
                            BoxySettings.maxCacheSize = value
                            botBridge.set_cache_settings(BoxySettings.maxCacheSize, 30)
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
                    Layout.preferredHeight: 30
                    spacing: 10

                    Label {
                        text: "Clear cache on exit:"
                        Layout.fillWidth: true
                    }

                    Switch {
                        id: clearCacheSwitch
                        checked: BoxySettings.clearCacheOnExit

                        onCheckedChanged: {
                            BoxySettings.clearCacheOnExit = checked
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            property int buttonWidth: Math.max(clearBtn.implicitWidth, openBtn.implicitWidth)

            Button {
                id: clearBtn
                Layout.preferredWidth: parent.buttonWidth
                Layout.fillWidth: true
                text: "Clear Cache Now"
                onClicked: {
                    botBridge.clear_cache()
                    refreshCacheInfo()
                }
            }

            Button {
                id: openBtn
                Layout.preferredWidth: parent.buttonWidth
                Layout.fillWidth: true
                text: "Open cache folder"
                onClicked: Qt.openUrlExternally("file:///" + botBridge.get_cache_directory())
            }
        }
    }
}
