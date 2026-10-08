import QtQuick
import QtQuick.Controls
import QtTest
import "../../qml" as Calculator

TestCase {
    id: testCase
    name: "ExpressionViewport"
    when: testWindow.visible && testWindow.active

    ApplicationWindow {
        id: testWindow
        width: 370
        height: 160
        visible: true

        Calculator.ExpressionViewport {
            id: viewport
            anchors.centerIn: parent
            width: testWindow.width - 76
            textFont: editor.font
            height: Math.min(100, maximumTextHeight)

            TextArea {
                id: editor
                width: viewport.availableWidth
                font.pixelSize: 16
                padding: 0
                background: null
                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                verticalAlignment: TextEdit.AlignVCenter
                selectByMouse: !viewport.touchInputActive
            }
        }
    }

    function init() {
        testWindow.width = 370
        editor.font.pixelSize = 16
        editor.text = "999999999329999999999999999999999999".repeat(45)
        testWindow.requestActivate()
        editor.forceActiveFocus()
        tryVerify(function() { return editor.activeFocus })
        tryVerify(function() { return viewport.contentItem.contentHeight > viewport.height * 3 })
        viewport.contentItem.cancelFlick()
        viewport.contentItem.contentY = 0
        editor.cursorPosition = 0
        tryCompare(viewport.contentItem, "contentY", 0)
    }

    Component {
        id: freshWindowComponent
        ApplicationWindow {
            width: 370
            height: 160
            visible: true
            property alias expressionEditor: freshEditor

            Calculator.ExpressionViewport {
                width: 294
                height: Math.min(100, maximumTextHeight)
                textFont: freshEditor.font
                TextArea {
                    id: freshEditor
                    width: parent.width
                    font.pixelSize: 22
                    focus: true
                    padding: 0
                    background: null
                }
            }
        }
    }

    function test_fresh_window_accepts_typing_without_clicking_editor() {
        const freshWindow = createTemporaryObject(freshWindowComponent, null)
        verify(freshWindow)
        freshWindow.requestActivate()
        tryVerify(function() { return freshWindow.active })
        tryVerify(function() { return freshWindow.expressionEditor.activeFocus })
        keyClick(Qt.Key_1)
        keyClick(Qt.Key_2)
        keyClick(Qt.Key_Plus)
        keyClick(Qt.Key_3)
        compare(freshWindow.expressionEditor.text, "12+3")
        freshWindow.close()
        testWindow.requestActivate()
    }

    function caretIsVisible() {
        const caret = editor.cursorRectangle
        return caret.y >= viewport.contentItem.contentY - 1
            && caret.y + caret.height <= viewport.contentItem.contentY + viewport.height + 1
    }

    function test_three_visible_lines_data() {
        return [
            { tag: "minimum_narrow", pixels: 16, width: 340 },
            { tag: "minimum_wide", pixels: 16, width: 620 },
            { tag: "maximum_narrow", pixels: 22, width: 340 },
            { tag: "maximum_wide", pixels: 22, width: 620 }
        ]
    }

    function test_three_visible_lines(data) {
        testWindow.width = data.width
        editor.font.pixelSize = data.pixels
        verify(waitForRendering(editor))
        keyClick(Qt.Key_Home, Qt.ControlModifier)
        tryCompare(editor, "cursorPosition", 0)
        tryCompare(viewport.contentItem, "contentY", 0)
        tryCompare(viewport, "height", 3 * editor.cursorRectangle.height)
        compare(viewport.maximumVisibleLines, 3)
        verify(editor.lineCount > 3)
        for (let line = 0; line < 2; ++line) {
            keyClick(Qt.Key_Down)
            tryVerify(caretIsVisible)
            compare(viewport.contentItem.contentY, 0)
        }
        keyClick(Qt.Key_Down)
        tryVerify(caretIsVisible)
        verify(viewport.contentItem.contentY > 0)
    }

    function test_down_and_up_follow_caret_through_wrapped_lines() {
        const originalText = editor.text
        for (let index = 0; index < 20; ++index) {
            keyClick(Qt.Key_Down)
            tryVerify(caretIsVisible, 1000, "Down must keep the caret visible")
        }
        verify(viewport.contentItem.contentY > viewport.height)
        const lowerPosition = viewport.contentItem.contentY
        for (let index = 0; index < 20; ++index) {
            keyClick(Qt.Key_Up)
            tryVerify(caretIsVisible, 1000, "Up must keep the caret visible")
        }
        verify(viewport.contentItem.contentY < lowerPosition)
        compare(editor.text, originalText)
    }

    function test_home_end_and_selection_follow_caret() {
        keyClick(Qt.Key_End, Qt.ControlModifier)
        tryCompare(editor, "cursorPosition", editor.text.length)
        tryVerify(caretIsVisible)
        verify(viewport.contentItem.contentY > 0)
        keyClick(Qt.Key_Home, Qt.ControlModifier | Qt.ShiftModifier)
        tryCompare(editor, "cursorPosition", 0)
        tryCompare(viewport.contentItem, "contentY", 0)
        compare(editor.selectedText, editor.text)
    }

    function test_typing_and_resize_keep_last_line_visible() {
        editor.cursorPosition = editor.text.length
        for (const key of [Qt.Key_1, Qt.Key_2, Qt.Key_3, Qt.Key_4, Qt.Key_5])
            keyClick(key)
        tryVerify(caretIsVisible)
        testWindow.width = 340
        tryVerify(caretIsVisible)
        verify(editor.text.endsWith("12345"))
        editor.text = "49,000"
        editor.cursorPosition = editor.text.length
        tryCompare(viewport.contentItem, "contentY", 0)
        verify(caretIsVisible())
    }

    function test_mouse_drag_still_selects_text() {
        const originalText = editor.text
        mouseDrag(editor, 5, 5, 100, 0, Qt.LeftButton)
        tryVerify(function() { return editor.selectedText.length > 0 })
        compare(editor.text, originalText)
    }

    function test_wheel_scrolls_without_moving_caret_and_stops_at_bounds() {
        const position = editor.cursorPosition
        mouseWheel(viewport, viewport.width / 2, viewport.height / 2, 0, -120)
        tryVerify(function() { return viewport.contentItem.contentY > 0 })
        compare(editor.cursorPosition, position)
        for (let index = 0; index < 8; ++index)
            mouseWheel(viewport, viewport.width / 2, viewport.height / 2, 0, 1200)
        tryCompare(viewport.contentItem, "contentY", 0)
        verify(viewport.contentItem.contentX === 0)
        const end = Math.max(0, viewport.contentItem.contentHeight - viewport.height)
        viewport.contentItem.contentY = end
        mouseWheel(viewport, viewport.width / 2, viewport.height / 2, 0, -1200, Qt.NoButton)
        wait(200)
        verify(viewport.contentItem.contentY <= end + 1)
        keyClick(Qt.Key_Down)
        tryVerify(caretIsVisible)
    }

    function test_touch_drag_keeps_native_flicking() {
        const sequence = touchEvent(viewport)
        sequence.press(0, viewport, viewport.width / 2, viewport.height - 5).commit()
        wait(20)
        for (let y = viewport.height - 10; y >= 5; y -= 5) {
            sequence.move(0, viewport, viewport.width / 2, y).commit()
            wait(20)
        }
        sequence.release(0, viewport, viewport.width / 2, 5).commit()
        tryVerify(function() { return viewport.contentItem.contentY > 0 })
        verify(viewport.contentItem.interactive)
        viewport.contentItem.cancelFlick()
        viewport.contentItem.returnToBounds()
    }
}
