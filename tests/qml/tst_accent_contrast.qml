import QtQuick
import QtTest
import "../../qml" as Calculator

TestCase {
    name: "AccentContrast"

    Calculator.AccentContrast { id: contrast }

    function verifyColor(actual, expected) {
        verify(Qt.colorEqual(actual, expected),
               "Expected " + expected + ", got " + actual)
    }

    function test_black_and_white_neutral_extremes() {
        verifyColor(contrast.textColor(Qt.rgba(0, 0, 0, 1), false),
                    Qt.rgba(1, 1, 1, 1))
        verifyColor(contrast.textColor(Qt.rgba(1, 1, 1, 1), true),
                    Qt.rgba(0, 0, 0, 1))
    }

    function test_neutral_grays_follow_brightness() {
        const darkGray = Qt.rgba(0.25, 0.25, 0.25, 1)
        const middleGray = Qt.rgba(0.5, 0.5, 0.5, 1)
        verifyColor(contrast.textColor(darkGray, false),
                    Qt.rgba(1, 1, 1, 1))
        verifyColor(contrast.textColor(middleGray, false),
                    Qt.rgba(0, 0, 0, 1))
        verifyColor(contrast.textColor(darkGray, true),
                    Qt.rgba(1, 1, 1, 1))
        verifyColor(contrast.textColor(middleGray, true),
                    Qt.rgba(0, 0, 0, 1))
    }

    function test_colored_accents_follow_window_theme() {
        const red = Qt.rgba(0.51, 0.004, 0.004, 1)
        const blue = Qt.rgba(0, 0.34, 0.72, 1)
        verifyColor(contrast.textColor(red, false), Qt.rgba(0, 0, 0, 1))
        verifyColor(contrast.textColor(red, true), Qt.rgba(1, 1, 1, 1))
        verifyColor(contrast.textColor(blue, false), Qt.rgba(0, 0, 0, 1))
        verifyColor(contrast.textColor(blue, true), Qt.rgba(1, 1, 1, 1))
    }

    function test_neutral_fills_are_not_recolored() {
        const black = Qt.rgba(0, 0, 0, 1)
        const gray = Qt.rgba(0.5, 0.5, 0.5, 1)
        const white = Qt.rgba(1, 1, 1, 1)
        verifyColor(contrast.fillColor(black), black)
        verifyColor(contrast.fillColor(gray), gray)
        verifyColor(contrast.fillColor(white), white)
    }
}
