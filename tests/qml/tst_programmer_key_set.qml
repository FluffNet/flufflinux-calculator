import QtQuick
import QtTest
import "../../qml" as Calculator

TestCase {
    name: "ProgrammerKeySet"

    Calculator.ProgrammerKeySet { id: keys }

    function test_layout_has_no_duplicate_buttons() {
        compare(keys.padKeys.length, 28)
        compare(keys.duplicates().length, 0)
        compare(keys.padKeys.indexOf("⌫"), -1)
    }

    function test_clear_and_hex_c_have_distinct_labels() {
        compare(keys.padKeys.filter(function(label) { return label === "CLR" }).length, 1)
        compare(keys.padKeys.filter(function(label) { return label === "C" }).length, 1)
        compare(keys.padKeys.filter(function(label) { return label === "x²" }).length, 0)
    }

    function test_keypad_matches_programmer_layout() {
        compare(keys.padKeys.slice(0, 5).join("|"), "A|≪|≫|CLR|÷")
        compare(keys.padKeys.slice(24).join("|"), "F|±|0|.")
        compare(keys.rowForIndex(23), 4)
        compare(keys.columnForIndex(23), 3)
        compare(keys.rowForIndex(24), 5)
        compare(keys.columnForIndex(27), 3)
    }
}
