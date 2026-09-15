import QtQuick
import QtQuick.Controls
import QtTest
import "../../qml" as Calculator

TestCase {
    id: testCase
    name: "UndoShortcuts"
    when: testWindow.visible && testWindow.active

    property int undoCount: 0
    property int redoCount: 0

    ApplicationWindow {
        id: testWindow
        width: 400
        height: 200
        visible: true

        TextArea {
            id: focusedEditor
            anchors.fill: parent
            focus: true
            text: "14"
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
                if (shortcuts.handleFocusedEditorKey(event.key, event.modifiers))
                    event.accepted = true
            }
        }

        Calculator.UndoShortcuts {
            id: shortcuts
            onUndoRequested: testCase.undoCount++
            onRedoRequested: testCase.redoCount++
        }
    }

    function init() {
        undoCount = 0
        redoCount = 0
        testWindow.requestActivate()
        focusedEditor.forceActiveFocus()
        tryVerify(function() { return focusedEditor.activeFocus })
    }

    function test_ctrl_z_with_editor_focus() {
        keyClick(Qt.Key_Z, Qt.ControlModifier)
        compare(undoCount, 1)
        compare(redoCount, 0)
        compare(focusedEditor.text, "14")
    }

    function test_ctrl_y_with_editor_focus() {
        keyClick(Qt.Key_Y, Qt.ControlModifier)
        compare(undoCount, 0)
        compare(redoCount, 1)
        compare(focusedEditor.text, "14")
    }

    function test_ctrl_shift_z_with_editor_focus() {
        keyClick(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier)
        compare(undoCount, 0)
        compare(redoCount, 1)
        compare(focusedEditor.text, "14")
    }
}
