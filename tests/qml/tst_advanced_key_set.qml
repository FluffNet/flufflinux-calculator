import QtQuick
import QtTest
import "../../qml" as Calculator

TestCase {
    name: "AdvancedKeySet"

    Calculator.AdvancedKeySet { id: keys }

    function test_layout_has_no_duplicate_buttons() {
        compare(keys.leftKeys.length, 25)
        compare(keys.rightKeys.length, 19)
        compare(keys.duplicates().length, 0)
    }

    function test_shared_operations_only_appear_on_the_right() {
        for (const label of ["x²", "√", "x⁻¹"]) {
            verify(keys.leftKeys.indexOf(label) === -1, label)
            verify(keys.rightKeys.indexOf(label) >= 0, label)
        }
    }

    function test_replacement_scientific_functions_are_unique() {
        for (const label of ["log", "ln", "exp"]) {
            compare(keys.leftKeys.filter(function(key) { return key === label }).length,
                    1, label)
            verify(keys.rightKeys.indexOf(label) === -1, label)
        }
    }
}
