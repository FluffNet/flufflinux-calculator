import QtQuick
import QtQuick.Controls

Button {
    id: key

    required property string modelData
    required property int index
    property bool operatorKey: false
    property string helpText: ""
    property bool shiftClearEnabled: false
    property bool alternateEnabled: false
    property var triggerHandler: function(label, buttonIndex) {}

    signal shiftClearRequested()
    signal alternateRequested()

    implicitWidth: 56
    implicitHeight: 52
    text: modelData
    font.pixelSize: operatorKey || modelData === "." || modelData === "√" ? 22 : 16
    font.bold: operatorKey || modelData === "."
        || (modelData.length === 1 && modelData >= "0" && modelData <= "9")
    hoverEnabled: true

    background: Rectangle {
        radius: 12
        color: key.down ? Qt.darker(key.palette.button, 1.12)
                        : key.hovered ? Qt.lighter(key.palette.button, 1.08)
                                      : key.palette.button
        border.width: key.activeFocus ? 2 : 1
        border.color: key.activeFocus ? key.palette.highlight
                                           : Qt.lighter(key.palette.button, 1.18)
    }

    contentItem: Label {
        text: key.text
        color: key.palette.buttonText
        opacity: key.enabled ? 1.0 : 0.42
        font: key.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    TapHandler {
        enabled: key.shiftClearEnabled
        acceptedModifiers: Qt.ShiftModifier
        onTapped: key.shiftClearRequested()
    }

    TapHandler {
        enabled: key.alternateEnabled
        acceptedButtons: Qt.RightButton
        onTapped: key.alternateRequested()
    }

    onPressAndHold: {
        if (alternateEnabled) alternateRequested()
    }

    ToolTip.visible: key.helpText.length > 0 && key.hovered
    ToolTip.text: key.helpText

    onClicked: triggerHandler(modelData, index)
}
