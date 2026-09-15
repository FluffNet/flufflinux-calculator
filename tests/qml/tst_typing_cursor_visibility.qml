import QtQuick
import QtTest
import "../../qml" as Calculator

TestCase {
    id: testCase
    name: "TypingCursorVisibility"

    Calculator.TypingCursorVisibility {
        id: controller
        revealDelay: 80
    }

    function init() {
        controller.revealNow()
    }

    function test_hides_until_typing_stops() {
        controller.typingActivity()
        compare(controller.cursorVisible, false)
        verify(controller.waiting)
        tryVerify(function() { return controller.cursorVisible }, 250)
        compare(controller.waiting, false)
    }

    function test_new_input_restarts_delay() {
        controller.typingActivity()
        wait(50)
        controller.typingActivity()
        wait(50)
        compare(controller.cursorVisible, false)
        tryVerify(function() { return controller.cursorVisible }, 200)
    }

    function test_navigation_can_reveal_immediately() {
        controller.typingActivity()
        controller.revealNow()
        compare(controller.cursorVisible, true)
        compare(controller.waiting, false)
    }
}
