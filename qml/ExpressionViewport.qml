import QtQuick
import QtQuick.Controls
import org.kde.desktop as Desktop

Desktop.ScrollView {
    id: root
    focus: true
    readonly property bool touchInputActive: touchPoint.active
    readonly property int maximumVisibleLines: 3
    property font textFont
    property var expressionEditor: null
    readonly property real textLineHeight: Math.ceil(textMetrics.height)
    readonly property real maximumTextHeight: maximumVisibleLines * Math.max(1, textLineHeight)
    readonly property real maximumViewportHeight: maximumTextHeight + topPadding + bottomPadding

    implicitWidth: 0
    implicitHeight: 0
    clip: true
    background: null

    function revealHorizontalCursor() {
        if (!expressionEditor || !contentItem || availableWidth <= 0) return
        const caret = expressionEditor.cursorRectangle
        const right = caret.x + caret.width
        // A short wrapped line must show its beginning, even after a long number.
        if (right <= availableWidth) contentItem.contentX = 0
        else if (caret.x < contentItem.contentX) contentItem.contentX = caret.x
        else if (right > contentItem.contentX + availableWidth)
            contentItem.contentX = right - availableWidth
    }

    onAvailableWidthChanged: Qt.callLater(revealHorizontalCursor)

    Connections {
        target: root.expressionEditor
        function onCursorRectangleChanged() { Qt.callLater(root.revealHorizontalCursor) }
    }

    FontMetrics {
        id: textMetrics
        font: root.textFont
    }

    // KDE's ScrollView already supplies one Kirigami.WheelHandler.
    // Keep the style's native gutter and full scrollbar thickness.
    ScrollBar.horizontal.policy: ScrollBar.AsNeeded
    ScrollBar.vertical.policy: ScrollBar.AsNeeded

    Item {
        // Observe touch before the text editor can claim it for selection.
        parent: root
        anchors.fill: parent
        z: 1

        PointHandler {
            id: touchPoint
            target: null
            acceptedDevices: PointerDevice.TouchScreen
        }
    }
}
