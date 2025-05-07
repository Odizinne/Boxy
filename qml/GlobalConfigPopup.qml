import QtQuick.Controls.Universal
import QtQuick
import QtQuick.Layouts
import "."

AnimatedPopup {
    modal: true
    ColumnLayout {
        anchors.fill: parent
        spacing: 15
        
        RowLayout {
            Label {
                text: "UI color"
                Layout.alignment: Qt.AlignLeft
                Layout.preferredWidth: 130
                font.bold: true
            }

            ButtonGroup {
                id: colorButtonGroup
            }

            GridLayout {
                id: colorGrid
                columns: 6
                rowSpacing: 8
                columnSpacing: 8
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: ListModel {
                        ListElement { color: "#FFA500" } // Orange
                        ListElement { color: "#0078D4" } // Blue
                        ListElement { color: "#D83B01" } // Red
                        ListElement { color: "#00CC6A" } // Green
                        ListElement { color: "#8764B8" } // Purple
                        ListElement { color: "#FFB900" } // Yellow
                        ListElement { color: "#E3008C" } // Pink
                        ListElement { color: "#00B7C3" } // Cyan
                        ListElement { color: "#94D0A5" } // Sage
                        ListElement { color: "#4A154B" } // Eggplant
                        ListElement { color: "#FF6D00" } // Pumpkin
                        ListElement { color: "#486860" } // Forest
                    }

                    Button {
                        id: colorButton
                        Layout.preferredWidth: 25
                        Layout.preferredHeight: 25
                        checkable: true
                        ButtonGroup.group: colorButtonGroup

                        background: Rectangle {
                            anchors.fill: parent
                            color: model.color
                            border.width: colorButton.checked ? 3 : 1
                            border.color: colorButton.checked ? "white" : Qt.darker(model.color, 1.2)
                        }

                        onCheckedChanged: {
                            if (checked) {
                                BoxySettings.accentColor= model.color
                            }
                        }

                        Component.onCompleted: {
                            if (BoxySettings.accentColor === model.color) {
                                checked = true
                            }
                        }
                    }
                }
            }
        }

        ToolSeparator {
            orientation: Qt.Horizontal
            Layout.fillWidth: true
            Layout.topMargin: -5
            Layout.bottomMargin: -10
        }

        RowLayout {
            Label {
                text: "Dark mode"
                Layout.fillWidth: true
                font.bold: true
            }

            Switch {
                Layout.rightMargin: -10
                checked: BoxySettings.darkMode
                onClicked: BoxySettings.darkMode = !BoxySettings.darkMode
            }
        }
    }
}
