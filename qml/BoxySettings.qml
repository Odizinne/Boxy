pragma Singleton
import QtCore

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
    property double volume: 0.8
    property string autoJoinUserId: ""
    property int accentColorIndex: 5
}
