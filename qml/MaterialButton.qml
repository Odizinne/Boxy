import QtQuick.Controls.Material

Button {
    Material.roundedScale: Material.LargeScale
    //implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
    //                        implicitContentWidth + leftPadding + rightPadding)
    //implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
    //                         implicitContentHeight + topPadding + bottomPadding)

    //padding: 8
    verticalPadding: padding - 4
    //spacing: 8
    Material.elevation: 0
    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0
}
