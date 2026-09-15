import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Control {
    id: root

    readonly property int keypadView: 0
    readonly property int bitPanelView: 1
    property int currentView: keypadView
    property string bitwiseLabel: qsTr("Bitwise")
    property string bitShiftLabel: qsTr("Bit shift")
    property var bitwiseActions: [
        { text: qsTr("AND"), value: "∧" },
        { text: qsTr("OR"), value: "∨" },
        { text: qsTr("XOR"), value: "⊻" },
        { text: qsTr("NOT"), value: "¬" },
        { text: qsTr("NAND"), value: "nand(" },
        { text: qsTr("NOR"), value: "nor(" }
    ]
    property var bitShiftActions: [
        { text: qsTr("Shift left"), value: "≪" },
        { text: qsTr("Logical shift right"), value: "≫" },
        { text: qsTr("Arithmetic shift right"), value: "ashr(" },
        { text: qsTr("Rotate left"), value: "rol(" },
        { text: qsTr("Rotate right"), value: "ror(" }
    ]

    readonly property bool bitwiseMenuOpened: bitwiseMenu.opened
    readonly property bool bitShiftMenuOpened: bitShiftMenu.opened
    readonly property real expandedContentWidth:
        bitwiseTextMetrics.advanceWidth + bitShiftTextMetrics.advanceWidth + 92
    readonly property bool compact: width < expandedContentWidth

    TextMetrics {
        id: bitwiseTextMetrics
        font: root.font
        text: root.bitwiseLabel + "  ▾"
    }

    TextMetrics {
        id: bitShiftTextMetrics
        font: root.font
        text: root.bitShiftLabel + "  ▾"
    }

    signal viewRequested(int view)
    signal bitwiseOperationRequested(string operation)
    signal bitShiftOperationRequested(string operation)

    function viewToggleControl() {
        return viewToggleButton
    }

    function commandButtonAt(index) {
        if (index === 0) return bitwiseButton
        if (index === 1) return bitShiftButton
        if (index === 2) return viewToggleButton
        return null
    }

    function bitwiseActionAt(index) {
        return bitwiseActionRepeater.itemAt(index)
    }

    function bitShiftActionAt(index) {
        return bitShiftActionRepeater.itemAt(index)
    }

    function openBitwiseMenu() {
        bitwiseMenu.open()
    }

    function openBitShiftMenu() {
        bitShiftMenu.open()
    }

    function closeMenus() {
        bitwiseMenu.close()
        bitShiftMenu.close()
    }

    padding: compact ? 2 : 4
    implicitHeight: 52
    Accessible.name: qsTr("Programmer controls")

    component CommandButton: Button {
        id: commandButton

        property bool selected: false
        property string accessibilityLabel: text

        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        padding: root.compact ? 2 : 10
        leftPadding: root.compact ? 2 : 12
        rightPadding: root.compact ? 2 : 12
        implicitWidth: root.compact ? 48
            : contentItem.implicitWidth + leftPadding + rightPadding
        implicitHeight: 44
        Accessible.name: accessibilityLabel

        background: Rectangle {
            radius: 8
            color: commandButton.down
                ? Qt.darker(commandButton.palette.button, 1.08)
                : commandButton.hovered || commandButton.visualFocus
                    ? Qt.lighter(commandButton.palette.button, 1.06)
                    : commandButton.selected
                        ? Qt.rgba(commandButton.palette.highlight.r,
                                  commandButton.palette.highlight.g,
                                  commandButton.palette.highlight.b,
                                  0.12)
                        : "transparent"
            border.width: commandButton.visualFocus ? 2 : 0
            border.color: commandButton.palette.highlight

            Rectangle {
                visible: commandButton.selected
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                height: 3
                radius: 2
                color: commandButton.palette.highlight
            }
        }

        contentItem: Label {
            text: commandButton.text
            color: commandButton.palette.text
            font: commandButton.font
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideNone
            wrapMode: Text.NoWrap
        }
    }

    component ActionMenuItem: MenuItem {
        id: actionItem

        required property var actionData
        property string actionValue: actionData.value

        text: actionData.text
        focusPolicy: Qt.StrongFocus
        implicitWidth: Math.max(180,
                                actionLabel.implicitWidth
                                    + leftPadding + rightPadding)
        Accessible.name: text

        contentItem: Label {
            id: actionLabel

            text: actionItem.text
            color: actionItem.enabled
                ? actionItem.palette.text : actionItem.palette.mid
            font: actionItem.font
            textFormat: Text.PlainText
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideNone
            wrapMode: Text.NoWrap
        }
    }

    background: Rectangle {
        color: root.palette.window
        border.width: 1
        border.color: root.palette.mid
    }

    contentItem: Item {
        implicitWidth: 0
        implicitHeight: 0
    }

    RowLayout {
        parent: root
        anchors.fill: root
        anchors.margins: root.padding
        spacing: 4

        CommandButton {
            id: bitwiseButton

            objectName: "programmerBitwiseButton"
            text: root.compact ? "∧▾" : root.bitwiseLabel + "  ▾"
            Layout.minimumWidth: root.compact ? 48 : implicitWidth
            Layout.preferredWidth: root.compact ? 48 : implicitWidth
            Layout.maximumWidth: root.compact ? 48 : implicitWidth
            accessibilityLabel: qsTr("Open bitwise operations")
            onClicked: bitwiseMenu.opened ? bitwiseMenu.close() : bitwiseMenu.open()
            ToolTip.visible: hovered && !bitwiseMenu.opened
            ToolTip.text: accessibilityLabel

            Menu {
                id: bitwiseMenu

                y: parent.height
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                Repeater {
                    id: bitwiseActionRepeater
                    model: root.bitwiseActions

                    ActionMenuItem {
                        required property var modelData
                        actionData: modelData
                        onTriggered: root.bitwiseOperationRequested(actionValue)
                    }
                }
            }
        }

        CommandButton {
            id: bitShiftButton

            objectName: "programmerBitShiftButton"
            text: root.compact ? "≪▾" : root.bitShiftLabel + "  ▾"
            Layout.minimumWidth: root.compact ? 48 : implicitWidth
            Layout.preferredWidth: root.compact ? 48 : implicitWidth
            Layout.maximumWidth: root.compact ? 48 : implicitWidth
            accessibilityLabel: qsTr("Open bit shift operations")
            onClicked: bitShiftMenu.opened ? bitShiftMenu.close() : bitShiftMenu.open()
            ToolTip.visible: hovered && !bitShiftMenu.opened
            ToolTip.text: accessibilityLabel

            Menu {
                id: bitShiftMenu

                y: parent.height
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                Repeater {
                    id: bitShiftActionRepeater
                    model: root.bitShiftActions

                    ActionMenuItem {
                        required property var modelData
                        actionData: modelData
                        onTriggered: root.bitShiftOperationRequested(actionValue)
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            visible: !root.compact
            Layout.leftMargin: root.compact ? 1 : 4
            Layout.rightMargin: root.compact ? 1 : 4
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Layout.topMargin: 8
            Layout.bottomMargin: 8
            color: root.palette.mid
        }

        ToolButton {
            id: viewToggleButton

            readonly property bool showsKeypadAction:
                root.currentView === root.bitPanelView

            objectName: "programmerViewToggleButton"
            implicitWidth: 48
            implicitHeight: 44
            Layout.minimumWidth: 48
            Layout.preferredWidth: 48
            Layout.maximumWidth: 48
            Layout.minimumHeight: 44
            Layout.preferredHeight: 44
            Layout.maximumHeight: 44
            display: AbstractButton.IconOnly
            focusPolicy: Qt.StrongFocus
            hoverEnabled: true
            Accessible.name: root.currentView === root.bitPanelView
                ? qsTr("Show keypad") : qsTr("Show bits")
            onClicked: root.viewRequested(root.currentView === root.bitPanelView
                                          ? root.keypadView : root.bitPanelView)
            ToolTip.visible: hovered
            ToolTip.text: Accessible.name

            contentItem: Item {
                implicitWidth: 22
                implicitHeight: 22

                Label {
                    anchors.centerIn: parent
                    visible: !viewToggleButton.showsKeypadAction
                    text: "01"
                    color: viewToggleButton.palette.buttonText
                    font.family: "monospace"
                    font.pixelSize: 14
                    font.bold: true
                }

                Item {
                    anchors.centerIn: parent
                    width: 22
                    height: 16
                    visible: viewToggleButton.showsKeypadAction

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 1
                        border.color: viewToggleButton.palette.buttonText
                        radius: 2
                    }

                    Grid {
                        anchors.centerIn: parent
                        columns: 4
                        spacing: 2

                        Repeater {
                            model: 8
                            Rectangle {
                                width: 2
                                height: 2
                                radius: 1
                                color: viewToggleButton.palette.buttonText
                            }
                        }
                    }
                }
            }
        }
    }
}
