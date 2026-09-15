import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Control {
    id: root

    property int currentBase: 10
    property var values: []
    property bool hasExpression: false
    signal baseRequested(int baseValue)

    readonly property var rows: [
        { label: "HEX", name: qsTr("Hexadecimal"), baseValue: 16, shortcut: "F5" },
        { label: "DEC", name: qsTr("Decimal"), baseValue: 10, shortcut: "F6" },
        { label: "OCT", name: qsTr("Octal"), baseValue: 8, shortcut: "F7" },
        { label: "BIN", name: qsTr("Binary"), baseValue: 2, shortcut: "F8" }
    ]

    function rawValueAt(index) {
        return values && values.length === 4 ? values[index] : ""
    }

    function shownValueAt(index) {
        if (!hasExpression) return "0"
        if (!values || values.length !== 4) return qsTr("Invalid input")
        const rawValue = rawValueAt(index)
        return rawValue.length > 0
            ? programmerRules.formatPreviewValue(rawValue, rows[index].baseValue)
            : qsTr("Not available")
    }

    function rowAt(index) {
        return rowRepeater.itemAt(index)
    }

    padding: 0
    bottomPadding: 8
    implicitHeight: 172
    clip: true
    Accessible.ignored: !visible

    ProgrammerKeyRules { id: programmerRules }

    background: Rectangle { color: root.palette.base }

    contentItem: ColumnLayout {
        spacing: 0

        Repeater {
            id: rowRepeater
            model: root.rows

            Button {
                id: baseRow

                required property int index
                required property var modelData
                readonly property bool currentBase:
                    root.currentBase === modelData.baseValue
                readonly property string shownValue: root.shownValueAt(index)
                readonly property bool valueNeedsScrolling:
                    previewFlick.contentWidth > previewFlick.width + 1
                readonly property real previewContentX: previewFlick.contentX
                readonly property real maximumPreviewContentX:
                    Math.max(0, previewFlick.contentWidth - previewFlick.width)
                readonly property real previewTextBottom:
                    previewFlick.y + previewValue.y + previewValue.height
                readonly property bool previewScrollBarVisible: previewScrollBar.visible
                readonly property bool previewScrollBarInteractive: previewScrollBar.interactive
                readonly property real previewScrollBarHeight: previewScrollBar.height
                readonly property real previewScrollBarTop: previewScrollBar.y
                readonly property real previewScrollClearance:
                    previewScrollBar.y - previewTextBottom
                readonly property real previewLeadingMargin:
                    previewLane.Layout.leftMargin
                readonly property real previewRightPadding:
                    previewLane.Layout.rightMargin

                function activateBase() {
                    root.baseRequested(modelData.baseValue)
                }

                function scrollPreviewBy(distance) {
                    previewFlick.contentX = Math.max(0,
                        Math.min(maximumPreviewContentX,
                                 previewFlick.contentX + distance))
                }

                function scrollPreviewTo(position) {
                    previewFlick.contentX = Math.max(0,
                        Math.min(maximumPreviewContentX, position))
                }

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 41
                Layout.preferredHeight: root.height / root.rows.length
                objectName: "programmerBaseRow" + modelData.label
                enabled: !root.hasExpression
                    || (root.values && root.values.length === 4
                        && root.rawValueAt(index).length > 0)
                flat: true
                padding: 0
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                Accessible.ignored: !root.visible
                Accessible.name: qsTr("%1 value %2").arg(modelData.name).arg(shownValue)
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Use %1  %2").arg(modelData.name).arg(modelData.shortcut)
                onClicked: activateBase()
                Keys.onReturnPressed: activateBase()
                Keys.onEnterPressed: activateBase()
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) {
                    if (!valueNeedsScrolling) return
                    const step = Math.max(24, previewFlick.width / 4)
                    if (event.key === Qt.Key_Left) {
                        scrollPreviewBy(-step)
                    } else if (event.key === Qt.Key_Right) {
                        scrollPreviewBy(step)
                    } else if (event.key === Qt.Key_Home) {
                        scrollPreviewTo(0)
                    } else if (event.key === Qt.Key_End) {
                        scrollPreviewTo(maximumPreviewContentX)
                    } else {
                        return
                    }
                    event.accepted = true
                }

                background: Rectangle {
                    color: Qt.rgba(baseRow.palette.highlight.r,
                                   baseRow.palette.highlight.g,
                                   baseRow.palette.highlight.b,
                                   baseRow.down ? 0.18
                                       : baseRow.currentBase ? 0.12
                                       : baseRow.hovered || baseRow.visualFocus ? 0.07 : 0)
                    border.width: baseRow.visualFocus ? 2 : 0
                    border.color: baseRow.palette.highlight

                    Rectangle {
                        visible: baseRow.currentBase
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3
                        color: baseRow.palette.highlight
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: baseRow.palette.mid
                        opacity: 0.28
                    }
                }

                contentItem: RowLayout {
                    spacing: 10

                    Item { Layout.preferredWidth: 9 }

                    Label {
                        text: baseRow.modelData.label
                        Layout.minimumWidth: 34
                        Layout.preferredWidth: 34
                        color: baseRow.palette.text
                        font.pixelSize: 12
                        font.bold: baseRow.currentBase
                    }

                    Item {
                        id: previewLane
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: 0
                        Layout.rightMargin: baseRow.modelData.baseValue === 2 ? 20 : 16

                        Flickable {
                            id: previewFlick

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: previewScrollBar.visible
                                ? previewScrollBar.top : parent.bottom
                            anchors.bottomMargin: previewScrollBar.visible ? 6 : 0
                            clip: true
                            interactive: false
                            flickableDirection: Flickable.HorizontalFlick
                            boundsBehavior: Flickable.StopAtBounds
                            contentWidth: Math.max(width, previewValue.implicitWidth)
                            contentHeight: height

                            Label {
                                id: previewValue

                                objectName: "programmerBaseValue" + baseRow.modelData.label
                                width: implicitWidth
                                anchors.verticalCenter: parent.verticalCenter
                                text: baseRow.shownValue
                                color: baseRow.palette.text
                                font.pixelSize: 14
                                font.bold: baseRow.currentBase
                                horizontalAlignment: Text.AlignLeft
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: baseRow.activateBase()
                                onWheel: function(wheel) {
                                    if (!baseRow.valueNeedsScrolling) {
                                        wheel.accepted = false
                                        return
                                    }
                                    const delta = wheel.angleDelta.x !== 0
                                        ? wheel.angleDelta.x : wheel.angleDelta.y
                                    if (delta === 0) {
                                        wheel.accepted = false
                                        return
                                    }
                                    const step = Math.max(24, previewFlick.width / 4)
                                    baseRow.scrollPreviewBy(delta > 0 ? -step : step)
                                    wheel.accepted = true
                                }
                            }

                            ScrollBar.horizontal: ScrollBar {
                                id: previewScrollBar

                                parent: previewLane
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 3
                                anchors.rightMargin: 3
                                anchors.bottomMargin: 3
                                objectName: "programmerBaseScroll" + baseRow.modelData.label
                                z: 2
                                policy: baseRow.valueNeedsScrolling
                                    ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                                interactive: true
                                minimumSize: 0.08
                                height: 8
                                focusPolicy: Qt.StrongFocus
                                Accessible.name: qsTr("%1 value scrollbar").arg(baseRow.modelData.name)
                            }
                        }
                    }
                }
            }
        }
    }
}
