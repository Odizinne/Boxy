import QtQuick
import QtQuick.Templates as T
import QtQuick.Controls.Material

T.ProgressBar {
    id: control
    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                           implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                            implicitContentHeight + topPadding + bottomPadding)
    
    contentItem: Item {
        implicitHeight: 4
        
        Rectangle {
            id: progressRect
            y: (parent.height - height) / 2
            height: 4
            width: control.position * parent.width
            color: control.Material.accentColor
            scale: control.mirrored ? -1 : 1
            transformOrigin: Item.Left
            
            Behavior on width {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
    
    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 4
        y: (control.height - height) / 2
        height: 4
        color: Qt.rgba(control.Material.accentColor.r, control.Material.accentColor.g, control.Material.accentColor.b, 0.25)
    }
}