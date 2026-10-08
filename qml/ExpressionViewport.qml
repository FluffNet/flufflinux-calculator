import QtQuick
import QtQuick.Controls
import org.kde.desktop as Desktop

Desktop.ScrollView {
    id: root
    focus: true
    readonly property bool touchInputActive: touchPoint.active
    readonly property int maximumVisibleLines: 3
    property font textFont
    readonly property real textLineHeight: Math.ceil(textMetrics.height)
    readonly property real maximumTextHeight: maximumVisibleLines * Math.max(1, textLineHeight)

    implicitWidth: 0
    implicitHeight: 0
    contentWidth: availableWidth
    clip: true
    padding: 0
    background: null

    FontMetrics {
        id: textMetrics
        font: root.textFont
    }

    // KDE's ScrollView already supplies one Kirigami.WheelHandler.
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AlwaysOff

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
