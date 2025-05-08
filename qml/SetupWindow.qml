import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.platform as Platform
import QtQuick.Controls.Material
import QtQuick.Templates as T

ApplicationWindow {
    id: setupWindow
    visible: true
    width: lyt.implicitWidth * 1.7
    height: lyt.implicitHeight + 30 + 40
    minimumWidth: lyt.implicitWidth * 1.7
    minimumHeight: lyt.implicitHeight + 30 + 40
    title: "Boxy Discord Bot Setup"
    Material.theme: BoxySettings.darkMode ? Material.Dark : Material.Light
    Material.accent: getAccentColor()
    Material.primary: getPrimaryColor()
    color: BoxySettings.darkMode ? "#303030" : "#fffbfe"
    header: ToolBar {
        height: 40
        Label {
            anchors.centerIn: parent
            text: "Boxy Discord Bot Setup"
            font.pixelSize: 20
            font.bold: true
        }
    }
    
    function getAccentColor() {
        switch (BoxySettings.accentColor) {
        case 0:  return Material.Red;
        case 1:  return Material.Pink;
        case 2:  return Material.Purple;
        case 3:  return Material.DeepPurple;
        case 4:  return Material.Indigo;
        case 5:  return Material.Blue;
        case 6:  return Material.LightBlue;
        case 7:  return Material.Cyan;
        case 8:  return Material.Teal;
        case 9:  return Material.Green;
        case 10: return Material.LightGreen;
        case 11: return Material.Lime;
        case 12: return Material.Yellow;
        case 13: return Material.Amber;
        case 14: return Material.Orange;
        case 15: return Material.DeepOrange;
        default: return Material.Red;
        }
    }

    function getPrimaryColor() {
        switch (BoxySettings.primaryColor) {
        case 0:  return Material.Red;
        case 1:  return Material.Pink;
        case 2:  return Material.Purple;
        case 3:  return Material.DeepPurple;
        case 4:  return Material.Indigo;
        case 5:  return Material.Blue;
        case 6:  return Material.LightBlue;
        case 7:  return Material.Cyan;
        case 8:  return Material.Teal;
        case 9:  return Material.Green;
        case 10: return Material.LightGreen;
        case 11: return Material.Lime;
        case 12: return Material.Yellow;
        case 13: return Material.Amber;
        case 14: return Material.Orange;
        case 15: return Material.DeepOrange;
        default: return Material.Blue;
        }
    }

    property bool tokenValid: tokenInput.text.trim() !== ""
    property bool readyToGo: tokenValid && messageIntentSwitch.checked && setupManager.ffmpegInstalled
    
    signal setupFinished(string token)
    
    ColumnLayout {
        id: lyt
        anchors.fill: parent
        anchors.margins: 15
        spacing: 20
        
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20
            
            CustomGroupBox {
                Layout.fillWidth: true
                title: "Create Discord Application"


                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14

                    MaterialButton {
                        text: "Open Discord Developer Portal"
                        Material.roundedScale: Material.LargeScale
                        Layout.alignment: Qt.AlignLeft
                        onClicked: Qt.openUrlExternally("https://discord.com/developers/applications")
                    }

                    Label {
                        text: "1 - Create a new application and name it 'Boxy'"
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "2 - Go to the Bot tab"
                    }

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "3 - Enable 'Message Content Intent"
                    }

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "4 - Click 'Reset Token' and copy it"
                    }
                }
            }
            
            CustomGroupBox {
                Layout.fillWidth: true
                title: "Enter Bot Token"


                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14

                    Label {
                        text: "⚠️ Never share your bot token with anyone"
                        opacity: 0.5
                    }

                    TextField {
                        id: tokenInput
                        Layout.fillWidth: true
                        placeholderText: "Paste your bot token here"
                        text: setupManager.get_token() || ""
                        echoMode: TextInput.Password
                    }
                }
            }

            CustomGroupBox {
                Layout.fillWidth: true
                title: "Install FFmpeg"


                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MaterialButton {
                            Material.roundedScale: Material.LargeScale
                            text: setupManager.ffmpegInstalled ? "✓ FFmpeg is installed" : "Install FFmpeg"
                            Layout.alignment: Qt.AlignLeft
                            onClicked: ffmpegPopup.open()
                            enabled: !setupManager.ffmpegInstalled
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                
                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: "I enabled Message Content Intent"
                        Layout.fillWidth: true
                    }

                    Switch {
                        id: messageIntentSwitch
                        Layout.rightMargin: - 10
                    }
                }
            }

            MaterialButton {
                text: "Let's Go!"
                Material.roundedScale: Material.LargeScale
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 150
                highlighted: true
                enabled: readyToGo
                
                onClicked: {
                    instructionDialog.open()
                }
            }
        }
    }
    
    Dialog {
        id: ffmpegPopup
        //modal: true
        //focus: true
        //closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        anchors.centerIn: parent
        width: ffmpegScrlView.implicitWidth + 80
        //height: popupLyt.implicitHeight + 80
        standardButtons: Dialog.Close
        title: "FFmpeg Installation"
            
            ScrollView {
                id: ffmpegScrlView
                anchors.fill: parent
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                
                ColumnLayout {
                    width: ffmpegPopup.width - 40
                    spacing: 15
                    
                    Label {
                        text: "FFmpeg is required for Boxy to process audio files."
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                    
                    // Windows instructions
                    ColumnLayout {
                        visible: setupManager.osType === "Windows"
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Label {
                            text: "For Windows:"
                            font.bold: true
                        }
                        
                        Label {
                            text: "FFmpeg can be automatically downloaded and installed for you."
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            MaterialButton {
                                highlighted: true
                                Material.roundedScale: Material.LargeScale
                                text: setupManager.ffmpegInstallInProgress ? "Installing..." :
                                                                             setupManager.ffmpegInstalled ? "Installation Complete" : "Install FFmpeg"
                                enabled: !setupManager.ffmpegInstallInProgress && !setupManager.ffmpegInstalled
                                Layout.alignment: Qt.AlignLeft
                                onClicked: setupManager.installFFmpegWindows()
                            }

                            ProgressBar {
                                visible: setupManager.ffmpegInstallInProgress
                                Layout.fillWidth: true
                                indeterminate: true
                            }

                            Label {
                                visible: setupManager.ffmpegInstalled
                                text: "✓ FFmpeg has been installed successfully!"
                                color: Material.accent
                            }
                        }
                    }
                    
                    // Linux instructions
                    ColumnLayout {
                        visible: setupManager.osType === "Linux"
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Label {
                            text: "For Linux:"
                            font.bold: true
                        }
                        
                        Label {
                            text: "Please run the following command in your terminal:"
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            height: linuxCommand.height + 20
                            color: Material.foreground
                            opacity: 0.1
                            radius: 5
                            
                            TextEdit {
                                id: linuxCommand
                                anchors.centerIn: parent
                                width: parent.width - 20
                                readOnly: true
                                selectByMouse: true
                                wrapMode: Text.Wrap
                                text: {
                                    if (setupManager.linuxDistro === "Ubuntu" || setupManager.linuxDistro === "Debian")
                                        return "sudo apt install ffmpeg"
                                    else if (setupManager.linuxDistro === "Fedora")
                                        return "sudo dnf in ffmpeg"
                                    else if (setupManager.linuxDistro === "Arch")
                                        return "sudo pacman -S ffmpeg"
                                    else
                                        return "# Please install ffmpeg using your distribution's package manager"
                                }
                            }
                        }
                        
                        MaterialButton {
                            text: "Copy Command"
                            Material.roundedScale: Material.LargeScale
                            Layout.alignment: Qt.AlignRight
                            onClicked: {
                                linuxCommand.selectAll()
                                linuxCommand.copy()
                            }
                        }
                    }
                    
                    ColumnLayout {
                        visible: setupManager.osType === "macOS"
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Label {
                            text: "For macOS:"
                            font.bold: true
                        }
                        
                        Label {
                            text: "Please install FFmpeg using Homebrew:"
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            height: macCommand.height + 20
                            color: Material.foreground
                            opacity: 0.1
                            radius: 5
                            
                            TextEdit {
                                id: macCommand
                                anchors.centerIn: parent
                                width: parent.width - 20
                                readOnly: true
                                selectByMouse: true
                                wrapMode: Text.Wrap
                                text: "brew install ffmpeg"
                            }
                        }
                        
                        MaterialButton {
                            text: "Copy Command"
                            Material.roundedScale: Material.LargeScale
                            Layout.alignment: Qt.AlignRight
                            onClicked: {
                                macCommand.selectAll()
                                macCommand.copy()
                            }
                        }
                        
                        Label {
                            text: "If you don't have Homebrew installed, install it first with:"
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            height: brewCommand.height + 20
                            color: Material.foreground
                            opacity: 0.1
                            radius: 5
                            
                            TextEdit {
                                id: brewCommand
                                anchors.centerIn: parent
                                width: parent.width - 20
                                readOnly: true
                                selectByMouse: true
                                wrapMode: Text.Wrap
                                text: '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
                            }
                        }
                        
                        MaterialButton {
                            text: "Copy Command"
                            Layout.alignment: Qt.AlignRight
                            Material.roundedScale: Material.LargeScale
                            onClicked: {
                                brewCommand.selectAll()
                                brewCommand.copy()
                            }
                        }
                    }
                }
            }
        }


    Dialog {
        id: instructionDialog
        title: "How to invite Boxy on your server"
        modal: true
        width: 320
        height: implicitHeight - 20
        anchors.centerIn: parent
        standardButtons: Dialog.Ok

        ColumnLayout {
            id: inviteLyt
            anchors.fill: parent
            spacing: 0

            Label {
                text: "To invite boxy to your servers, open the server section in the toolbar, and click <b>Invite to server</b>."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                textFormat: Text.RichText
            }
        }

        onAccepted: {
            setupFinished(tokenInput.text.trim())
            setupWindow.close()
        }
    }
}
