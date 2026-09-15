import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Drawer {
    id: root

    property string titleText: qsTr("History")
    property string emptyText: qsTr("No history yet")
    property var entries: []
    property bool canUndo: false
    property bool canRedo: false
    property real sidecarWidth: 0

    readonly property int count: historyList.count
    readonly property bool empty: count === 0
    readonly property bool emptyStateVisible: emptyState.visible
    readonly property bool clearEnabled: clearButton.enabled
    readonly property bool listHasFocus: historyList.activeFocus
    readonly property int titleAlignment: titleLabel.horizontalAlignment
    readonly property color separatorColor: sidecarSeparator.color
    readonly property real separatorWidth: sidecarSeparator.width

    signal clearRequested()
    signal undoRequested()
    signal redoRequested()
    signal entryRequested(string expression, string result, int index)

    function entryExpression(entry) {
        if (entry === undefined || entry === null) return ""
        if (typeof entry === "string") return entry.split("\t")[0] || ""
        return entry.expression === undefined ? "" : String(entry.expression)
    }

    function entryResult(entry) {
        if (entry === undefined || entry === null) return ""
        if (typeof entry === "string") {
            const fields = entry.split("\t")
            return fields.length > 1 ? fields.slice(1).join("\t") : ""
        }
        return entry.result === undefined ? "" : String(entry.result)
    }

    function entryAt(index) {
        return historyList.itemAtIndex(index)
    }

    function escapedText(text) {
        return text.replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
    }

    function clearControl() {
        return clearButton
    }

    function undoControl() {
        return undoButton
    }

    function redoControl() {
        return redoButton
    }

    function showNewest() {
        historyList.positionViewAtEnd()
    }

    function focusInitialControl() {
        if (root.count > 0) {
            historyList.currentIndex = root.count - 1
            const newestEntry = historyList.itemAtIndex(root.count - 1)
            if (newestEntry) {
                newestEntry.forceActiveFocus(Qt.TabFocusReason)
                return
            }
        }
        historyList.forceActiveFocus(Qt.TabFocusReason)
    }

    edge: Qt.RightEdge
    modal: false
    dim: false
    interactive: true
    padding: 0
    width: parent ? Math.min(parent.width,
        sidecarWidth > 0
            ? sidecarWidth
            : Math.max(340, parent.width * 0.48)) : 360
    height: parent ? parent.height : 560
    closePolicy: Popup.NoAutoClose
    onOpened: Qt.callLater(function() {
        showNewest()
        Qt.callLater(focusInitialControl)
    })

    background: Rectangle {
        color: root.palette.window
        border.width: 1
        border.color: root.palette.mid

        Rectangle {
            id: sidecarSeparator

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 2
            color: root.palette.mid
            opacity: 0.85
        }
    }

    contentItem: ColumnLayout {
        spacing: 0
        Accessible.name: root.titleText

        Item {
            Layout.fillWidth: true
            Layout.minimumHeight: 56
            Layout.preferredHeight: Math.max(56, titleLabel.implicitHeight + 16)

            Label {
                id: titleLabel

                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                text: root.titleText
                color: root.palette.text
                font.pixelSize: 18
                font.bold: true
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideNone
                wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.palette.mid
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumHeight: 52
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            spacing: 6

            ToolButton {
                id: undoButton

                Layout.fillWidth: true
                text: qsTr("Undo")
                display: AbstractButton.IconOnly
                icon.name: "edit-undo"
                icon.width: 22
                icon.height: 22
                icon.color: palette.buttonText
                enabled: root.canUndo
                focusPolicy: Qt.StrongFocus
                Accessible.name: qsTr("Undo")
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Undo") + "  Ctrl+Z"
                onClicked: root.undoRequested()
            }

            ToolButton {
                id: redoButton

                Layout.fillWidth: true
                text: qsTr("Redo")
                display: AbstractButton.IconOnly
                icon.name: "edit-redo"
                icon.width: 22
                icon.height: 22
                icon.color: palette.buttonText
                enabled: root.canRedo
                focusPolicy: Qt.StrongFocus
                Accessible.name: qsTr("Redo")
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Redo") + "  Ctrl+Y / Ctrl+Shift+Z"
                onClicked: root.redoRequested()
            }

            ToolButton {
                id: clearButton

                Layout.fillWidth: true
                text: qsTr("Clear")
                display: AbstractButton.IconOnly
                icon.name: "edit-clear-history"
                icon.width: 22
                icon.height: 22
                icon.color: palette.buttonText
                enabled: root.count > 0
                focusPolicy: Qt.StrongFocus
                Accessible.name: qsTr("Clear history")
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Clear history")
                onClicked: root.clearRequested()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.palette.mid
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: historyList

                objectName: "programmerHistoryList"
                anchors.fill: parent
                clip: true
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                model: root.entries || []
                activeFocusOnTab: true
                Accessible.name: qsTr("%1 entries").arg(root.titleText)
                onCountChanged: Qt.callLater(function() {
                    root.showNewest()
                    if (root.opened && root.count === 0)
                        root.focusInitialControl()
                })

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    interactive: true
                    width: 8
                    Accessible.name: qsTr("History scrollbar")
                }

                delegate: Button {
                    id: historyEntry

                    required property int index
                    required property var modelData
                    readonly property string expressionText:
                        root.entryExpression(modelData)
                    readonly property string resultText:
                        root.entryResult(modelData)
                    readonly property bool preservesFullText:
                        equationLabel.elide === Text.ElideNone
                            && equationLabel.wrapMode === Text.WrapAnywhere

                    objectName: "programmerHistoryEntry" + index
                    width: Math.max(0, ListView.view.width - 10)
                    height: equationLabel.implicitHeight + 20
                    padding: 10
                    focusPolicy: Qt.StrongFocus
                    hoverEnabled: true
                    Accessible.name: qsTr("%1 equals %2").arg(expressionText).arg(resultText)
                    onClicked: root.entryRequested(expressionText, resultText, index)

                    background: Rectangle {
                        color: historyEntry.down
                            ? Qt.darker(historyEntry.palette.base, 1.06)
                            : historyEntry.hovered || historyEntry.visualFocus
                                ? historyEntry.palette.alternateBase
                                : historyEntry.palette.base
                        border.width: historyEntry.visualFocus ? 2 : 0
                        border.color: historyEntry.palette.highlight

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: historyEntry.palette.mid
                        }
                    }

                    contentItem: Text {
                        id: equationLabel

                        text: root.escapedText(historyEntry.expressionText)
                            + " = <b>" + root.escapedText(historyEntry.resultText) + "</b>"
                        color: historyEntry.palette.text
                        textFormat: Text.StyledText
                        wrapMode: Text.WrapAnywhere
                        elide: Text.ElideNone
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Label {
                id: emptyState

                visible: root.empty
                anchors.centerIn: parent
                width: Math.max(0, parent.width - 48)
                text: root.emptyText
                color: root.palette.text
                textFormat: Text.PlainText
                opacity: 0.72
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                Accessible.name: text
            }
        }
    }
}
