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

    property bool tokenValid: tokenInput.text.trim() !== ""
    property bool readyToGo: tokenValid && setupManager.ffmpegInstalled && setupManager.tokenValidationStatus === "Validated"
    
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
            
            Label {
                text: "Create discord application"
                Layout.bottomMargin: -15
                Layout.leftMargin: 10
                color: Material.accent
            }
            Pane {
                Layout.fillWidth: true
                Material.background: BoxySettings.darkMode ? "#2B2B2B" : "#FFFFFF"
                Material.elevation: 6
                Material.roundedScale: Material.ExtraSmallScale


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
                        text: "- Create a new application and name it 'Boxy'"
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "- Go to the Bot tab"
                    }

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "- Enable 'Message Content Intent'"
                    }

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "- Click 'Reset Token' and copy it"
                    }
                }
            }
            
            Label {
                text: "Setup Boxy and invite it to your server"
                Layout.bottomMargin: -15
                Layout.leftMargin: 10
                color: Material.accent
            }
            Pane {
                Layout.fillWidth: true
                Material.background: BoxySettings.darkMode ? "#2B2B2B" : "#FFFFFF"
                Material.elevation: 6
                Material.roundedScale: Material.ExtraSmallScale


                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14

                    Label {
                        text: "⚠️ Never share your bot token with anyone"
                        color: Material.foreground
                    }

                    TextField {
                        id: tokenInput
                        Layout.fillWidth: true
                        placeholderText: "Paste your bot token here"
                        text: setupManager.get_token() || ""
                        echoMode: TextInput.Password
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MaterialButton {
                            text: setupManager.tokenValidationStatus === "Validated" ? "Token is valid" : "Validate Token"
                            Material.roundedScale: Material.LargeScale
                            enabled: setupManager.tokenValidationStatus !== "Validated" 
                            onClicked: {
                                setupManager.validate_token(tokenInput.text.trim())
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        MaterialButton {
                            TextEdit {
                                id: clipboardHelper
                                visible: false
                                text: setupManager.inviteLink
                            }
                            text: "Invite Boxy to your server"
                            Material.roundedScale: Material.LargeScale
                            enabled: setupManager.tokenValidationStatus === "Validated"
                            onClicked: {
                                Qt.openUrlExternally(setupManager.inviteLink)
                                clipboardHelper.selectAll()
                                clipboardHelper.copy()
                            }
                        }

                        Label {
                            text: setupManager.inviteLink
                            color: Material.accent
                            wrapMode: Text.WordWrap
                            visible: false
                        }
                    }
                }
            }

            Label {
                text: "Install FFmpeg"
                Layout.bottomMargin: -15
                Layout.leftMargin: 10
                color: Material.accent
            }
            Pane {
                Layout.fillWidth: true
                Material.background: BoxySettings.darkMode ? "#2B2B2B" : "#FFFFFF"
                Material.elevation: 6
                Material.roundedScale: Material.ExtraSmallScale


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

            MaterialButton {
                text: "Let's Go!"
                Material.roundedScale: Material.LargeScale
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 150
                highlighted: true
                enabled: readyToGo
                
                onClicked: {
                    setupFinished(tokenInput.text.trim())
                    setupWindow.close()
                }
            }
        }
    }
    
    Dialog {
        id: ffmpegPopup
        anchors.centerIn: parent
        width: ffmpegScrlView.implicitWidth + 80
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
}
