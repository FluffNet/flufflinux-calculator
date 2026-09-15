import QtQuick

Item {
    id: root
    signal undoRequested()
    signal redoRequested()

    function handleFocusedEditorKey(key, modifiers) {
        const controlPressed = (modifiers & Qt.ControlModifier) !== 0
        const unsupportedModifier = (modifiers & (Qt.AltModifier | Qt.MetaModifier)) !== 0
        if (!controlPressed || unsupportedModifier) return false
        if (key === Qt.Key_Z) {
            if ((modifiers & Qt.ShiftModifier) !== 0)
                root.redoRequested()
            else
                root.undoRequested()
            return true
        }
        if (key === Qt.Key_Y) {
            root.redoRequested()
            return true
        }
        return false
    }

    Shortcut {
        sequence: "Ctrl+Z"
        context: Qt.ApplicationShortcut
        onActivated: root.undoRequested()
    }
    Shortcut {
        sequence: "Ctrl+Shift+Z"
        context: Qt.ApplicationShortcut
        onActivated: root.redoRequested()
    }
    Shortcut {
        sequence: "Ctrl+Y"
        context: Qt.ApplicationShortcut
        onActivated: root.redoRequested()
    }
}
