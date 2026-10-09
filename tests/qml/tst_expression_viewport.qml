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
            expressionEditor: editor
            height: maximumViewportHeight

            TextArea {
                id: editor
                width: viewport.availableWidth
                font.pixelSize: 16
                padding: 0
                background: null
                wrapMode: TextEdit.WordWrap
                verticalAlignment: TextEdit.AlignVCenter
                selectByMouse: !viewport.touchInputActive
            }
        }
    }

    function init() {
        testWindow.width = 370
        editor.font.pixelSize = 16
        editor.text = "99999999932999+\u200b".repeat(90)
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
            property alias expressionViewport: freshViewport

            Calculator.ExpressionViewport {
                id: freshViewport
                width: 294
                height: maximumViewportHeight
                textFont: freshEditor.font
                expressionEditor: freshEditor
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

    Component {
        id: valueWindowComponent
        ApplicationWindow {
            width: 370
            height: 160
            visible: true
            property alias expressionEditor: valueInput
            property alias expressionViewport: valueViewport
            Calculator.ValueViewport {
                id: valueViewport
                width: 180
                height: implicitHeight
                valueField: valueInput
                TextField {
                    id: valueInput
                    width: valueViewport.contentWidth
                    autoScroll: false
                    background: null
                    placeholderText: "Value"
                    font.pixelSize: 18
                    selectByMouse: !valueViewport.touchInputActive
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
            && caret.y + caret.height <= viewport.contentItem.contentY + viewport.availableHeight + 1
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
        tryCompare(viewport, "availableHeight", 3 * editor.cursorRectangle.height)
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
        const end = Math.max(0, viewport.contentItem.contentHeight - viewport.availableHeight)
        viewport.contentItem.contentY = end
        mouseWheel(viewport, viewport.width / 2, viewport.height / 2, 0, -1200, Qt.NoButton)
        wait(200)
        verify(viewport.contentItem.contentY <= end + 1)
        keyClick(Qt.Key_Down)
        tryVerify(caretIsVisible)
    }

    function showBothScrollbars() {
        editor.text = ("1234567890".repeat(9) + "+\u200b").repeat(15)
        editor.cursorPosition = 0
        tryCompare(viewport.ScrollBar.horizontal, "visible", true)
        tryCompare(viewport.ScrollBar.vertical, "visible", true)
        verify(waitForRendering(viewport))
        viewport.contentItem.cancelFlick()
        viewport.contentItem.contentX = 0
        viewport.contentItem.contentY = 0
    }

    function test_native_scrollbars_reserve_space_and_disappear_for_short_input() {
        showBothScrollbars()
        const horizontal = viewport.ScrollBar.horizontal
        const vertical = viewport.ScrollBar.vertical
        verify(horizontal.height >= horizontal.implicitHeight)
        verify(vertical.width >= vertical.implicitWidth)
        verify(horizontal.y >= viewport.topPadding + viewport.availableHeight - 1)
        verify(vertical.x >= viewport.leftPadding + viewport.availableWidth - 1)
        verify(horizontal.y + horizontal.height <= viewport.height + 1)
        verify(vertical.x + vertical.width <= viewport.width + 1)
        compare(viewport.availableHeight, viewport.maximumTextHeight)
        editor.text = "12+3"
        tryCompare(horizontal, "visible", false)
        tryCompare(vertical, "visible", false)
        compare(viewport.rightPadding, 0)
        compare(viewport.bottomPadding, 0)
    }

    function test_single_line_value_keeps_full_padding_without_vertical_overflow() {
        const freshWindow = createTemporaryObject(valueWindowComponent, null)
        verify(freshWindow)
        const field = freshWindow.expressionEditor
        const view = freshWindow.expressionViewport
        field.text = "1234567890".repeat(12)
        tryCompare(view.ScrollBar.horizontal, "visible", true)
        tryCompare(view.ScrollBar.vertical, "visible", false)
        field.cursorPosition = field.text.length
        tryVerify(function() { return view.contentItem.contentX > 0 })
        compare(view.contentItem.contentY, 0)
        verify(field.cursorRectangle.height <= view.availableHeight)
        view.width = 100
        tryVerify(function() {
            return field.cursorRectangle.x + field.cursorRectangle.width
                <= view.contentItem.contentX + view.availableWidth + 1
        })
        field.text = "42"
        tryCompare(view.ScrollBar.horizontal, "visible", false)
        tryCompare(view.ScrollBar.vertical, "visible", false)
        freshWindow.close()
        testWindow.requestActivate()
    }

    function test_horizontal_wheel_and_drag_preserve_text_and_caret() {
        showBothScrollbars()
        const original = editor.text
        mouseWheel(viewport, viewport.width / 2, viewport.height / 2, -120, 0)
        tryVerify(function() { return viewport.contentItem.contentX > 0 })
        wait(250)
        viewport.contentItem.cancelFlick()
        viewport.contentItem.contentX = 0
        const bar = viewport.ScrollBar.horizontal
        mouseDrag(bar, bar.width * bar.size / 2, bar.height / 2, 75, 0, Qt.LeftButton)
        tryVerify(function() { return viewport.contentItem.contentX > 0 })
        compare(editor.cursorPosition, 0)
        compare(editor.text, original)
        const end = viewport.contentItem.contentWidth - viewport.availableWidth
        viewport.contentItem.contentX = end
        mouseWheel(viewport, viewport.width / 2, viewport.height / 2, -1200, 0)
        wait(250)
        verify(viewport.contentItem.contentX <= end + 1)
    }

    function test_vertical_scrollbar_drag_and_native_middle_click() {
        showBothScrollbars()
        const bar = viewport.ScrollBar.vertical
        mouseDrag(bar, bar.width / 2, bar.height * bar.size / 2, 0, 30, Qt.LeftButton)
        tryVerify(function() { return viewport.contentItem.contentY > 0 })
        compare(editor.cursorPosition, 0)
        if (bar.background && (bar.background.acceptedButtons & Qt.MiddleButton)) {
            viewport.contentItem.contentY = 0
            mouseClick(bar, bar.width / 2, bar.height * 0.75, Qt.MiddleButton)
            tryVerify(function() { return viewport.contentItem.contentY > 0 })
        }
    }

    function test_horizontal_gesture_keeps_manual_pan_until_typing_data() {
        return [{tag: "narrow", width: 340}, {tag: "wide", width: 620}]
    }

    function test_horizontal_gesture_keeps_manual_pan_until_typing(data) {
        testWindow.width = data.width
        editor.text = ("200\u200b+100\u200b+600\u200b+50\u200b+").repeat(20)
            + "1".repeat(180) + "\u200b+3"
        editor.cursorPosition = editor.text.length
        tryCompare(viewport.contentItem, "contentX", 0)
        verify(waitForRendering(editor))
        tryVerify(caretIsVisible)
        const original = editor.text
        const cursor = editor.cursorPosition
        const vertical = viewport.contentItem.contentY
        mouseWheel(viewport, 40, 12, -24, 0)
        tryVerify(function() { return viewport.contentItem.contentX > 0 })
        wait(450)
        verify(viewport.contentItem.contentX > 0, "caret following must not undo manual horizontal scrolling")
        compare(viewport.contentItem.contentY, vertical)
        compare(editor.cursorPosition, cursor)
        compare(editor.text, original)
        keyClick(Qt.Key_4)
        tryCompare(viewport.contentItem, "contentX", 0)
        verify(editor.text.endsWith("+34"))
        verify(caretIsVisible())
    }

    function test_conversion_horizontal_gesture_preserves_value_and_caret() {
        const freshWindow = createTemporaryObject(valueWindowComponent, null)
        verify(freshWindow)
        freshWindow.requestActivate()
        tryVerify(function() { return freshWindow.active })
        const field = freshWindow.expressionEditor
        const view = freshWindow.expressionViewport
        field.forceActiveFocus()
        tryVerify(function() { return field.activeFocus })
        field.text = "1234567890".repeat(20)
        field.cursorPosition = field.text.length
        tryVerify(function() { return view.contentItem.contentX > 0 })
        const original = field.text
        const cursor = field.cursorPosition
        mouseWheel(view, 40, 12, 12000, 0)
        tryCompare(view.contentItem, "contentX", 0)
        mouseWheel(view, 40, 12, -24, 0)
        tryVerify(function() { return view.contentItem.contentX > 0 })
        wait(450)
        verify(view.contentItem.contentX > 0)
        compare(view.contentItem.contentY, 0)
        compare(field.cursorPosition, cursor)
        compare(field.text, original)
        keyClick(Qt.Key_4)
        tryVerify(function() {
            return field.cursorRectangle.x + field.cursorRectangle.width
                <= view.contentItem.contentX + view.availableWidth + 1
        })
        verify(field.text.endsWith("04"))
        freshWindow.close()
        testWindow.requestActivate()
    }

    function test_horizontal_touch_drag_and_keyboard_follow_caret() {
        showBothScrollbars()
        const sequence = touchEvent(viewport)
        sequence.press(0, viewport, viewport.availableWidth - 5, 10).commit()
        wait(20)
        for (let x = viewport.availableWidth - 10; x >= 10; x -= 10) {
            sequence.move(0, viewport, x, 10).commit()
            wait(20)
        }
        sequence.release(0, viewport, 10, 10).commit()
        tryVerify(function() { return viewport.contentItem.contentX > 0 })
        verify(viewport.contentItem.interactive)
        viewport.contentItem.cancelFlick()
        keyClick(Qt.Key_End)
        tryVerify(function() {
            return editor.cursorRectangle.x + editor.cursorRectangle.width
                <= viewport.contentItem.contentX + viewport.availableWidth + 1
        })
        keyClick(Qt.Key_Home)
        tryCompare(viewport.contentItem, "contentX", 0)
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
