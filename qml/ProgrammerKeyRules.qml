import QtQuick

QtObject {
    readonly property var typedFunctionNames: [
        "abs", "acos", "acosh", "ashr", "asin", "asinh", "atan",
        "atanh", "ceil", "cos", "cosh", "e", "exp", "floor", "frac",
        "int", "ln", "log", "log10", "log2", "lshr", "nand", "nor",
        "pi", "rol", "ror", "round", "sin", "sinh", "sqrt", "swap",
        "tan", "tanh", "trunc", "twos"
    ]

    function isClearKey(label, programmingMode) {
        return label === "CLR" || (label === "C" && !programmingMode)
    }

    function digitValue(label) {
        if (label.length !== 1) return -1
        const code = label.charCodeAt(0)
        if (code >= 48 && code <= 57) return code - 48
        if (code >= 65 && code <= 70) return code - 65 + 10
        return -1
    }

    function isHexDigit(label) {
        const value = digitValue(label)
        return value >= 10 && value <= 15
    }

    function isKeyEnabled(label, base) {
        const value = digitValue(label)
        if (value >= 0) return value < base
        if (label === "." || label === "%" || label === "x⁻¹") return base === 10
        return true
    }

    function typingAllowed(text, base, textBeforeCursor) {
        if (text.length !== 1) return true
        if (text === "." || text === "%") return base === 10
        const value = digitValue(text.toUpperCase())
        if (value < 0) return true
        if (value >= 10 && base === 16) return true
        if (value < base) return true
        if (text !== text.toLowerCase() && value >= 10) return false

        const identifierMatch = /[A-Za-z_][A-Za-z0-9_]*$/.exec(textBeforeCursor)
        const candidate = ((identifierMatch && identifierMatch[0]) || "") + text
        return typedFunctionNames.some(function(name) {
            return name.startsWith(candidate.toLowerCase())
        })
    }

    function isArgumentSeparator(text, commaIndex) {
        if (commaIndex < 0 || commaIndex >= text.length
                || text.charAt(commaIndex) !== ",") return false

        let nesting = 0
        for (let openingIndex = commaIndex - 1;
             openingIndex >= 0; --openingIndex) {
            const character = text.charAt(openingIndex)
            if (character === ")") {
                nesting++
            } else if (character === "(" && nesting > 0) {
                nesting--
            } else if (character === "(") {
                let nameEnd = openingIndex
                while (nameEnd > 0
                       && /\s/.test(text.charAt(nameEnd - 1))) nameEnd--
                let nameStart = nameEnd
                while (nameStart > 0
                       && /[A-Za-z0-9_]/.test(text.charAt(nameStart - 1))) {
                    nameStart--
                }
                const name = text.slice(nameStart, nameEnd)
                const argumentFunctions = [
                    "root", "nthroot", "nand", "nor", "rol", "ror",
                    "ashr", "lshr"
                ]
                if (argumentFunctions.indexOf(name) < 0) return false

                let innerNesting = 0
                for (let index = openingIndex + 1;
                     index < commaIndex; ++index) {
                    const innerCharacter = text.charAt(index)
                    if (innerCharacter === "(") innerNesting++
                    else if (innerCharacter === ")" && innerNesting > 0)
                        innerNesting--
                    else if (innerCharacter === "," && innerNesting === 0)
                        return false
                }
                return true
            }
        }
        return false
    }

    function inputText(label, inverse, base) {
        if (inverse && label === "x²") return "sqrt("
        if (label === "x²") return base === 2 ? "^10" : "^2"
        const inputs = {
            "÷": "/", "×": "*", "−": "-", "mod": " mod ",
            "xʸ": "^", "x⁻¹": "^(-1)",
            "⌈x⌉": "ceil(", "⌊x⌋": "floor(", "|x|": "abs(",
            "log₂": "log2(", "x!": "!"
        }
        if (inputs[label] !== undefined) return inputs[label]
        if (["log", "ln", "int", "frac", "round", "twos", "swap"].indexOf(label) >= 0)
            return label + "("
        return label
    }

    function bitsPerRow(wordBits) {
        return 8
    }

    function bitRowStarts(wordBits) {
        const totalBits = Math.max(8, wordBits)
        const starts = []
        for (let bit = totalBits - 1; bit >= 0; bit -= 8) starts.push(bit)
        return starts
    }

    function bitCountForRow(rowStart) {
        return Math.min(8, rowStart + 1)
    }

    function toggleBit(binaryText, wordBits, bitIndex) {
        if (wordBits < 1 || bitIndex < 0 || bitIndex >= wordBits) return binaryText
        let normalized = binaryText.length > 0 ? binaryText : "0"
        if (!/^[01]+$/.test(normalized)) return binaryText
        if (normalized.length > wordBits) normalized = normalized.slice(-wordBits)
        while (normalized.length < wordBits) normalized = "0" + normalized
        const stringIndex = wordBits - 1 - bitIndex
        const replacement = normalized.charAt(stringIndex) === "1" ? "0" : "1"
        return normalized.slice(0, stringIndex) + replacement
            + normalized.slice(stringIndex + 1)
    }

    function formatPreviewValue(value, base) {
        if (value.length === 0 || value === "0") return value

        const negative = value.charAt(0) === "-"
        let digits = negative ? value.slice(1) : value
        let decimalSuffix = ""
        let exponentSuffix = ""
        if (base === 10) {
            const exponentIndex = digits.search(/[eE]/)
            if (exponentIndex >= 0) {
                exponentSuffix = digits.slice(exponentIndex)
                digits = digits.slice(0, exponentIndex)
            }
            const decimalIndex = digits.indexOf(".")
            if (decimalIndex >= 0) {
                decimalSuffix = digits.slice(decimalIndex)
                digits = digits.slice(0, decimalIndex)
            }
        }
        const groupSize = base === 8 || base === 10 ? 3 : 4
        const separator = base === 10 ? "," : " "
        if (base === 2) {
            while (digits.length % groupSize !== 0) digits = "0" + digits
        }
        const groups = []
        let firstGroupLength = digits.length % groupSize
        if (firstGroupLength === 0) firstGroupLength = groupSize
        groups.push(digits.slice(0, firstGroupLength))
        for (let index = firstGroupLength; index < digits.length; index += groupSize)
            groups.push(digits.slice(index, index + groupSize))
        return (negative ? "-" : "") + groups.join(separator)
            + decimalSuffix + exponentSuffix
    }

    function tooltip(label) {
        const tips = {
            "CLR": qsTr("Clear. Shift click to clear history"),
            "⇧⁻¹": qsTr("Use inverse function"),
            "x²": qsTr("Square"),
            "xʸ": qsTr("Power"),
            "twos": qsTr("Two's complement"),
            "⌈x⌉": qsTr("Round up"),
            "∧": qsTr("Bitwise AND"),
            "∨": qsTr("Bitwise OR"),
            "log₂": qsTr("Base 2 logarithm"),
            "swap": qsTr("Reverse byte order"),
            "⌊x⌋": qsTr("Round down"),
            "¬": qsTr("Bitwise NOT"),
            "⊻": qsTr("Bitwise XOR"),
            "log": qsTr("Base 10 logarithm"),
            "round": qsTr("Round to the nearest whole number"),
            "int": qsTr("Integer part"),
            "|x|": qsTr("Absolute value"),
            "≪": qsTr("Shift bits left"),
            "≫": qsTr("Shift bits right"),
            "ln": qsTr("Natural logarithm"),
            "frac": qsTr("Fractional part"),
            "x!": qsTr("Factorial"),
            "%": qsTr("Percentage"),
            "mod": qsTr("Remainder"),
            "x⁻¹": qsTr("Reciprocal"),
            "()": qsTr("Parentheses"),
            "(": qsTr("Open parenthesis"),
            ")": qsTr("Close parenthesis"),
            "±": qsTr("Change sign"),
            "⌫": qsTr("Backspace")
        }
        if (isHexDigit(label)) return qsTr("Hexadecimal digit %1").arg(label)
        return tips[label] || ""
    }
}
