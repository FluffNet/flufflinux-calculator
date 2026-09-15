import QtQuick
import QtQuick.Controls
import QtTest
import "../../qml" as Calculator

TestCase {
    id: testCase
    name: "ProgrammerBasePreview"
    when: testWindow.visible && testWindow.active

    property int requestedBase: 0
    property int requestCount: 0

    ApplicationWindow {
        id: testWindow
        width: 520
        height: 172
        visible: true

        Calculator.ProgrammerBasePreview {
            id: preview
            anchors.fill: parent
            currentBase: 16
            hasExpression: true
            values: ["FF", "255", "377", "11111111"]
            onBaseRequested: function(baseValue) {
                testCase.requestedBase = baseValue
                testCase.requestCount++
            }
        }
    }

    function init() {
        requestedBase = 0
        requestCount = 0
        preview.currentBase = 16
        preview.hasExpression = true
        preview.values = ["FF", "255", "377", "11111111"]
        testWindow.requestActivate()
        tryVerify(function() { return testWindow.active })
        tryVerify(function() { return !!preview.rowAt(3) })
    }

    function test_rows_are_hex_dec_oct_bin() {
        const expectedLabels = ["HEX", "DEC", "OCT", "BIN"]
        const expectedBases = [16, 10, 8, 2]
        let selectedRows = 0

        for (let index = 0; index < expectedLabels.length; ++index) {
            const row = preview.rowAt(index)
            compare(row.modelData.label, expectedLabels[index])
            compare(row.modelData.baseValue, expectedBases[index])
            compare(row.objectName, "programmerBaseRow" + expectedLabels[index])
            verify(row.width > 0, "row " + index + " width")
            verify(row.height >= 32, "row " + index + " height")
            if (index > 0) {
                const previousRow = preview.rowAt(index - 1)
                verify(row.y >= previousRow.y + previousRow.height,
                       "row " + index + " must not overlap")
            }
            if (row.currentBase) selectedRows++
        }

        compare(selectedRows, 1)
    }

    function test_live_values_and_empty_state() {
        compare(preview.rowAt(0).shownValue, "FF")
        compare(preview.rowAt(1).shownValue, "255")
        compare(preview.rowAt(2).shownValue, "377")
        compare(preview.rowAt(3).shownValue, "1111 1111")

        preview.hasExpression = false
        for (let index = 0; index < 4; ++index)
            compare(preview.rowAt(index).shownValue, "0")
    }

    function test_invalid_state_is_explicit() {
        preview.values = []
        for (let index = 0; index < 4; ++index) {
            compare(preview.rowAt(index).shownValue, "Invalid input")
            verify(!preview.rowAt(index).enabled)
        }
    }

    function test_fractional_decimal_marks_other_bases_unavailable() {
        preview.values = ["", "1234.5", "", ""]
        compare(preview.rowAt(0).shownValue, "Not available")
        compare(preview.rowAt(1).shownValue, "1,234.5")
        compare(preview.rowAt(2).shownValue, "Not available")
        compare(preview.rowAt(3).shownValue, "Not available")
        verify(!preview.rowAt(0).enabled)
        verify(preview.rowAt(1).enabled)
        verify(!preview.rowAt(2).enabled)
        verify(!preview.rowAt(3).enabled)
    }

    function test_mouse_switch_dispatches_once_100_times() {
        const bases = [16, 10, 8, 2]
        for (let click = 0; click < 100; ++click) {
            const row = preview.rowAt(click % 4)
            mouseMove(row, row.width / 2, row.height / 2)
            wait(1)
            mouseClick(row, row.width / 2, row.height / 2)
            wait(1)
            compare(requestCount, click + 1, "click " + click)
            compare(requestedBase, bases[click % 4], "base " + click)
        }
    }

    function test_keyboard_switching() {
        const decimalRow = preview.rowAt(1)
        decimalRow.forceActiveFocus()
        tryCompare(decimalRow, "activeFocus", true)
        keyClick(Qt.Key_Return)
        compare(requestCount, 1)
        compare(requestedBase, 10)

        const binaryRow = preview.rowAt(3)
        binaryRow.forceActiveFocus()
        keyClick(Qt.Key_Space)
        compare(requestCount, 2)
        compare(requestedBase, 2)
    }

    function test_keyboard_focus_is_visible() {
        const octalRow = preview.rowAt(2)
        octalRow.forceActiveFocus(Qt.TabFocusReason)
        tryCompare(octalRow, "activeFocus", true)
        tryCompare(octalRow, "visualFocus", true)
        compare(octalRow.background.border.width, 2)
    }

    function test_long_values_remain_full_and_scrollable() {
        const longHex = "F".repeat(1024)
        const longDecimal = "9".repeat(1000)
        const longOctal = "7".repeat(1200)
        const longBinary = "1".repeat(4096)
        const originalWidth = preview.width

        preview.values = [longHex, longDecimal, longOctal, longBinary]
        tryVerify(function() { return preview.rowAt(3).valueNeedsScrolling })

        compare(preview.rowAt(0).shownValue.replace(/ /g, ""), longHex)
        compare(preview.rowAt(1).shownValue.replace(/,/g, ""), longDecimal)
        compare(preview.rowAt(2).shownValue.replace(/ /g, ""), longOctal)
        compare(preview.rowAt(3).shownValue.replace(/ /g, ""), longBinary)
        verify(!preview.rowAt(3).shownValue.includes("..."))
        compare(preview.width, originalWidth)
    }

    function test_long_values_have_real_keyboard_scrolling() {
        preview.values = ["F".repeat(1024), "9".repeat(1000),
                          "7".repeat(1200), "1".repeat(4096)]
        const binaryRow = preview.rowAt(3)
        tryVerify(function() { return binaryRow.valueNeedsScrolling })
        compare(binaryRow.previewLeadingMargin,
                preview.rowAt(0).previewLeadingMargin)
        verify(binaryRow.previewRightPadding >= 20)
        verify(binaryRow.previewScrollBarVisible)
        verify(binaryRow.previewScrollBarInteractive)
        verify(binaryRow.previewScrollBarHeight >= 8)
        verify(binaryRow.previewScrollClearance >= 7,
               "long value text must not touch its scrollbar")

        binaryRow.scrollPreviewTo(0)
        binaryRow.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_End)
        tryVerify(function() {
            return binaryRow.previewContentX > 0
                && Math.abs(binaryRow.previewContentX
                            - binaryRow.maximumPreviewContentX) < 1
        })

        keyClick(Qt.Key_Home)
        tryVerify(function() { return binaryRow.previewContentX < 1 })
        keyClick(Qt.Key_Right)
        tryVerify(function() { return binaryRow.previewContentX > 0 })
        keyClick(Qt.Key_Left)
        tryVerify(function() { return binaryRow.previewContentX < 1 })
    }
}
