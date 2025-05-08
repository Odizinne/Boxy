import QtQuick.Controls.Material
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
                text: "Accent color"
                Layout.alignment: Qt.AlignLeft
                Layout.preferredWidth: 130
                font.bold: true
            }

            ButtonGroup {
                id: colorButtonGroup
            }

            GridLayout {
                id: colorGrid
                columns: 8
                rowSpacing: 8
                columnSpacing: 8
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: ListModel {
                        ListElement { color: "#F44336" } // Material.Red
                        ListElement { color: "#E91E63" } // Material.Pink
                        ListElement { color: "#9C27B0" } // Material.Purple
                        ListElement { color: "#673AB7" } // Material.DeepPurple
                        ListElement { color: "#3F51B5" } // Material.Indigo
                        ListElement { color: "#2196F3" } // Material.Blue
                        ListElement { color: "#03A9F4" } // Material.LightBlue
                        ListElement { color: "#00BCD4" } // Material.Cyan
                        ListElement { color: "#009688" } // Material.Teal
                        ListElement { color: "#4CAF50" } // Material.Green
                        ListElement { color: "#8BC34A" } // Material.LightGreen
                        ListElement { color: "#CDDC39" } // Material.Lime
                        ListElement { color: "#FFEB3B" } // Material.Yellow
                        ListElement { color: "#FFC107" } // Material.Amber
                        ListElement { color: "#FF9800" } // Material.Orange
                        ListElement { color: "#FF5722" } // Material.DeepOrange
                    }

                    MaterialButton {
                        id: colorButton
                        Layout.preferredWidth: 25
                        Layout.preferredHeight: 25
                        checkable: true
                        ButtonGroup.group: colorButtonGroup

                        background: Rectangle {
                            anchors.fill: parent
                            color: model.color
                            radius: 4
                            border.width: colorButton.checked ? 3 : 1
                            border.color: colorButton.checked ? "white" : Qt.darker(model.color, 1.2)
                        }

                        onCheckedChanged: {
                            if (checked) {
                                BoxySettings.accentColor = model.index
                            }
                        }

                        Component.onCompleted: {
                            if (BoxySettings.accentColor === model.index) {
                                checked = true
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Label {
                text: "Primary color"
                Layout.alignment: Qt.AlignLeft
                Layout.preferredWidth: 130
                font.bold: true
            }

            ButtonGroup {
                id: primaryColorButtonGroup
            }

            GridLayout {
                id: primaryColorGrid
                columns: 8
                rowSpacing: 8
                columnSpacing: 8
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: ListModel {
                        ListElement { color: "#F44336" } // Material.Red
                        ListElement { color: "#E91E63" } // Material.Pink
                        ListElement { color: "#9C27B0" } // Material.Purple
                        ListElement { color: "#673AB7" } // Material.DeepPurple
                        ListElement { color: "#3F51B5" } // Material.Indigo
                        ListElement { color: "#2196F3" } // Material.Blue
                        ListElement { color: "#03A9F4" } // Material.LightBlue
                        ListElement { color: "#00BCD4" } // Material.Cyan
                        ListElement { color: "#009688" } // Material.Teal
                        ListElement { color: "#4CAF50" } // Material.Green
                        ListElement { color: "#8BC34A" } // Material.LightGreen
                        ListElement { color: "#CDDC39" } // Material.Lime
                        ListElement { color: "#FFEB3B" } // Material.Yellow
                        ListElement { color: "#FFC107" } // Material.Amber
                        ListElement { color: "#FF9800" } // Material.Orange
                        ListElement { color: "#FF5722" } // Material.DeepOrange
                    }

                    MaterialButton {
                        id: primaryColorButton
                        Layout.preferredWidth: 25
                        Layout.preferredHeight: 25
                        checkable: true
                        ButtonGroup.group: primaryColorButtonGroup

                        background: Rectangle {
                            anchors.fill: parent
                            color: model.color
                            radius: 4
                            border.width: primaryColorButton.checked ? 3 : 1
                            border.color: primaryColorButton.checked ? "white" : Qt.darker(model.color, 1.2)
                        }

                        onCheckedChanged: {
                            if (checked) {
                                BoxySettings.primaryColor = model.index
                            }
                        }

                        Component.onCompleted: {
                            if (BoxySettings.primaryColor === model.index) {
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
