import QtQuick
import QtTest
import "../../qml" as Calculator

TestCase {
    name: "RootNotation"

    Calculator.RootNotation { id: notation }

    function test_named_root_symbols() {
        compare(notation.symbol(2), "√")
        compare(notation.symbol(3), "∛")
        compare(notation.symbol(4), "∜")
        compare(notation.symbol(5), "⁵√")
        compare(notation.symbol(10), "¹⁰√")
        compare(notation.symbol(25), "²⁵√")
        compare(notation.symbol(999), "⁹⁹⁹√")
    }

    function test_one_hundred_interface_roots_are_symbolic() {
        const allowed = "⁰¹²³⁴⁵⁶⁷⁸⁹√∛∜"
        for (let degree = 2; degree < 102; ++degree) {
            const symbol = notation.symbol(degree)
            verify(symbol.length > 0, degree)
            verify(symbol.indexOf("root") === -1, degree)
            for (let index = 0; index < symbol.length; ++index)
                verify(allowed.indexOf(symbol.charAt(index)) >= 0,
                       degree + ": " + symbol)
        }
    }
}
