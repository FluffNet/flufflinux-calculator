import QtQuick
import QtQuick.Controls
import QtTest
import "../../qml" as Calculator

TestCase {
    id: testCase
    name: "ProgrammerControlRow"
    when: testWindow.visible && testWindow.active

    property int viewRequestCount: 0
    property int requestedView: -1
    property int bitwiseRequestCount: 0
    property string requestedBitwiseOperation: ""
    property int bitShiftRequestCount: 0
    property string requestedBitShiftOperation: ""

    ApplicationWindow {
        id: testWindow
        width: 468
        height: 420
        visible: true

        Calculator.ProgrammerControlRow {
            id: controls
            x: 10
            y: 20
            width: 448

            onViewRequested: function(view) {
                testCase.viewRequestCount++
                testCase.requestedView = view
                controls.currentView = view
            }
            onBitwiseOperationRequested: function(operation) {
                testCase.bitwiseRequestCount++
                testCase.requestedBitwiseOperation = operation
            }
            onBitShiftOperationRequested: function(operation) {
                testCase.bitShiftRequestCount++
                testCase.requestedBitShiftOperation = operation
            }
        }
    }

    function init() {
        controls.width = 448
        controls.bitwiseLabel = qsTr("Bitwise")
        controls.bitShiftLabel = qsTr("Bit shift")
        controls.closeMenus()
        tryVerify(function() {
            return !controls.bitwiseMenuOpened && !controls.bitShiftMenuOpened
        })
        controls.currentView = controls.keypadView
        viewRequestCount = 0
        requestedView = -1
        bitwiseRequestCount = 0
        requestedBitwiseOperation = ""
        bitShiftRequestCount = 0
        requestedBitShiftOperation = ""
        testWindow.requestActivate()
        tryVerify(function() { return testWindow.active })
        tryVerify(function() {
            return controls.commandButtonAt(2) !== null
        })
    }

    function clickControl(control) {
        mouseClick(control, control.width / 2, control.height / 2)
    }

    function test_default_api_matches_supported_programmer_operations() {
        compare(controls.keypadView, 0)
        compare(controls.bitPanelView, 1)
        compare(controls.currentView, controls.keypadView)

        compare(controls.bitwiseActions.length, 6)
        compare(controls.bitwiseActions[0].value, "∧")
        compare(controls.bitwiseActions[1].value, "∨")
        compare(controls.bitwiseActions[2].value, "⊻")
        compare(controls.bitwiseActions[3].value, "¬")
        compare(controls.bitwiseActions[4].value, "nand(")
        compare(controls.bitwiseActions[5].value, "nor(")

        compare(controls.bitShiftActions.length, 5)
        compare(controls.bitShiftActions[0].value, "≪")
        compare(controls.bitShiftActions[1].value, "≫")
        compare(controls.bitShiftActions[2].value, "ashr(")
        compare(controls.bitShiftActions[3].value, "rol(")
        compare(controls.bitShiftActions[4].value, "ror(")
    }

    function test_controls_are_ordered_without_overlap_or_elision() {
        tryVerify(function() {
            const first = controls.commandButtonAt(0)
            const second = controls.commandButtonAt(1)
            return second.x >= first.x + first.width
        })
        let previous = null
        for (let index = 0; index < 2; ++index) {
            const control = controls.commandButtonAt(index)
            verify(control.width > 0, "control " + index + " width")
            verify(control.height >= 44, "control " + index + " height")
            compare(control.contentItem.elide, Text.ElideNone)
            compare(control.contentItem.textFormat, Text.PlainText)
            if (previous !== null) {
                verify(control.x >= previous.x + previous.width,
                       "control " + index + " overlap")
            }
            previous = control
        }

        const toggle = controls.commandButtonAt(2)
        verify(toggle.width > 0)
        verify(toggle.height >= 44)
        verify(toggle.x >= previous.x + previous.width)
        compare(toggle.display, AbstractButton.IconOnly)

        compare(controls.background.color, controls.palette.window)
        compare(controls.commandButtonAt(0).contentItem.color,
                controls.commandButtonAt(0).palette.text)
    }

    function test_compact_controls_fit_basic_mode_width() {
        controls.width = 188
        tryVerify(function() { return controls.compact })

        const bitwise = controls.commandButtonAt(0)
        const shift = controls.commandButtonAt(1)
        const toggle = controls.commandButtonAt(2)
        tryVerify(function() {
            return toggle.x + toggle.width <= controls.width
        })
        compare(bitwise.text, "∧▾")
        compare(shift.text, "≪▾")
        verify(bitwise.width >= 48, "bitwise width " + bitwise.width)
        compare(toggle.width, bitwise.width)
        compare(toggle.height, bitwise.height)
        verify(shift.x >= bitwise.x + bitwise.width,
               "shift geometry " + shift.x + " after "
                   + (bitwise.x + bitwise.width))
        verify(toggle.x >= shift.x + shift.width,
               "toggle geometry " + toggle.x + " after "
                   + (shift.x + shift.width))
        verify(toggle.x + toggle.width <= controls.width)
    }

    function test_long_translated_labels_switch_to_compact_controls() {
        controls.bitwiseLabel = "Very long localized bitwise operations label"
        controls.bitShiftLabel = "Very long localized bit shift operations label"
        controls.width = 448

        tryVerify(function() { return controls.compact })
        compare(controls.commandButtonAt(0).text, "∧▾")
        compare(controls.commandButtonAt(1).text, "≪▾")
        verify(controls.commandButtonAt(2).x
               + controls.commandButtonAt(2).width <= controls.width)
    }

    function test_single_icon_view_toggle_dispatches_once() {
        const toggle = controls.viewToggleControl()
        verify(!toggle.showsKeypadAction)
        compare(toggle.Accessible.name, "Show bits")
        verify(toggle.contentItem.implicitWidth > 0)

        clickControl(toggle)
        compare(viewRequestCount, 1)
        compare(requestedView, controls.bitPanelView)
        verify(toggle.showsKeypadAction)
        compare(toggle.Accessible.name, "Show keypad")
        verify(toggle.contentItem.implicitWidth > 0)

        toggle.forceActiveFocus(Qt.TabFocusReason)
        tryCompare(toggle, "activeFocus", true)
        keyClick(Qt.Key_Space)
        compare(viewRequestCount, 2)
        compare(requestedView, controls.keypadView)
        verify(!toggle.showsKeypadAction)
        compare(toggle.Accessible.name, "Show bits")
    }

    function test_bitwise_menu_dispatches_every_action() {
        for (let index = 0; index < controls.bitwiseActions.length; ++index) {
            controls.openBitwiseMenu()
            tryVerify(function() { return controls.bitwiseMenuOpened })
            tryVerify(function() { return controls.bitwiseActionAt(index) !== null })
            const action = controls.bitwiseActionAt(index)
            compare(action.contentItem.elide, Text.ElideNone)
            compare(action.contentItem.textFormat, Text.PlainText)
            compare(action.text, controls.bitwiseActions[index].text)
            mouseClick(action, action.width / 2, action.height / 2)
            compare(bitwiseRequestCount, index + 1)
            compare(requestedBitwiseOperation,
                    controls.bitwiseActions[index].value)
            tryVerify(function() { return !controls.bitwiseMenuOpened })
        }
    }

    function test_bit_shift_menu_dispatches_every_action() {
        for (let index = 0; index < controls.bitShiftActions.length; ++index) {
            controls.openBitShiftMenu()
            tryVerify(function() { return controls.bitShiftMenuOpened })
            tryVerify(function() { return controls.bitShiftActionAt(index) !== null })
            const action = controls.bitShiftActionAt(index)
            compare(action.contentItem.elide, Text.ElideNone)
            compare(action.contentItem.textFormat, Text.PlainText)
            compare(action.text, controls.bitShiftActions[index].text)
            mouseClick(action, action.width / 2, action.height / 2)
            compare(bitShiftRequestCount, index + 1)
            compare(requestedBitShiftOperation,
                    controls.bitShiftActions[index].value)
            tryVerify(function() { return !controls.bitShiftMenuOpened })
        }
    }

    function test_menu_button_keyboard_access() {
        const bitwise = controls.commandButtonAt(0)
        bitwise.forceActiveFocus(Qt.TabFocusReason)
        tryCompare(bitwise, "visualFocus", true)
        keyClick(Qt.Key_Space)
        tryVerify(function() { return controls.bitwiseMenuOpened })
        keyClick(Qt.Key_Escape)
        tryVerify(function() { return !controls.bitwiseMenuOpened })
    }

    function test_visible_text_contains_no_long_dash_characters() {
        const texts = [
            controls.commandButtonAt(0).text,
            controls.commandButtonAt(1).text
        ]
        for (const action of controls.bitwiseActions) texts.push(action.text)
        for (const action of controls.bitShiftActions) texts.push(action.text)
        for (const value of texts) verify(!/[\u2013\u2014]/.test(value), value)
    }
}
