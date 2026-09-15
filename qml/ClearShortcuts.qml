import QtQuick

Item {
    id: root
    signal clearRequested()

    function handleFocusedEditorKey(key, modifiers) {
        if (key !== Qt.Key_Escape || modifiers !== Qt.NoModifier)
            return false
        root.clearRequested()
        return true
    }

    Shortcut {
        sequence: "Esc"
        context: Qt.ApplicationShortcut
        onActivated: root.clearRequested()
    }
}
