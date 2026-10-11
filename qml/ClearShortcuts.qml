import QtQuick

Item {
    id: root
    signal clearRequested()

    function handleFocusedEditorKey(key, modifiers) {
        if (!root.enabled || key !== Qt.Key_Escape || modifiers !== Qt.NoModifier)
            return false
        root.clearRequested()
        return true
    }

    Shortcut {
        enabled: root.enabled
        sequence: "Esc"
        context: Qt.ApplicationShortcut
        onActivated: root.clearRequested()
    }
}
