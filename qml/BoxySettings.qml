pragma Singleton
import QtCore
import QtQuick

Settings {
    id: settings
    property bool shuffle: false
    property bool repeat: false
    property string lastServer: ""
    property string lastChannel: ""
    property bool clearCacheOnExit: false
    property int maxCacheSize: 1024 
    property string accentColor: "#00CC6A"
    property bool darkMode: true
}