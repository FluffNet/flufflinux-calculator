import QtQuick
import QtQuick.Controls
import QtTest
import "../../qml" as Calculator

TestCase {
    id: testCase
    name: "ProgrammerBitPanel"
    when: testWindow.visible && testWindow.active

    property int toggledBit: -1
    property int toggleCount: 0

    ApplicationWindow {
        id: testWindow
        width: 600
        height: 320
        visible: true

        Calculator.ProgrammerBitPanel {
            id: panel
            anchors.fill: parent
            wordBits: 64
            binaryValue: "1".repeat(64)
            onBitToggled: function(bitIndex) {
                testCase.toggledBit = bitIndex
                testCase.toggleCount++
            }
        }
    }

    function init() {
        toggledBit = -1
        toggleCount = 0
        panel.wordBits = 64
        panel.binaryValue = "1".repeat(64)
        panel.valueAvailable = true
        testWindow.requestActivate()
        tryVerify(function() { return testWindow.active })
        tryCompare(panel, "rowCount", 8)
        tryCompare(panel, "scrollBarVisible", false)
    }

    function test_every_word_size_has_correct_rows() {
        const sizes = [8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096]
        const rows = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512]
        for (let index = 0; index < sizes.length; ++index) {
            panel.wordBits = sizes[index]
            tryCompare(panel, "rowCount", rows[index])
        }
    }

    function test_endpoints_are_separated_and_exact() {
        panel.wordBits = 4096
        panel.binaryValue = "0".repeat(4096)
        tryCompare(panel, "rowCount", 512)

        panel.showMostSignificantBits()
        wait(20)
        const first = panel.rowAt(0)
        verify(first)
        compare(first.modelData, 4095)
        compare(first.endingBit, 4088)
        verify(first.endpointWidth >= 42)

        panel.showLeastSignificantBits()
        wait(20)
        const last = panel.rowAt(511)
        verify(last)
        compare(last.modelData, 7)
        compare(last.endingBit, 0)
    }

    function test_click_toggles_once() {
        panel.showLeastSignificantBits()
        wait(20)
        const lowRow = panel.rowAt(7)
        verify(lowRow)
        const bitZero = lowRow.bitAt(7)
        verify(bitZero)
        mouseClick(bitZero, bitZero.width / 2, bitZero.height / 2)
        compare(toggleCount, 1)
        compare(toggledBit, 0)
    }

    function test_4096_bits_have_one_visible_scrollbar() {
        panel.wordBits = 4096
        panel.binaryValue = "1".repeat(4096)
        tryCompare(panel, "rowCount", 512)
        tryCompare(panel, "scrollBarVisible", true)

        const scrollBar = panel.scrollBarControl()
        verify(scrollBar)
        verify(scrollBar.interactive)
        compare(scrollBar.focusPolicy, Qt.StrongFocus)
        compare(scrollBar.Accessible.role, Accessible.ScrollBar)
        compare(scrollBar.Accessible.name, "Bit panel scrollbar")

        panel.showMostSignificantBits()
        tryVerify(function() { return panel.scrollPosition <= 1 })
        scrollBar.forceActiveFocus(Qt.TabFocusReason)
        tryCompare(scrollBar, "activeFocus", true)
        keyClick(Qt.Key_End)
        tryVerify(function() {
            return Math.abs(panel.scrollPosition
                - panel.maximumScrollPosition) < 1
        })

        keyClick(Qt.Key_Home)
        tryVerify(function() { return panel.scrollPosition <= 1 })
        keyClick(Qt.Key_PageDown)
        tryVerify(function() { return panel.scrollPosition > 1 })
    }

    function test_every_narrow_row_fits_before_scrollbar() {
        testWindow.width = 340
        const sizes = [64, 128, 256, 512, 1024, 2048, 4096]
        for (let index = 0; index < sizes.length; ++index) {
            panel.wordBits = sizes[index]
            panel.binaryValue = "0"
            panel.showMostSignificantBits()
            wait(20)

            const row = panel.rowAt(0)
            verify(row !== null)
            const reservedScrollWidth = panel.scrollBarVisible
                ? panel.scrollBarControl().width + 8 : 0
            compare(row.width + reservedScrollWidth, panel.width - 20)
            verify(row.bitAt(7).x + row.bitAt(7).width <= row.width)
            verify(row.bitAt(7).width >= 14)
            verify(row.rightEndpointRight <= row.width)
        }
    }

    function test_unavailable_value_disables_bits() {
        panel.valueAvailable = false
        panel.showLeastSignificantBits()
        wait(20)
        const lowRow = panel.rowAt(7)
        verify(lowRow)
        verify(!lowRow.bitAt(7).enabled)
    }
}
