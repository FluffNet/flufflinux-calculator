import QtQuick
import QtQuick.Controls
import QtTest
import "../../qml" as Calculator

TestCase {
    id: testCase
    name: "ExpressionEditorSync"
    when: testWindow.visible && testWindow.active
    property int inputWrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
    property bool trackInput: false
    property real minimumScroll: 0
    property int minimumCursor: 0
    property int inputEdits: 0

    function isFormattingCharacter(text, index) {
        return text[index] === "\u200b"
            || (text[index] === "," && !rules.isArgumentSeparator(text, index))
    }

    function logicalCursorIndex(text, position) {
        let index = 0
        for (let i = 0; i < position; i++) {
            if (!isFormattingCharacter(text, i)) index++
        }
        return index
    }

    function editorCursorPosition(text, logicalIndex) {
        if (logicalIndex === 0) return 0
        let index = 0
        for (let i = 0; i < text.length; i++) {
            if (!isFormattingCharacter(text, i)) index++
            if (index === logicalIndex) {
                let position = i + 1
                while (position < text.length && isFormattingCharacter(text, position)) position++
                return position
            }
        }
        return text.length
    }

    Calculator.ProgrammerKeyRules { id: rules }

    QtObject {
        id: backend
        property string expression: ""
        property bool grouping: false
        property int applyCount: 0
        function applyExpression(text) {
            applyCount++
            let normalized = text.replace(/\u200b/g, "").replace(/\$/g, "")
            if (grouping) {
                normalized = normalized.replace(/[0-9][0-9,]*/g, function(number) {
                    return number.replace(/,/g, "").replace(/\B(?=(\d{3})+(?!\d))/g, ",")
                })
            }
            expression = normalized.replace(/([+*/-])/g, "\u200b$1")
        }
    }

    ApplicationWindow {
        id: testWindow
        width: 340
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
                wrapMode: testCase.inputWrapMode
                selectByMouse: !viewport.touchInputActive
            }
        }
    }

    Calculator.ExpressionEditorSync {
        calculatorBackend: backend
        expressionEditor: editor
        logicalCursorIndex: testCase.logicalCursorIndex
        editorCursorPosition: testCase.editorCursorPosition
        onInputEdited: testCase.inputEdits++
    }

    Connections {
        target: viewport.contentItem
        function onContentYChanged() {
            if (testCase.trackInput)
                testCase.minimumScroll = Math.min(testCase.minimumScroll, viewport.contentItem.contentY)
        }
    }

    Connections {
        target: editor
        function onCursorPositionChanged() {
            if (testCase.trackInput)
                testCase.minimumCursor = Math.min(testCase.minimumCursor, editor.cursorPosition)
        }
    }

    function init() {
        trackInput = false
        inputWrapMode = TextEdit.WrapAtWordBoundaryOrAnywhere
        testWindow.width = 340
        backend.grouping = false
        backend.applyExpression("")
        testWindow.requestActivate()
        editor.forceActiveFocus()
        tryVerify(function() { return editor.activeFocus })
        inputEdits = 0
        backend.applyCount = 0
    }

    function test_repeated_plus_three_never_resets_scroll_or_caret_data() {
        return [{tag:"narrow", width:340, grouping:false},
                {tag:"wide", width:620, grouping:false},
                {tag:"narrow_grouped", width:340, grouping:true},
                {tag:"wide_grouped", width:620, grouping:true},
                {tag:"terms_narrow", width:340, grouping:false, wordWrap:true},
                {tag:"terms_wide_grouped", width:620, grouping:true, wordWrap:true}]
    }

    function test_repeated_plus_three_never_resets_scroll_or_caret(data) {
        testWindow.width = data.width
        backend.grouping = data.grouping
        inputWrapMode = data.wordWrap ? TextEdit.WordWrap : TextEdit.WrapAtWordBoundaryOrAnywhere
        const prefix = data.wordWrap ? ("1".repeat(13) + "+").repeat(20) : "1".repeat(13) + "+"
        backend.applyExpression(prefix + "1".repeat(230))
        verify(waitForRendering(editor))
        editor.cursorPosition = editor.text.length
        tryVerify(function() { return viewport.contentItem.contentY > 0 })
        wait(20)
        const startScroll = viewport.contentItem.contentY
        const startCursor = editor.cursorPosition
        minimumScroll = startScroll
        minimumCursor = startCursor
        backend.applyCount = 0
        trackInput = true
        for (let i = 0; i < 10; i++) {
            keyClick(Qt.Key_Plus)
            keyClick(Qt.Key_3)
            compare(editor.text, backend.expression)
            compare(editor.cursorPosition, editor.text.length)
            verify(waitForRendering(editor))
        }
        trackInput = false
        verify(minimumScroll >= startScroll - 1, "operator formatting must not scroll back to earlier text")
        verify(minimumCursor >= startCursor, "operator formatting must not reset the caret")
        compare(backend.applyCount, 20)
        compare(inputEdits, 20)
        verify(editor.text.replace(/\u200b/g, "").endsWith("+3".repeat(10)))
    }

    function test_wrapped_term_shows_operator_and_line_start_data() {
        return [{tag: "user_narrow_grouped", width: 340, grouping: true, digits: 36},
                {tag: "user_wide_grouped", width: 620, grouping: true, digits: 72},
                {tag: "user_narrow_plain", width: 340, grouping: false, digits: 36}]
    }

    function test_wrapped_term_shows_operator_and_line_start(data) {
        testWindow.width = data.width
        backend.grouping = data.grouping
        inputWrapMode = TextEdit.WordWrap
        const calculation = "200+200+200+100+600+50+200+200+100+100+100"
        backend.applyExpression(calculation + "+" + calculation + "+" + "1".repeat(data.digits))
        editor.cursorPosition = editor.text.length
        tryVerify(function() { return viewport.contentItem.contentX > 0 })
        keyClick(Qt.Key_Plus)
        verify(waitForRendering(editor))
        const plus = editor.text.lastIndexOf("+")
        tryCompare(viewport.contentItem, "contentX", 0)
        verify(editor.positionToRectangle(plus).y > editor.positionToRectangle(plus - 2).y)
        keyClick(Qt.Key_3)
        verify(waitForRendering(editor))
        compare(editor.positionToRectangle(plus).y, editor.positionToRectangle(plus + 1).y)
        tryCompare(viewport.contentItem, "contentX", 0)
        verify(editor.cursorRectangle.x + editor.cursorRectangle.width <= viewport.availableWidth)
        verify(editor.cursorRectangle.y >= viewport.contentItem.contentY - 1)
        compare(editor.cursorPosition, editor.text.length)
        verify(editor.text.replace(/\u200b/g, "").endsWith("+3"))
    }

    function test_legacy_wrap_hints_are_migrated_without_losing_input() {
        inputWrapMode = TextEdit.WordWrap
        backend.expression = ("200+\u200b").repeat(22) + "1".repeat(36) + "+\u200b3"
        editor.cursorPosition = editor.text.length
        keyClick(Qt.Key_Plus)
        keyClick(Qt.Key_3)
        verify(waitForRendering(editor))
        verify(editor.text.endsWith("\u200b+3\u200b+3"))
        compare(editor.cursorPosition, editor.text.length)
        tryCompare(viewport.contentItem, "contentX", 0)
    }

    function test_middle_edit_preserves_logical_cursor() {
        backend.applyExpression("12+34")
        editor.cursorPosition = editor.text.indexOf("3")
        keyClick(Qt.Key_9)
        compare(editor.text.replace(/\u200b/g, ""), "12+934")
        compare(editor.cursorPosition, editorCursorPosition(editor.text, 4))
    }

    function test_currency_removal_and_grouping_keep_typing_at_end() {
        backend.grouping = true
        keyClick(Qt.Key_Dollar)
        for (const key of [Qt.Key_1, Qt.Key_2, Qt.Key_3, Qt.Key_4, Qt.Key_5]) keyClick(key)
        compare(editor.text, "12,345")
        compare(editor.cursorPosition, editor.text.length)
        compare(inputEdits, 6)
    }

    function test_selection_is_replaced_by_typing() {
        backend.applyExpression("12345+6789")
        editor.select(0, 5)
        keyClick(Qt.Key_9)
        compare(editor.text.replace(/\u200b/g, ""), "9+6789")
        compare(editor.cursorPosition, 1)
        compare(editor.selectedText, "")
    }

    function test_external_expression_change_does_not_create_an_edit() {
        backend.applyExpression("41+1")
        compare(editor.text, backend.expression)
        compare(backend.applyCount, 1)
        compare(inputEdits, 0)
    }
}
