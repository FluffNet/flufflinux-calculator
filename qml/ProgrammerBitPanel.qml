import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Control {
    id: root

    property int wordBits: 64
    property string binaryValue: ""
    property bool valueAvailable: true
    property string unavailableText: qsTr("Whole number required")
    signal bitToggled(int bitIndex)

    readonly property int rowCount: bitList.count
    readonly property bool scrollBarVisible: bitScrollBar.visible
    readonly property real scrollPosition: bitList.contentY
    readonly property real maximumScrollPosition:
        Math.max(bitList.originY, bitList.contentHeight - bitList.height)

    function rowAt(index) {
        return bitList.itemAtIndex(index)
    }

    function scrollBarControl() {
        return bitScrollBar
    }

    function showMostSignificantBits() {
        initialPositionTimer.stop()
        bitList.forceLayout()
        bitList.positionViewAtBeginning()
    }

    function showLeastSignificantBits() {
        initialPositionTimer.stop()
        bitList.forceLayout()
        bitList.positionViewAtEnd()
    }

    padding: 0
    implicitHeight: 250
    Accessible.name: qsTr("Bit toggle panel")

    ProgrammerKeyRules { id: programmerRules }

    Timer {
        id: initialPositionTimer
        interval: 0
        onTriggered: root.showLeastSignificantBits()
    }

    onWordBitsChanged: initialPositionTimer.restart()

    background: Rectangle {
        radius: 12
        color: root.palette.alternateBase
        border.width: 1
        border.color: root.palette.mid
    }

    contentItem: Item {
        ListView {
            id: bitList

            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.topMargin: contentHeight > parent.height - 20
                ? 10 : Math.max(10, (parent.height - contentHeight) / 2)
            anchors.bottomMargin: anchors.topMargin
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: programmerRules.bitRowStarts(root.wordBits)
            opacity: root.valueAvailable ? 1.0 : 0.16

            Component.onCompleted: initialPositionTimer.restart()

            ScrollBar.vertical: ScrollBar {
                id: bitScrollBar

                objectName: "programmerBitScrollBar"
                policy: bitList.contentHeight > bitList.height + 1
                    ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                interactive: true
                width: 9
                z: 2
                padding: 0
                stepSize: 0.05
                minimumSize: height > 0 ? Math.min(1, 18 / height) : 0
                focusPolicy: Qt.StrongFocus
                Accessible.role: Accessible.ScrollBar
                Accessible.name: qsTr("Bit panel scrollbar")

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) {
                    const maximumPosition = Math.max(0, 1 - bitScrollBar.size)
                    let nextPosition = bitScrollBar.position
                    if (event.key === Qt.Key_Up) {
                        nextPosition -= bitScrollBar.stepSize
                    } else if (event.key === Qt.Key_Down) {
                        nextPosition += bitScrollBar.stepSize
                    } else if (event.key === Qt.Key_PageUp) {
                        nextPosition -= bitScrollBar.size
                    } else if (event.key === Qt.Key_PageDown) {
                        nextPosition += bitScrollBar.size
                    } else if (event.key === Qt.Key_Home) {
                        nextPosition = 0
                    } else if (event.key === Qt.Key_End) {
                        nextPosition = maximumPosition
                    } else {
                        return
                    }
                    bitScrollBar.position = Math.max(0,
                        Math.min(maximumPosition, nextPosition))
                    event.accepted = true
                }

                background: Rectangle {
                    radius: 5
                    color: Qt.rgba(root.palette.text.r,
                                   root.palette.text.g,
                                   root.palette.text.b, 0.14)
                }

                contentItem: Rectangle {
                    radius: 5
                    color: root.palette.text
                    opacity: 0.65
                }
            }

            delegate: RowLayout {
                id: bitRow

                required property int index
                required property int modelData
                readonly property int bitCount:
                    programmerRules.bitCountForRow(modelData)
                readonly property int endpointWidth: root.wordBits > 999 ? 42
                    : root.wordBits > 99 ? 34 : 28
                readonly property int endingBit:
                    modelData - bitCount + 1
                readonly property int compactSpacing: width >= 420 ? 5 : 3
                readonly property int compactGroupGap: width >= 420 ? 10 : 6
                readonly property int compactBitFontSize: Math.max(13,
                    Math.min(18, Math.floor(width / 20)))
                readonly property real rightEndpointRight:
                    endingLabel.x + endingLabel.width

                function bitAt(index) {
                    return bitRepeater.itemAt(index)
                }

                width: bitList.width
                    - (bitScrollBar.visible ? bitScrollBar.width + 8 : 0)
                height: 28
                spacing: compactSpacing
                objectName: "programmerBitRow" + modelData

                Label {
                    text: bitRow.modelData
                    Layout.minimumWidth: bitRow.endpointWidth
                    Layout.preferredWidth: bitRow.endpointWidth
                    horizontalAlignment: Text.AlignHCenter
                    color: root.palette.text
                    opacity: 0.75
                    font.pixelSize: Math.max(11,
                        bitRow.compactBitFontSize - 2)
                    font.bold: true
                }

                Rectangle {
                    Layout.preferredWidth: 2
                    Layout.preferredHeight: 22
                    color: root.palette.text
                    opacity: 0.4
                }

                Repeater {
                    id: bitRepeater
                    model: bitRow.bitCount

                    Button {
                        id: bitButton

                        required property int index
                        readonly property int bitPosition:
                            bitRow.modelData - index
                        readonly property int stringIndex:
                            root.binaryValue.length - 1 - bitPosition
                        readonly property string bitValue: {
                            if (!root.valueAvailable) return ""
                            return stringIndex >= 0
                                ? root.binaryValue.charAt(stringIndex) : "0"
                        }

                        Layout.fillWidth: true
                        Layout.minimumWidth: 14
                        Layout.leftMargin: index > 0 && index % 4 === 0
                            ? bitRow.compactGroupGap : 0
                        Layout.fillHeight: true
                        flat: true
                        padding: 0
                        text: bitValue
                        enabled: root.valueAvailable
                        focusPolicy: Qt.StrongFocus
                        objectName: "programmerBit" + bitPosition
                        Accessible.name: qsTr("Bit %1, value %2").arg(bitPosition).arg(bitValue)
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("Bit %1. Click to toggle").arg(bitPosition)
                        onClicked: root.bitToggled(bitPosition)

                        background: Rectangle {
                            radius: 4
                            color: bitButton.down
                                ? Qt.rgba(bitButton.palette.highlight.r,
                                          bitButton.palette.highlight.g,
                                          bitButton.palette.highlight.b, 0.22)
                                : bitButton.hovered || bitButton.visualFocus
                                    ? Qt.rgba(bitButton.palette.highlight.r,
                                              bitButton.palette.highlight.g,
                                              bitButton.palette.highlight.b, 0.12)
                                    : "transparent"
                            border.width: bitButton.visualFocus ? 2 : 0
                            border.color: bitButton.palette.highlight
                        }

                        contentItem: Label {
                            text: bitButton.text
                            color: bitButton.palette.text
                            opacity: bitButton.text === "1" ? 1.0 : 0.38
                            font.bold: true
                            font.pixelSize: bitRow.compactBitFontSize
                                + (bitButton.text === "1" ? 1 : 0)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 2
                    Layout.preferredHeight: 22
                    color: root.palette.text
                    opacity: 0.4
                }

                Label {
                    id: endingLabel

                    text: bitRow.endingBit
                    Layout.minimumWidth: bitRow.endpointWidth
                    Layout.preferredWidth: bitRow.endpointWidth
                    horizontalAlignment: Text.AlignHCenter
                    color: root.palette.text
                    opacity: 0.75
                    font.pixelSize: Math.max(11,
                        bitRow.compactBitFontSize - 2)
                    font.bold: true
                }
            }
        }

        Label {
            anchors.centerIn: parent
            visible: !root.valueAvailable
            text: root.unavailableText
            color: root.palette.text
            font.bold: true
            z: 3
        }

    }
}
