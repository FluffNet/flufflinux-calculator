import QtQuick
import QtQuick.Controls
import QtTest
import "../../qml" as Calculator

TestCase {
    id: testCase
    name: "ProgrammerBaseShortcuts"
    when: testWindow.visible && testWindow.active

    property int requestedBase: 0
    property int requestCount: 0

    ApplicationWindow {
        id: testWindow
        width: 320
        height: 180
        visible: true

        Calculator.ProgrammerBaseShortcuts {
            id: shortcuts
            onBaseRequested: function(baseValue) {
                testCase.requestedBase = baseValue
                testCase.requestCount++
            }
        }
    }

    function init() {
        requestedBase = 0
        requestCount = 0
        shortcuts.shortcutsEnabled = true
        testWindow.requestActivate()
        tryVerify(function() { return testWindow.active })
    }

    function test_f5_through_f8_switch_bases_100_times() {
        const keys = [Qt.Key_F5, Qt.Key_F6, Qt.Key_F7, Qt.Key_F8]
        const bases = [16, 10, 8, 2]

        for (let press = 0; press < 100; ++press) {
            keyClick(keys[press % 4])
            compare(requestCount, press + 1, "key press " + press)
            compare(requestedBase, bases[press % 4], "base " + press)
        }
    }

    function test_shortcuts_disable_outside_programming() {
        shortcuts.shortcutsEnabled = false
        keyClick(Qt.Key_F5)
        keyClick(Qt.Key_F6)
        keyClick(Qt.Key_F7)
        keyClick(Qt.Key_F8)
        compare(requestCount, 0)
    }
}
