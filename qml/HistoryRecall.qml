import QtQuick

QtObject {
    id: root

    property var calculatorBackend
    property var expressionEditor

    signal expressionRestored()

    function restore(expression) {
        calculatorBackend.applyExpression(expression)
        Qt.callLater(function() {
            expressionEditor.forceActiveFocus()
            expressionEditor.deselect()
            expressionEditor.cursorPosition = expressionEditor.text.length
            root.expressionRestored()
        })
    }
}
