import QtQuick
import QtQuick.Controls.Material
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
            totalCachedSize = size
            cachedItemsCount = count
            cacheLocation = location
        }

        function onStatusChanged(status) {
            if (status === "") {
                refreshCacheInfo()
            }
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15

        RowLayout {
            Layout.preferredHeight: 30
            spacing: 10

            Label {
                text: "Cached items:"
                Layout.fillWidth: true
                font.bold: true
            }
            Label {
                text: cachedItemsCount.toString()
            }
        }

        RowLayout {
            Layout.preferredHeight: 30
            spacing: 10

            Label {
                text: "Total size:"
                Layout.fillWidth: true
                font.bold: true
            }
            Label {
                text: formatBytes(totalCachedSize)
            }
        }

        RowLayout {
            Layout.preferredHeight: 30
            spacing: 10

            Label {
                text: "Maximum cache size:"
                Layout.preferredWidth: implicitWidth + 50
                Layout.fillWidth: true
                font.bold: true
            }

            SpinBox {
                id: cacheSizeSpinBox
                from: 100
                to: 10000
                stepSize: 100
                value: BoxySettings.maxCacheSize
                editable: true
                Layout.preferredHeight: 30

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
                text: "Parallel downloads:"
                Layout.fillWidth: true
                font.bold: true
            }

            SpinBox {
                id: parallelDownloadsSpinBox
                from: 1
                to: 8
                stepSize: 1
                Layout.preferredHeight: 30
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
            Layout.preferredHeight: 30
            spacing: 10

            Label {
                text: "Clear cache on exit:"
                Layout.fillWidth: true
                font.bold: true
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
                text: "Clear Cache Now"
                onClicked: {
                    botBridge.clear_cache()
                    refreshCacheInfo()
                }
            }

            MaterialButton {
                id: openBtn
                Layout.preferredWidth: parent.buttonWidth
                Layout.fillWidth: true
                text: "Open cache folder"
                onClicked: Qt.openUrlExternally(getFileUrl(botBridge.get_cache_directory()))
            }
        }
    }
}
