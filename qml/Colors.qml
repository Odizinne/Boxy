pragma Singleton
import QtQuick
import QtQuick.Controls.Material

QtObject {
    id: root
    
    readonly property var colorPairs: [
        ["#5D9CEC", "#3A5E8C", "#4A89DC", "#2D4A70"], // Electric Blue family
        ["#FF7043", "#BF4B2C", "#FF5722", "#A63E25"], // Deep Orange family
        ["#26C6DA", "#0E7C87", "#00BCD4", "#0A6673"], // Cyan family
        ["#AB47BC", "#6A2C73", "#9C27B0", "#5C1769"], // Purple family
        ["#FFCA28", "#C79A00", "#FFC107", "#A67F00"], // Amber family
        ["#66BB6A", "#407C42", "#4CAF50", "#366E38"], // Green family
        ["#EC407A", "#AD2A54", "#E91E63", "#8E2249"], // Pink family
        ["#29B6F6", "#1A6F94", "#03A9F4", "#156F85"], // Light Blue family
        ["#FFA726", "#BF7D1E", "#FF9800", "#A66400"], // Orange family
        ["#78909C", "#4C5A63", "#607D8B", "#3E515A"]  // Blue Grey family
    ]
    
    readonly property int currentIndex: BoxySettings.accentColorIndex % 10
    readonly property bool isDarkTheme: BoxySettings.darkMode
    readonly property color accentColor: isDarkTheme ?
                                        colorPairs[currentIndex][2] :
                                        colorPairs[currentIndex][0]
    readonly property color primaryColor: isDarkTheme ?
                                         colorPairs[currentIndex][3] :
                                         colorPairs[currentIndex][1]           
    readonly property color primaryForeground: "white"
    readonly property color backgroundColor: isDarkTheme ? "#1C1C1C" : "#E3E3E3"
    readonly property color paneColor: isDarkTheme ? "#2B2B2B" : "#FFFFFF"
    
    property Connections settingsConnections: Connections {
        target: BoxySettings
        function onDarkModeChanged() {
            root.isDarkThemeChanged()
        }
    }
}