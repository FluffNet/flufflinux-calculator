import QtQuick

QtObject {
    id: controller

    property int revealDelay: 1000
    property bool cursorVisible: true
    readonly property bool waiting: revealTimer.running

    function typingActivity() {
        cursorVisible = false
        revealTimer.restart()
    }

    function revealNow() {
        revealTimer.stop()
        cursorVisible = true
    }

    property Timer revealTimer: Timer {
        interval: controller.revealDelay
        repeat: false
        onTriggered: controller.cursorVisible = true
    }
}
