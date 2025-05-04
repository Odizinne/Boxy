pragma Singleton
import QtCore

Settings {
    id: settings
    property bool shuffle: false
    property bool repeat: false
    property string lastServer: ""
    property string lastChannel: ""
    property bool clearCacheOnExit: false
    property int maxCacheSize: 1024  // MB
}