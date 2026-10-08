import QtQuick
import QtQuick.Controls

Button {
    id: root

    property string expressionText
    property string resultText

    signal expressionRequested(string expression)

    height: Math.max(46, equationLabel.implicitHeight + 16)
    padding: 0
    focusPolicy: Qt.StrongFocus
    Accessible.name: expressionText + " = " + resultText
    onClicked: expressionRequested(expressionText)

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    TextMetrics {
        id: equationMetrics
        font.pixelSize: 17
        text: root.expressionText + " = " + root.resultText
    }

    function escapedText(value) {
        return value.replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
    }

    contentItem: Text {
        id: equationLabel

        leftPadding: 12
        rightPadding: 12
        text: root.escapedText(root.expressionText)
            + " = <b>" + root.escapedText(root.resultText) + "</b>"
        textFormat: Text.StyledText
        color: root.palette.text
        font.pixelSize: Math.max(12, Math.min(17, Math.floor(17
            * Math.max(1, width - leftPadding - rightPadding) * 3
            / Math.max(1, equationMetrics.advanceWidth))))
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        color: root.palette.base
        border.width: root.visualFocus ? 2 : 0
        border.color: root.palette.highlight

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 2
            color: root.palette.mid
            opacity: 0.55
        }
    }
}
