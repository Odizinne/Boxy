// SmoothProgressBar.qml
import QtQuick
import QtQuick.Templates as T
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl

T.ProgressBar {
    id: control
    
    // Keep the standard value property
    // No need for targetValue since we'll apply the smoothing at the visual level
    
    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                           implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                            implicitContentHeight + topPadding + bottomPadding)
    
    contentItem: Item {
        implicitHeight: 4
        
        // Custom implementation with smooth width changes
        Rectangle {
            id: progressRect
            y: (parent.height - height) / 2
            height: 4
            width: control.position * parent.width
            color: control.Material.accentColor
            scale: control.mirrored ? -1 : 1
            transformOrigin: Item.Left // Important for mirroring to work correctly
            
            // This is the key for smooth transitions
            Behavior on width {
                NumberAnimation {
                    duration: 50
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