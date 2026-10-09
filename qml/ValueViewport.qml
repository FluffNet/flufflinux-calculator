import QtQuick

ExpressionViewport {
    id: root

    required property var valueField
    textFont: valueField.font
    contentWidth: Math.max(availableWidth,
        valueField.contentWidth + valueField.leftPadding + valueField.rightPadding)
    contentHeight: valueField.implicitHeight
    implicitHeight: contentHeight + topPadding + bottomPadding

    background: Rectangle {
        color: root.palette.base
        radius: 3
        border.color: root.valueField.activeFocus ? root.palette.highlight : root.palette.mid
    }

    function revealCursor() {
        const caret = valueField.cursorRectangle
        const flickable = contentItem
        if (caret.x < flickable.contentX)
            flickable.contentX = Math.max(0, caret.x)
        else if (caret.x + caret.width > flickable.contentX + availableWidth)
            flickable.contentX = Math.min(contentWidth - availableWidth,
                caret.x + caret.width - availableWidth)
    }

    onAvailableWidthChanged: Qt.callLater(revealCursor)

    Connections {
        target: root.valueField
        function onCursorRectangleChanged() { Qt.callLater(root.revealCursor) }
    }
}
