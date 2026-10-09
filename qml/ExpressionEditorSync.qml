import QtQml

QtObject {
    id: root

    required property var calculatorBackend
    required property var expressionEditor
    required property var logicalCursorIndex
    required property var editorCursorPosition
    property bool synchronizing: false

    signal inputEdited()

    function loadExpression() {
        if (synchronizing || expressionEditor.text === calculatorBackend.expression) return
        synchronizing = true
        expressionEditor.text = calculatorBackend.expression
        synchronizing = false
    }

    function synchronizeInput() {
        if (synchronizing || expressionEditor.text === calculatorBackend.expression) return
        const originalText = expressionEditor.text
        const cursorIndex = logicalCursorIndex(originalText, expressionEditor.cursorPosition)
        synchronizing = true
        try {
            calculatorBackend.applyExpression(originalText)
            const normalizedText = calculatorBackend.expression
            if (normalizedText !== originalText) {
                let prefix = 0
                while (prefix < originalText.length && prefix < normalizedText.length
                       && originalText[prefix] === normalizedText[prefix]) prefix++
                let suffix = 0
                while (suffix < originalText.length - prefix
                       && suffix < normalizedText.length - prefix
                       && originalText[originalText.length - suffix - 1]
                          === normalizedText[normalizedText.length - suffix - 1]) suffix++
                const replacement = normalizedText.slice(prefix, normalizedText.length - suffix)
                // Keep the existing document and caret when formatting inserts wrap hints.
                // Insert first so a large replacement never temporarily empties the viewport.
                if (replacement.length > 0) expressionEditor.insert(prefix, replacement)
                const oldEnd = originalText.length - suffix
                if (oldEnd > prefix)
                    expressionEditor.remove(prefix + replacement.length, oldEnd + replacement.length)
                expressionEditor.cursorPosition = editorCursorPosition(normalizedText, cursorIndex)
            }
        } finally {
            synchronizing = false
        }
        inputEdited()
    }

    Component.onCompleted: loadExpression()

    property Connections backendChanges: Connections {
        target: root.calculatorBackend
        function onExpressionChanged() { root.loadExpression() }
    }

    property Connections editorChanges: Connections {
        target: root.expressionEditor
        function onTextChanged() { root.synchronizeInput() }
    }
}
