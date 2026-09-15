import QtQuick
import QtQuick.Controls
import QtTest
import "../../qml" as Calculator

TestCase {
    id: testCase
    name: "ClearShortcuts"
    when: testWindow.visible && testWindow.active

    property int clearCount: 0

    ApplicationWindow {
        id: testWindow
        width: 400
        height: 200
        visible: true

        TextArea {
            id: focusedEditor
            anchors.fill: parent
            focus: true
            text: "98765"
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
                if (shortcuts.handleFocusedEditorKey(event.key, event.modifiers)) {
                    event.accepted = true
                }
            }
        }

        Calculator.ClearShortcuts {
            id: shortcuts
            onClearRequested: {
                testCase.clearCount++
                focusedEditor.clear()
            }
        }
    }

    function init() {
        clearCount = 0
        focusedEditor.text = "98765"
        testWindow.requestActivate()
        focusedEditor.forceActiveFocus()
        tryVerify(function() { return focusedEditor.activeFocus })
    }

    function test_escape_with_editor_focus() {
        keyClick(Qt.Key_Escape)
        compare(clearCount, 1)
        compare(focusedEditor.text, "")
    }

    function test_modified_escape_is_ignored_by_editor_handler() {
        verify(!shortcuts.handleFocusedEditorKey(Qt.Key_Escape,
                                                 Qt.ShiftModifier))
        compare(clearCount, 0)
        compare(focusedEditor.text, "98765")
    }
}
