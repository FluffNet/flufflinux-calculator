import QtQuick

QtObject {
    function actionForEvent(key, modifiers, text) {
        const controlPressed = (modifiers & Qt.ControlModifier) !== 0
        const unsupportedModifier = (modifiers & (Qt.AltModifier
                                                   | Qt.MetaModifier)) !== 0

        if (controlPressed && !unsupportedModifier && key === Qt.Key_A)
            return "selectAll"
        if (controlPressed && !unsupportedModifier && key === Qt.Key_V)
            return "paste"
        if (controlPressed || unsupportedModifier)
            return "ignore"
        if (key === Qt.Key_Escape)
            return "clear"
        if (key === Qt.Key_Backspace)
            return "backspace"
        if (!text || text.trim().length === 0
                || /[\u0000-\u001f\u007f]/.test(text))
            return "ignore"
        return "insert"
    }
}
