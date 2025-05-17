import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Material

ApplicationWindow {
    id: setupWindow
    visible: true
    width: lyt.implicitWidth * 1.65
    height: lyt.implicitHeight + 30 + 40
    minimumWidth: lyt.implicitWidth * 1.65
    minimumHeight: lyt.implicitHeight + 30 + 40
    title: "Boxy Discord Bot Setup"
    Material.theme: BoxySettings.darkMode ? Material.Dark : Material.Light
    Material.accent: Material.Pink
    Material.primary: Material.Indigo
    color: BoxySettings.darkMode ? "#1C1C1C" : "#E3E3E3"
    header: ToolBar {
        height: 40
        Label {
            anchors.centerIn: parent
            text: "Boxy Discord Bot Setup"
            font.pixelSize: 14
            font.bold: true
        }
    }
}