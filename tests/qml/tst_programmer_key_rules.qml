import QtQuick
import QtTest
import "../../qml" as Calculator

TestCase {
    name: "ProgrammerKeyRules"

    Calculator.ProgrammerKeyRules { id: rules }

    function test_clear_key_names() {
        verify(rules.isClearKey("CLR", true))
        verify(rules.isClearKey("C", false))
        verify(!rules.isClearKey("C", true))
        verify(!rules.isClearKey("A", false))
    }

    function test_hexadecimal_letters() {
        for (const label of ["A", "B", "C", "D", "E", "F"])
            verify(rules.isHexDigit(label), label)
        for (const label of ["CLR", "0", "9", "+", "mod"])
            verify(!rules.isHexDigit(label), label)
    }

    function test_radix_matrix_100() {
        const bases = [2, 8, 10, 16]
        const labels = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
                        "A", "B", "C", "D", "E", "F", ".", "%", "x⁻¹",
                        "CLR", "mod", "∧", "∨", "⊻", "≪"]
        let checked = 0
        for (const base of bases) {
            for (const label of labels) {
                const value = rules.digitValue(label)
                const decimalOnly = label === "." || label === "%" || label === "x⁻¹"
                const expected = value >= 0 ? value < base : decimalOnly ? base === 10 : true
                compare(rules.isKeyEnabled(label, base), expected, base + ": " + label)
                checked++
            }
        }
        compare(checked, 100)
    }

    function test_typed_radix_validation_and_function_names() {
        verify(rules.typingAllowed("0", 2, ""))
        verify(rules.typingAllowed("1", 2, ""))
        verify(!rules.typingAllowed("2", 2, ""))
        verify(!rules.typingAllowed("8", 8, ""))
        verify(!rules.typingAllowed("A", 10, ""))
        verify(!rules.typingAllowed("F", 2, ""))
        verify(rules.typingAllowed("A", 16, ""))
        verify(rules.typingAllowed("f", 16, ""))

        verify(rules.typingAllowed("a", 10, ""))
        verify(rules.typingAllowed("f", 2, ""))
        verify(rules.typingAllowed("2", 2, "log"))
        verify(!rules.typingAllowed("2", 2, "value_"))
        verify(!rules.typingAllowed("8", 2, "log"))
        verify(!rules.typingAllowed("d", 2, ""))
        verify(rules.typingAllowed("e", 10, "1"))
        verify(rules.typingAllowed("e", 10, ""))
        verify(rules.typingAllowed("p", 10, ""))
        verify(rules.typingAllowed("s", 10, ""))
        verify(rules.typingAllowed("x", 10, "e"))
        verify(rules.typingAllowed(".", 10, "1"))
        verify(rules.typingAllowed("%", 10, "1"))
        verify(!rules.typingAllowed(".", 16, "1"))
        verify(!rules.typingAllowed("%", 2, "1"))
    }

    function test_function_argument_separators_are_not_grouping_commas() {
        for (const expression of [
                 "root(3,8)", "nthroot(4,16)", "nand(1,2)", "nor(1,2)",
                 "rol(1,2)", "ror(1,2)", "ashr(8,1)", "lshr(8,1)"
             ]) {
            const comma = expression.indexOf(",")
            verify(rules.isArgumentSeparator(expression, comma), expression)
        }
        verify(!rules.isArgumentSeparator("1,000", 1))
        verify(!rules.isArgumentSeparator("abs(1,000)", 5))
    }

    function test_every_insertable_button_mapping() {
        const expected = {
            "x²": "^2", "xʸ": "^", "twos": "twos(", "⌈x⌉": "ceil(",
            "∧": "∧", "∨": "∨", "log₂": "log2(", "swap": "swap(",
            "⌊x⌋": "floor(", "¬": "¬", "⊻": "⊻", "log": "log(",
            "int": "int(", "|x|": "abs(", "≪": "≪", "≫": "≫",
            "ln": "ln(", "frac": "frac(", "round": "round(", "x!": "!", "÷": "/",
            "×": "*", "−": "-", "+": "+", "mod": " mod ",
            "x⁻¹": "^(-1)", "%": "%", ".": "."
        }
        for (const label in expected)
            compare(rules.inputText(label, false), expected[label], label)
        for (const label of ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
                             "A", "B", "C", "D", "E", "F"])
            compare(rules.inputText(label, false), label)
        compare(rules.inputText("x²", true), "sqrt(")
        compare(rules.inputText("x²", false, 2), "^10")
        compare(rules.inputText("x²", false, 8), "^2")
        compare(rules.inputText("x²", false, 10), "^2")
        compare(rules.inputText("x²", false, 16), "^2")
    }

    function test_every_special_key_has_help() {
        const keys = ["⇧⁻¹", "x²", "xʸ", "twos", "⌈x⌉", "∧", "∨",
                      "log₂", "swap", "⌊x⌋", "¬", "⊻", "log", "int", "|x|", "≪",
                      "≫", "ln", "frac", "round", "x!", "CLR", "±", "%", "mod", "()", "x⁻¹"]
        for (const label of keys)
            verify(rules.tooltip(label).length > 0, label)
    }

    function test_bit_rows_match_word_size() {
        const cases = [
            [8, 8, 1, 7, 7],
            [16, 8, 2, 15, 7],
            [32, 8, 4, 31, 7],
            [64, 8, 8, 63, 7],
            [128, 8, 16, 127, 7],
            [4096, 8, 512, 4095, 7]
        ]
        for (const row of cases) {
            const starts = rules.bitRowStarts(row[0])
            compare(rules.bitsPerRow(row[0]), row[1], row[0] + " bits")
            compare(starts.length, row[2], row[0] + " row count")
            compare(starts[0], row[3], row[0] + " first row")
            compare(starts[starts.length - 1], row[4], row[0] + " last row")
            compare(rules.bitCountForRow(starts[starts.length - 1]), row[1],
                    row[0] + " final row width")
        }
    }

    function test_clickable_bit_toggle_matrix_100() {
        compare(rules.toggleBit("0", 8, 0), "00000001")
        compare(rules.toggleBit("0", 8, 7), "10000000")
        compare(rules.toggleBit("00000001", 8, 0), "00000000")

        const sizes = [8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096]
        for (let testIndex = 0; testIndex < 100; ++testIndex) {
            const bits = sizes[testIndex % sizes.length]
            const bitIndex = (testIndex * 17) % Math.min(bits, 64)
            const toggled = rules.toggleBit("0", bits, bitIndex)
            compare(toggled.length, bits, testIndex + ": width")
            compare(toggled.charAt(bits - 1 - bitIndex), "1", testIndex + ": set")
            compare(rules.toggleBit(toggled, bits, bitIndex), "0".repeat(bits),
                    testIndex + ": clear")
        }
    }

    function test_every_word_size_toggles_low_middle_and_high_bits() {
        const sizes = [8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096]
        let checked = 0
        for (const bits of sizes) {
            const indexes = [0, Math.floor(bits / 2), bits - 1]
            for (const bitIndex of indexes) {
                const toggled = rules.toggleBit("0", bits, bitIndex)
                compare(toggled.length, bits, bits + "-bit width")
                compare(toggled.charAt(bits - 1 - bitIndex), "1",
                        bits + "-bit position " + bitIndex)
                compare(rules.toggleBit(toggled, bits, bitIndex), "0".repeat(bits),
                        bits + "-bit clear " + bitIndex)
                checked++
            }
        }
        compare(checked, 30)
    }

    function test_programmer_preview_formatting() {
        compare(rules.formatPreviewValue("FF", 16), "FF")
        compare(rules.formatPreviewValue("FFFFF", 16), "F FFFF")
        compare(rules.formatPreviewValue("9032", 10), "9,032")
        compare(rules.formatPreviewValue("-1234567", 10), "-1,234,567")
        compare(rules.formatPreviewValue("1234.5", 10), "1,234.5")
        compare(rules.formatPreviewValue("1234.5e+20", 10), "1,234.5e+20")
        compare(rules.formatPreviewValue("21510", 8), "21 510")
        compare(rules.formatPreviewValue("11111111", 2), "1111 1111")
        compare(rules.formatPreviewValue("10001101001000", 2),
                "0010 0011 0100 1000")
        compare(rules.formatPreviewValue("1", 2), "0001")
        compare(rules.formatPreviewValue("0", 2), "0")

        const values = ["1", "10", "101", "1111", "10000", "101010",
                        "11111111", "100000000", "101010101010"]
        let checked = 0
        for (let index = 0; index < 100; ++index) {
            const raw = values[index % values.length]
            const formatted = rules.formatPreviewValue(raw, 2)
            compare(formatted.replace(/[ ,]/g, "").slice(-raw.length), raw,
                    index + ": digits")
            verify(!formatted.includes("..."), index + ": no ellipsis")
            checked++
        }
        compare(checked, 100)
    }

    function test_every_supported_bit_row_endpoint() {
        const sizes = [8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096]
        let checked = 0
        for (const bits of sizes) {
            const starts = rules.bitRowStarts(bits)
            for (let rowIndex = 0; rowIndex < starts.length; ++rowIndex) {
                const expectedStart = bits - 1 - rowIndex * 8
                const expectedEnd = Math.max(0, expectedStart - 7)
                const count = rules.bitCountForRow(starts[rowIndex])
                compare(starts[rowIndex], expectedStart,
                        bits + " bits, row " + rowIndex + " start")
                compare(starts[rowIndex] - count + 1, expectedEnd,
                        bits + " bits, row " + rowIndex + " end")
                checked++
            }
        }
        compare(checked, 1023)
    }
}
