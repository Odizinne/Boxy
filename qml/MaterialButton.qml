import QtQuick.Controls.Material

Button {
    Material.roundedScale: Material.ExtraSmallScale
    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    padding: 8
    verticalPadding: padding - 4
    spacing: 8
    Material.elevation: 2
    topInset: 0
    bottomInset: 0

    icon.width: 20
    icon.height: 20
}