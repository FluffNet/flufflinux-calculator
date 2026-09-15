import QtQml

QtObject {
    function superscript(number) {
        const normalDigits = String(Math.floor(Number(number)))
        const superscriptDigits = "⁰¹²³⁴⁵⁶⁷⁸⁹"
        let result = ""
        for (let index = 0; index < normalDigits.length; ++index)
            result += superscriptDigits.charAt(Number(normalDigits.charAt(index)))
        return result
    }

    function symbol(degree) {
        const value = Math.max(2, Math.floor(Number(degree)))
        if (value === 2) return "√"
        if (value === 3) return "∛"
        if (value === 4) return "∜"
        return superscript(value) + "√"
    }
}
