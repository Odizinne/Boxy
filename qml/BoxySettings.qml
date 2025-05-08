pragma Singleton
import QtCore
import QtQuick

Settings {
    id: settings
    property bool shuffle: false
    property bool repeat: false
    property bool clearCacheOnExit: false
    property int maxCacheSize: 1024 
    property int accentColor: 1
    property int primaryColor: 4
    property bool darkMode: true
    property int maxParallelDownloads: 3
}
