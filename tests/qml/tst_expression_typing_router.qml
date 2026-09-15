import QtQuick
import QtTest
import "../../qml" as Calculator

TestCase {
    name: "ExpressionTypingRouter"

    Calculator.ExpressionTypingRouter { id: router }

    function test_backspace_is_an_action_not_text() {
        compare(router.actionForEvent(Qt.Key_Backspace,
                                      Qt.NoModifier,
                                      "\b"),
                "backspace")
    }

    function test_escape_clears_instead_of_becoming_text() {
        compare(router.actionForEvent(Qt.Key_Escape,
                                      Qt.NoModifier,
                                      "\u001b"),
                "clear")
    }

    function test_control_characters_are_never_inserted() {
        const controls = ["\u0000", "\b", "\t", "\n", "\r", "\u001b", "\u007f"]
        for (const character of controls) {
            compare(router.actionForEvent(Qt.Key_unknown,
                                          Qt.NoModifier,
                                          character),
                    "ignore")
        }
    }

    function test_regular_typing_and_shortcuts() {
        compare(router.actionForEvent(Qt.Key_2, Qt.NoModifier, "2"), "insert")
        compare(router.actionForEvent(Qt.Key_Plus, Qt.NoModifier, "+"), "insert")
        compare(router.actionForEvent(Qt.Key_unknown, Qt.NoModifier, "√"), "insert")
        compare(router.actionForEvent(Qt.Key_unknown, Qt.NoModifier, "∛"), "insert")
        compare(router.actionForEvent(Qt.Key_unknown, Qt.NoModifier, "∜"), "insert")
        compare(router.actionForEvent(Qt.Key_I, Qt.NoModifier, "i"), "insert")
        compare(router.actionForEvent(Qt.Key_unknown, Qt.NoModifier, "ⅈ"), "insert")
        compare(router.actionForEvent(Qt.Key_A, Qt.ControlModifier, "a"), "selectAll")
        compare(router.actionForEvent(Qt.Key_V, Qt.ControlModifier, "v"), "paste")
        compare(router.actionForEvent(Qt.Key_C, Qt.ControlModifier, "c"), "ignore")
    }
}
