import QtQuick
import QtQuick.Controls
import QtTest
import org.kde.kirigami as Kirigami
import "../../qml" as Calculator

TestCase {
    id: testCase
    name: "HistoryRecall"
    when: testWindow.visible && testWindow.active

    QtObject {
        id: backend
        property string expression: ""
        property var entries: []
        signal calculateRequested(string expression)
        function applyExpression(value) { expression = value }
        function calculate() { calculateRequested(expression) }
    }

    Calculator.HistoryRecall {
        id: recall
        calculatorBackend: backend
        expressionEditor: editor
    }

    SignalSpy { id: restored; target: recall; signalName: "expressionRestored" }
    SignalSpy { id: calculated; target: backend; signalName: "calculateRequested" }

    ApplicationWindow {
        id: testWindow
        width: 700
        height: 340
        visible: true

        ListView {
            id: history
            x: 10
            y: 10
            width: 330
            height: 170
            clip: true
            model: backend.entries

            Kirigami.WheelHandler {
                target: history
                blockTargetWheel: true
                scrollFlickableTarget: true
                filterMouseEvents: false
            }

            delegate: Calculator.CalculationHistoryEntry {
                required property var modelData
                width: ListView.view.width
                expressionText: modelData.expression
                resultText: modelData.result
                onExpressionRequested: function(expression) { recall.restore(expression) }
            }
        }

        Calculator.ExpressionViewport {
            id: viewport
            x: 10
            y: 210
            width: 330
            textFont: editor.font
            height: Math.min(80, maximumTextHeight)

            TextArea {
                id: editor
                width: viewport.availableWidth
                padding: 0
                font.pixelSize: 12
                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                selectByMouse: !viewport.touchInputActive
                text: backend.expression
                onTextChanged: {
                    if (text !== backend.expression) backend.applyExpression(text)
                }
                Keys.onReturnPressed: backend.calculate()
                Keys.onEnterPressed: backend.calculate()
            }
        }

        Calculator.ProgrammerHistoryDrawer {
            id: drawer
            entries: backend.entries
            sidecarWidth: 340
            onEntryRequested: function(expression, result, index) {
                recall.restore(expression)
            }
        }
    }

    function init() {
        drawer.close()
        tryVerify(function() { return !drawer.opened })
        backend.expression = "9000"
        backend.entries = [{ expression: "2000+2000", result: "4000" },
                           { expression: "6*7", result: "42" }]
        history.cancelFlick()
        history.positionViewAtBeginning()
        testWindow.requestActivate()
        editor.forceActiveFocus()
        editor.deselect()
        restored.clear()
        calculated.clear()
        tryCompare(history, "count", 2)
        tryVerify(function() { return testWindow.active && editor.activeFocus })
    }

    function clickEntry(index) {
        tryVerify(function() { return history.itemAtIndex(index) !== null })
        const entry = history.itemAtIndex(index)
        mouseClick(entry, entry.width - 20, Math.min(entry.height / 2, history.height / 2))
        tryVerify(function() { return editor.activeFocus })
        tryCompare(editor, "cursorPosition", editor.text.length)
    }

    function test_history_wraps_operator_with_following_number_data() {
        return [{tag: "narrow", width: 290}, {tag: "user_width", width: 340},
                {tag: "wider", width: 420}, {tag: "programming", width: 340, programming: true}]
    }

    function test_history_wraps_operator_with_following_number(data) {
        const calculation = "200+200+200+100+600+50+200+200+100+100+100"
        const expression = calculation.replace(/\+/g, "\u200b+")
        backend.entries = [{expression: expression, result: "2,050"}]
        tryCompare(history, "count", 1)
        let entry
        if (data.programming) {
            drawer.open()
            tryVerify(function() { return drawer.opened })
            entry = drawer.entryAt(0)
        } else {
            history.width = data.width
            entry = history.itemAtIndex(0)
        }
        verify(entry)
        const label = entry.contentItem
        label.forceLayout()
        verify(waitForRendering(label))
        const lineCount = label.lineCount
        verify(lineCount > 1)
        // Invisible links let us measure the actual styled history layout.
        // They keep the same glyphs, font, wrapping, and bold result.
        label.linkColor = label.color
        const terms = expression.split("\u200b")
        label.text = terms.map(function(term, index) {
            if (index === 0) return term
            return '<a href="operator' + index + '">+</a><a href="operand'
                + index + '">' + term[1] + '</a>' + term.slice(2)
        }).join("\u200b") + " = <b>2,050</b>"
        verify(waitForRendering(label))
        compare(label.lineCount, lineCount)
        const rows = {}
        for (let y = 0; y < label.height; y += 2) {
            for (let x = 0; x < label.width; x += 2) {
                const link = label.linkAt(x, y)
                if (link.length > 0 && rows[link] === undefined) rows[link] = y
            }
        }
        for (let index = 1; index < terms.length; index++) {
            verify(rows["operator" + index] !== undefined, "operator must be visible")
            verify(rows["operand" + index] !== undefined, "following number must be visible")
            compare(rows["operator" + index], rows["operand" + index],
                    "each + must share a line with the number that follows it")
        }
        history.width = 330
    }

    function test_click_restores_expression_not_result_without_calculating() {
        clickEntry(0)
        tryCompare(restored, "count", 1)
        compare(editor.text, "2000+2000")
        compare(editor.selectedText, "")
        compare(calculated.count, 0)
        compare(backend.entries.length, 2)
        keyClick(Qt.Key_Return)
        compare(calculated.count, 1)
        compare(calculated.signalArguments[0][0], "2000+2000")
    }

    function test_restored_expression_can_be_extended_and_calculated() {
        clickEntry(0)
        tryCompare(restored, "count", 1)
        for (const key of [Qt.Key_Plus, Qt.Key_5, Qt.Key_0, Qt.Key_0])
            keyClick(key)
        compare(editor.text, "2000+2000+500")
        compare(backend.expression, "2000+2000+500")
        compare(calculated.count, 0)
        keyClick(Qt.Key_Enter)
        compare(calculated.count, 1)
        compare(calculated.signalArguments[0][0], "2000+2000+500")
    }

    function test_clicking_same_expression_clears_selection() {
        clickEntry(0)
        tryCompare(restored, "count", 1)
        editor.selectAll()
        compare(editor.selectedText, editor.text)
        clickEntry(0)
        tryCompare(restored, "count", 2)
        compare(editor.selectedText, "")
        compare(editor.text, "2000+2000")
        compare(editor.cursorPosition, editor.text.length)
    }

    function test_keyboard_activation_restores_expression() {
        const entry = history.itemAtIndex(1)
        verify(entry)
        entry.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Space)
        tryCompare(restored, "count", 1)
        compare(editor.text, "6*7")
        verify(editor.activeFocus)
    }

    function test_long_expression_is_restored_in_full_and_caret_is_visible() {
        const expression = "1234567890".repeat(100) + "+1"
        backend.entries = [{ expression: expression, result: "9".repeat(100) }]
        tryCompare(history, "count", 1)
        clickEntry(0)
        tryCompare(restored, "count", 1)
        compare(editor.text, expression)
        verify(viewport.contentItem.contentY > 0)
        const caret = editor.cursorRectangle
        verify(caret.y >= viewport.contentItem.contentY - 1)
        verify(caret.y + caret.height <= viewport.contentItem.contentY + viewport.height + 1)
    }

    function test_programming_history_restores_expression_and_focus() {
        backend.entries = [{ expression: "FF+1", result: "100" }]
        drawer.open()
        tryVerify(function() { return drawer.opened && drawer.entryAt(0) !== null })
        const entry = drawer.entryAt(0)
        mouseClick(entry, entry.width / 2, entry.height / 2)
        tryCompare(restored, "count", 1)
        compare(editor.text, "FF+1")
        verify(editor.activeFocus)
        compare(editor.cursorPosition, editor.text.length)
        verify(drawer.opened)
        compare(calculated.count, 0)
    }

    function test_multiline_and_tabbed_expression_is_one_recallable_entry() {
        const expression = "2000+\n\t2000"
        backend.entries = JSON.parse(JSON.stringify([{ expression: expression, result: "4000" }]))
        tryCompare(history, "count", 1)
        clickEntry(0)
        tryCompare(restored, "count", 1)
        compare(editor.text, expression)
        compare(calculated.count, 0)
    }

    function populateScrollableHistory() {
        const entries = []
        for (let index = 0; index < 30; ++index)
            entries.push({ expression: index + "+1", result: String(index + 1) })
        backend.entries = entries
        tryCompare(history, "count", 30)
        history.positionViewAtBeginning()
    }

    function test_wheel_scrolling_does_not_recall_a_calculation() {
        populateScrollableHistory()
        mouseWheel(history, history.width / 2, history.height / 2, 0, -120)
        tryVerify(function() { return history.contentY > 0 })
        compare(restored.count, 0)
        compare(editor.text, "9000")
    }

    function test_touch_dragging_does_not_recall_a_calculation() {
        populateScrollableHistory()
        const sequence = touchEvent(history)
        sequence.press(0, history, 160, 150).commit()
        wait(20)
        for (let y = 140; y >= 20; y -= 10) {
            sequence.move(0, history, 160, y).commit()
            wait(20)
        }
        sequence.release(0, history, 160, 20).commit()
        tryVerify(function() { return history.contentY > 0 })
        compare(restored.count, 0)
        compare(editor.text, "9000")
        history.cancelFlick()
    }
}
