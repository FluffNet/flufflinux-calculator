import QtQuick
import QtQuick.Controls
import QtTest
import "../../qml" as Calculator

TestCase {
    id: testCase
    name: "CalculatorKey"
    when: testWindow.visible && testWindow.active

    property int triggerCount: 0
    property int shiftClearCount: 0
    property int alternateCount: 0
    property string currentLabel: "8"
    property int currentIndex: 0
    property int currentBase: 10
    property string currentMode: "basic"
    property var receivedLabels: []

    ApplicationWindow {
        id: testWindow
        width: 240
        height: 140
        visible: true

        Calculator.ProgrammerKeyRules { id: rules }

        Calculator.CalculatorKey {
            id: key
            x: 60
            y: 30
            width: 120
            height: 70
            modelData: testCase.currentLabel
            index: testCase.currentIndex
            enabled: testCase.currentMode !== "programming"
                || rules.isKeyEnabled(testCase.currentLabel, testCase.currentBase)
            shiftClearEnabled: rules.isClearKey(testCase.currentLabel,
                                                testCase.currentMode === "programming")
            alternateEnabled: testCase.currentLabel === "√"
            triggerHandler: function(label, buttonIndex) {
                testCase.triggerCount++
                testCase.receivedLabels.push(label + ":" + buttonIndex)
            }
            onShiftClearRequested: testCase.shiftClearCount++
            onAlternateRequested: testCase.alternateCount++
        }
    }

    function init() {
        triggerCount = 0
        shiftClearCount = 0
        alternateCount = 0
        currentLabel = "8"
        currentIndex = 0
        currentBase = 10
        currentMode = "basic"
        receivedLabels = []
        testWindow.requestActivate()
        key.forceActiveFocus()
        tryVerify(function() { return testWindow.active })
    }

    function clickKey(modifiers) {
        mouseClick(key, key.width / 2, key.height / 2, Qt.LeftButton,
                   modifiers || Qt.NoModifier)
    }

    function test_8_and_9_dispatch_once_per_mouse_click() {
        for (let click = 0; click < 100; ++click) {
            currentLabel = click % 2 === 0 ? "8" : "9"
            currentIndex = click
            clickKey()
            compare(triggerCount, click + 1, "mouse click " + click)
            compare(receivedLabels[click], currentLabel + ":" + click)
        }
        compare(triggerCount, 100)
    }

    function test_mode_and_radix_click_matrix_100() {
        const modes = ["basic", "advanced", "financial", "programming", "conversion"]
        const bases = [2, 8, 10, 16]
        const labels = ["0", "1", "7", "8", "9"]
        let expectedTriggers = 0
        let clicks = 0

        for (const mode of modes) {
            currentMode = mode
            for (const base of bases) {
                currentBase = base
                for (const label of labels) {
                    currentLabel = label
                    clickKey()
                    clicks++
                    if (mode !== "programming" || rules.isKeyEnabled(label, base))
                        expectedTriggers++
                    compare(triggerCount, expectedTriggers,
                            mode + " base " + base + " key " + label)
                }
            }
        }

        compare(clicks, 100)
    }

    function test_programming_all_keys_mouse_matrix_100() {
        const bases = [2, 8, 10, 16]
        const labels = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
                        "A", "B", "C", "D", "E", "F", ".", "%", "x⁻¹",
                        "CLR", "mod", "∧", "∨", "⊻", "≪"]
        let expectedTriggers = 0
        let clicks = 0
        currentMode = "programming"

        for (const base of bases) {
            currentBase = base
            for (const label of labels) {
                currentLabel = label
                clickKey()
                clicks++
                if (rules.isKeyEnabled(label, base)) expectedTriggers++
                compare(triggerCount, expectedTriggers,
                        "base " + base + " key " + label)
            }
        }

        compare(clicks, 100)
    }

    function test_custom_mode_handler_does_not_stack() {
        currentMode = "financial"
        currentLabel = "8"
        clickKey()
        compare(triggerCount, 1)

        currentMode = "conversion"
        currentLabel = "9"
        clickKey()
        compare(triggerCount, 2)

        currentMode = "programming"
        currentBase = 16
        currentLabel = "C"
        clickKey()
        compare(triggerCount, 3)
    }

    function test_disabled_programming_digits_do_not_dispatch() {
        currentMode = "programming"
        currentBase = 2
        for (const label of ["8", "9", "A", "C", ".", "%"]) {
            currentLabel = label
            clickKey()
        }
        compare(triggerCount, 0)

        currentLabel = "1"
        clickKey()
        compare(triggerCount, 1)
    }

    function test_shift_clear_dispatches_each_path_once() {
        currentMode = "programming"
        currentLabel = "CLR"
        clickKey(Qt.ShiftModifier)
        compare(triggerCount, 1)
        compare(shiftClearCount, 1)
    }

    function test_root_alternate_menu_dispatches_on_right_click() {
        currentLabel = "√"
        mouseClick(key, key.width / 2, key.height / 2, Qt.RightButton)
        compare(alternateCount, 1)
        compare(triggerCount, 0)

        clickKey()
        compare(alternateCount, 1)
        compare(triggerCount, 1)
    }
}
