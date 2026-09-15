import QtQml

QtObject {
    readonly property var padKeys: [
        "A", "≪", "≫", "CLR", "÷",
        "B", "(", ")", "%", "×",
        "C", "7", "8", "9", "−",
        "D", "4", "5", "6", "+",
        "E", "1", "2", "3",
        "F", "±", "0", "."
    ]

    function rowForIndex(index) {
        if (index < 20) return Math.floor(index / 5)
        return index < 24 ? 4 : 5
    }

    function columnForIndex(index) {
        if (index < 20) return index % 5
        return index < 24 ? index - 20 : index - 24
    }

    function duplicates() {
        const seen = {}
        const repeated = []
        for (const label of padKeys) {
            if (seen[label] && repeated.indexOf(label) === -1)
                repeated.push(label)
            seen[label] = true
        }
        return repeated
    }
}
