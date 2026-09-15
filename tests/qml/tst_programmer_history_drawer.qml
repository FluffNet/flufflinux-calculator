import QtQuick
import QtQuick.Controls
import QtTest
import "../../qml" as Calculator

TestCase {
    id: testCase
    name: "ProgrammerHistoryDrawer"
    when: testWindow.visible && testWindow.active

    property var historyEntries: []
    property int clearRequestCount: 0
    property int undoRequestCount: 0
    property int redoRequestCount: 0
    property int entryRequestCount: 0
    property string requestedExpression: ""
    property string requestedResult: ""
    property int requestedIndex: -1

    ApplicationWindow {
        id: testWindow
        width: 340
        height: 560
        visible: true

        Calculator.ProgrammerHistoryDrawer {
            id: drawer
            entries: testCase.historyEntries
            canUndo: true
            canRedo: true

            onClearRequested: {
                testCase.clearRequestCount++
                testCase.historyEntries = []
            }
            onUndoRequested: testCase.undoRequestCount++
            onRedoRequested: testCase.redoRequestCount++
            onEntryRequested: function(expression, result, index) {
                testCase.entryRequestCount++
                testCase.requestedExpression = expression
                testCase.requestedResult = result
                testCase.requestedIndex = index
            }
        }
    }

    function init() {
        drawer.close()
        tryVerify(function() { return !drawer.opened })
        drawer.sidecarWidth = 0
        testWindow.width = 340
        testWindow.height = 560
        historyEntries = [
            { expression: "FF + 1", result: "100" },
            "100\t256"
        ]
        clearRequestCount = 0
        undoRequestCount = 0
        redoRequestCount = 0
        entryRequestCount = 0
        requestedExpression = ""
        requestedResult = ""
        requestedIndex = -1
        testWindow.requestActivate()
        tryVerify(function() { return testWindow.active })
        tryCompare(drawer, "count", 2)
    }

    function openDrawer() {
        drawer.open()
        tryVerify(function() { return drawer.opened })
        wait(20)
    }

    function test_opening_focuses_the_newest_entry() {
        openDrawer()
        const newest = drawer.entryAt(drawer.count - 1)
        verify(newest)
        tryCompare(newest, "activeFocus", true)
    }

    function test_right_side_shell_and_theme_colors() {
        compare(drawer.edge, Qt.RightEdge)
        verify(!drawer.modal)
        verify(!drawer.dim)
        compare(drawer.titleText, "History")
        compare(drawer.closePolicy, Popup.NoAutoClose)
        compare(drawer.titleAlignment, Text.AlignHCenter)
        verify(drawer.width >= 340)
        fuzzyCompare(drawer.width, testWindow.width, 1)
        fuzzyCompare(drawer.height, testWindow.height, 1)
        compare(drawer.background.color, drawer.palette.window)
        compare(drawer.separatorColor, drawer.palette.mid)
        compare(drawer.separatorWidth, 2)

        openDrawer()
        tryVerify(function() {
            return Math.abs(drawer.x - (testWindow.width - drawer.width)) < 2
        })
    }

    function test_width_scales_with_a_wide_window() {
        testWindow.width = 1000
        tryCompare(drawer, "width", 480)
        verify(drawer.width > 420)
        testWindow.width = 340
        tryCompare(drawer, "width", 340)
    }

    function test_explicit_sidecar_width_uses_only_requested_space() {
        testWindow.width = 700
        drawer.sidecarWidth = 360
        tryCompare(drawer, "width", 360)
        drawer.sidecarWidth = 0
    }

    function test_history_controls_are_icon_only_with_tooltips() {
        const undo = drawer.undoControl()
        const redo = drawer.redoControl()
        const clear = drawer.clearControl()

        compare(undo.display, AbstractButton.IconOnly)
        compare(redo.display, AbstractButton.IconOnly)
        compare(clear.display, AbstractButton.IconOnly)
        compare(undo.icon.name, "edit-undo")
        compare(redo.icon.name, "edit-redo")
        compare(clear.icon.name, "edit-clear-history")
        compare(undo.ToolTip.text, "Undo  Ctrl+Z")
        compare(redo.ToolTip.text, "Redo  Ctrl+Y / Ctrl+Shift+Z")
        compare(clear.ToolTip.text, "Clear history")
        compare(undo.Accessible.name, "Undo")
        compare(redo.Accessible.name, "Redo")
        compare(clear.Accessible.name, "Clear history")
    }

    function test_structured_and_tab_separated_entries_are_supported() {
        openDrawer()
        tryVerify(function() { return drawer.entryAt(1) !== null })
        const first = drawer.entryAt(0)
        const second = drawer.entryAt(1)
        compare(first.expressionText, "FF + 1")
        compare(first.resultText, "100")
        compare(second.expressionText, "100")
        compare(second.resultText, "256")
        verify(first.preservesFullText)
        verify(second.preservesFullText)
    }

    function test_entry_click_dispatches_complete_value() {
        openDrawer()
        const second = drawer.entryAt(1)
        mouseClick(second, second.width / 2, second.height / 2)
        compare(entryRequestCount, 1)
        compare(requestedExpression, "100")
        compare(requestedResult, "256")
        compare(requestedIndex, 1)
    }

    function test_long_entry_wraps_without_elision() {
        const longExpression = "1".repeat(1024) + " + 1"
        const longResult = "F".repeat(1024)
        historyEntries = [
            { expression: longExpression, result: longResult }
        ]
        tryCompare(drawer, "count", 1)
        openDrawer()
        tryVerify(function() { return drawer.entryAt(0) !== null })
        const entry = drawer.entryAt(0)
        compare(entry.expressionText, longExpression)
        compare(entry.resultText, longResult)
        verify(entry.preservesFullText)
        verify(entry.height > 46)
    }

    function test_history_actions_are_keyboard_accessible() {
        openDrawer()
        const undo = drawer.undoControl()
        verify(undo.enabled)
        undo.forceActiveFocus(Qt.TabFocusReason)
        tryCompare(undo, "visualFocus", true)
        keyClick(Qt.Key_Space)
        compare(undoRequestCount, 1)

        const redo = drawer.redoControl()
        verify(redo.enabled)
        redo.forceActiveFocus(Qt.TabFocusReason)
        tryCompare(redo, "visualFocus", true)
        keyClick(Qt.Key_Space)
        compare(redoRequestCount, 1)

        const clear = drawer.clearControl()
        verify(clear.enabled)
        clear.forceActiveFocus(Qt.TabFocusReason)
        tryCompare(clear, "visualFocus", true)
        keyClick(Qt.Key_Space)
        compare(clearRequestCount, 1)
        tryCompare(drawer, "count", 0)
        tryCompare(drawer, "listHasFocus", true)
    }

    function test_external_clear_from_focused_entry_restores_focus() {
        openDrawer()
        const newest = drawer.entryAt(drawer.count - 1)
        verify(newest)
        newest.forceActiveFocus(Qt.TabFocusReason)
        tryCompare(newest, "activeFocus", true)

        historyEntries = []
        tryCompare(drawer, "count", 0)
        tryCompare(drawer, "listHasFocus", true)
    }

    function test_escape_does_not_close_history() {
        openDrawer()
        keyClick(Qt.Key_Escape)
        wait(20)
        verify(drawer.opened)
    }

    function test_empty_state_disables_clear() {
        openDrawer()
        historyEntries = []
        tryCompare(drawer, "count", 0)
        verify(drawer.empty)
        verify(drawer.emptyStateVisible)
        verify(!drawer.clearEnabled)
    }

    function test_visible_text_contains_no_long_dash_characters() {
        const values = [drawer.titleText, drawer.emptyText,
                        drawer.undoControl().text, drawer.redoControl().text,
                        drawer.clearControl().text]
        for (const value of values) verify(!/[\u2013\u2014]/.test(value), value)
    }
}
