import QtQuick

Item {
    id: root

    property bool shortcutsEnabled: true
    signal baseRequested(int baseValue)

    Shortcut {
        sequence: "F5"
        enabled: root.shortcutsEnabled
        context: Qt.ApplicationShortcut
        onActivated: root.baseRequested(16)
    }
    Shortcut {
        sequence: "F6"
        enabled: root.shortcutsEnabled
        context: Qt.ApplicationShortcut
        onActivated: root.baseRequested(10)
    }
    Shortcut {
        sequence: "F7"
        enabled: root.shortcutsEnabled
        context: Qt.ApplicationShortcut
        onActivated: root.baseRequested(8)
    }
    Shortcut {
        sequence: "F8"
        enabled: root.shortcutsEnabled
        context: Qt.ApplicationShortcut
        onActivated: root.baseRequested(2)
    }
}
