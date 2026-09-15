import QtQml

QtObject {
    readonly property var leftKeys: [
        "⇧⁻¹", "xʸ", "log", "ln", "exp",
        "sin", "sinh", "asin", "asinh", "⌈x⌉",
        "cos", "cosh", "acos", "acosh", "|x|",
        "tan", "tanh", "atan", "atanh", "x!",
        "deg", "π", "e", "⌊x⌋", "round"
    ]
    readonly property var rightKeys: [
        "C", "±", "x²", "%",
        "7", "8", "9", "mod",
        "4", "5", "6", "()",
        "1", "2", "3", "√",
        "0", ".", "x⁻¹"
    ]

    function duplicates() {
        const seen = {}
        const repeated = []
        for (const label of leftKeys.concat(rightKeys)) {
            if (seen[label] && repeated.indexOf(label) === -1)
                repeated.push(label)
            seen[label] = true
        }
        return repeated
    }
}
