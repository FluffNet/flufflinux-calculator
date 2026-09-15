import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import com.flufflinux.calculator

ApplicationWindow {
    id: window
    width: defaultWindowWidth
    height: defaultWindowHeight
    minimumWidth: programmerHistorySidecarActive
        ? minimumWidthForMode("programming") + programmerHistoryPanelWidth
        : mode === "basic" || mode === "programming" ? 340
        : mode === "conversion" ? 380 : 620
    minimumHeight: mode === "programming" ? 676 : 540
    visible: true
    title: mode === "basic" ? qsTr("Calculator")
        : qsTr("Calculator") + "  " + translatedModeName(mode)
    color: palette.window
    property string mode: "basic"
    readonly property int defaultWindowWidth: 370
    readonly property int defaultWindowHeight: 620
    property int normalWindowWidth: defaultWindowWidth
    property int normalWindowHeight: defaultWindowHeight
    property bool windowStateReady: false
    property bool programmerHistorySidecarActive: false
    property bool programmerHistoryTransitioning: false
    property bool programmerHistoryOpenedMaximized: false
    property int programmerHistoryOriginalWidth: 0
    property int programmerHistoryCalculatorWidth: 0
    property int programmerHistoryPanelWidth: 360
    readonly property bool darkTheme: (palette.window.r * 0.2126 + palette.window.g * 0.7152 + palette.window.b * 0.0722) < 0.5
    readonly property string wrapHint: "\u200b"
    property bool inverse: false
    property int programBase: backend.programmerBase
    property int wordBits: backend.programmerWordBits
    property bool programmerBitPanelEnabled: backend.programmerBitPanelEnabled
    readonly property string programmerPreviewData:
        mode === "programming" && backend.expression.trim().length > 0
            ? backend.programmerValues(backend.expression, programBase, wordBits)
            : ""
    readonly property var programmerPreviewParts:
        programmerPreviewData.length > 0 ? programmerPreviewData.split("\t") : []
    property int customRootDegree: 5
    readonly property var advancedKeys: advancedKeySet.leftKeys
    property var financialKeys: ["⇧⁻¹","x²","xʸ","log","ln","Ctrm","Ddb","Fv","Gpm","Pmt","Pv","Rate","Sln","Syd","Term"]
    property var basicKeys: ["C","±","%","7","8","9","4","5","6","1","2","3","0","."]
    readonly property var commonKeys: advancedKeySet.rightKeys
    readonly property var programmerPadKeys: programmerKeySet.padKeys
    property var actionKeys: ["÷","×","−","+"]
    property var conversionUnits: [
        { category: qsTr("Angle"), unit: "", display: "", header: true },
        { category: qsTr("Angle"), unit: "Degrees", display: qsTr("Degrees"), header: false },
        { category: qsTr("Angle"), unit: "Gradians", display: qsTr("Gradians"), header: false },
        { category: qsTr("Angle"), unit: "Radians", display: qsTr("Radians"), header: false },
        { category: qsTr("Area"), unit: "", display: "", header: true },
        { category: qsTr("Area"), unit: "Acres", display: qsTr("Acres"), header: false },
        { category: qsTr("Area"), unit: "Hectares", display: qsTr("Hectares"), header: false },
        { category: qsTr("Area"), unit: "Square feet", display: qsTr("Square feet"), header: false },
        { category: qsTr("Area"), unit: "Square kilometers", display: qsTr("Square kilometers"), header: false },
        { category: qsTr("Area"), unit: "Square meters", display: qsTr("Square meters"), header: false },
        { category: qsTr("Data"), unit: "", display: "", header: true },
        { category: qsTr("Data"), unit: "Bytes", display: qsTr("Bytes"), header: false },
        { category: qsTr("Data"), unit: "Gigabytes", display: qsTr("Gigabytes"), header: false },
        { category: qsTr("Data"), unit: "Kibibytes", display: qsTr("Kibibytes"), header: false },
        { category: qsTr("Data"), unit: "Kilobytes", display: qsTr("Kilobytes"), header: false },
        { category: qsTr("Data"), unit: "Mebibytes", display: qsTr("Mebibytes"), header: false },
        { category: qsTr("Data"), unit: "Megabytes", display: qsTr("Megabytes"), header: false },
        { category: qsTr("Distance"), unit: "", display: "", header: true },
        { category: qsTr("Distance"), unit: "Centimeters", display: qsTr("Centimeters"), header: false },
        { category: qsTr("Distance"), unit: "Feet", display: qsTr("Feet"), header: false },
        { category: qsTr("Distance"), unit: "Inches", display: qsTr("Inches"), header: false },
        { category: qsTr("Distance"), unit: "Kilometers", display: qsTr("Kilometers"), header: false },
        { category: qsTr("Distance"), unit: "Meters", display: qsTr("Meters"), header: false },
        { category: qsTr("Distance"), unit: "Miles", display: qsTr("Miles"), header: false },
        { category: qsTr("Distance"), unit: "Millimeters", display: qsTr("Millimeters"), header: false },
        { category: qsTr("Distance"), unit: "Yards", display: qsTr("Yards"), header: false },
        { category: qsTr("Speed"), unit: "", display: "", header: true },
        { category: qsTr("Speed"), unit: "Kilometers/hour", display: qsTr("Kilometers per hour"), header: false },
        { category: qsTr("Speed"), unit: "Knots", display: qsTr("Knots"), header: false },
        { category: qsTr("Speed"), unit: "Meters/second", display: qsTr("Meters per second"), header: false },
        { category: qsTr("Speed"), unit: "Miles/hour", display: qsTr("Miles per hour"), header: false },
        { category: qsTr("Temperature"), unit: "", display: "", header: true },
        { category: qsTr("Temperature"), unit: "Celsius", display: qsTr("Celsius"), header: false },
        { category: qsTr("Temperature"), unit: "Fahrenheit", display: qsTr("Fahrenheit"), header: false },
        { category: qsTr("Temperature"), unit: "Kelvin", display: qsTr("Kelvin"), header: false },
        { category: qsTr("Time"), unit: "", display: "", header: true },
        { category: qsTr("Time"), unit: "Days", display: qsTr("Days"), header: false },
        { category: qsTr("Time"), unit: "Hours", display: qsTr("Hours"), header: false },
        { category: qsTr("Time"), unit: "Minutes", display: qsTr("Minutes"), header: false },
        { category: qsTr("Time"), unit: "Seconds", display: qsTr("Seconds"), header: false },
        { category: qsTr("Time"), unit: "Weeks", display: qsTr("Weeks"), header: false },
        { category: qsTr("Volume"), unit: "", display: "", header: true },
        { category: qsTr("Volume"), unit: "Cubic meters", display: qsTr("Cubic meters"), header: false },
        { category: qsTr("Volume"), unit: "Cups (US)", display: qsTr("Cups (US)"), header: false },
        { category: qsTr("Volume"), unit: "Gallons (US)", display: qsTr("Gallons (US)"), header: false },
        { category: qsTr("Volume"), unit: "Liters", display: qsTr("Liters"), header: false },
        { category: qsTr("Volume"), unit: "Milliliters", display: qsTr("Milliliters"), header: false },
        { category: qsTr("Weight"), unit: "", display: "", header: true },
        { category: qsTr("Weight"), unit: "Grams", display: qsTr("Grams"), header: false },
        { category: qsTr("Weight"), unit: "Kilograms", display: qsTr("Kilograms"), header: false },
        { category: qsTr("Weight"), unit: "Ounces", display: qsTr("Ounces"), header: false },
        { category: qsTr("Weight"), unit: "Pounds", display: qsTr("Pounds"), header: false },
        { category: qsTr("Weight"), unit: "Tonnes", display: qsTr("Tonnes"), header: false }
    ]

    function translatedModeName(value) {
        const names = {
            "basic": qsTr("Basic"),
            "advanced": qsTr("Advanced"),
            "financial": qsTr("Financial"),
            "programming": qsTr("Programming"),
            "conversion": qsTr("Conversion")
        }
        return names[value] || value
    }

    function translatedErrorText(value) {
        const messages = {
            "Invalid input": qsTr("Invalid input"),
            "Invalid value": qsTr("Invalid value"),
            "Invalid values": qsTr("Invalid values"),
            "Incompatible units": qsTr("Incompatible units"),
            "Expected a number": qsTr("Expected a number"),
            "Expected closing parenthesis": qsTr("Expected closing parenthesis"),
            "Division by zero is undefined": qsTr("Division by zero is undefined"),
            "Modulo by zero is undefined": qsTr("Modulo by zero is undefined"),
            "Square root is undefined for negative values": qsTr("Square root is undefined for negative values"),
            "Result is not a number": qsTr("Result is not a number"),
            "Result is not a real number": qsTr("Result is not a real number"),
            "Overflow: the result is too large": qsTr("Overflow: the result is too large"),
            "Exponent is too large": qsTr("Exponent is too large"),
            "Factorial input is too large": qsTr("Factorial input is too large"),
            "Factorial input is limited to 100,000": qsTr("Factorial input is limited to 100,000"),
            "Factorial is undefined for negative values": qsTr("Factorial is undefined for negative values"),
            "Root degree must be at least 2": qsTr("Root degree must be at least 2"),
            "Root degree is too large": qsTr("Root degree is too large"),
            "Programmer expression is too long": qsTr("Programmer expression is too long"),
            "Programmer result is too large": qsTr("Programmer result is too large"),
            "Invalid base": qsTr("Invalid base"),
            "Bitwise operations require whole numbers": qsTr("Bitwise operations require whole numbers"),
            "Byte swap requires a non-negative whole number": qsTr("Byte swap requires a non negative whole number"),
            "Shift is too large": qsTr("Shift is too large"),
            "Whole number required": qsTr("Whole number required")
        }
        return messages[value] || value
    }

    CalculatorBackend { id: backend }
    ProgrammerKeyRules { id: programmerRules }
    ProgrammerKeySet { id: programmerKeySet }
    ExpressionTypingRouter { id: expressionTypingRouter }
    AccentContrast { id: accentContrast }
    RootNotation { id: rootNotation }
    AdvancedKeySet { id: advancedKeySet }

    Timer {
        id: windowStateSaveTimer
        interval: 400
        onTriggered: backend.saveWindowStateForMode(window.mode,
                                                    window.normalWindowWidth,
                                                    window.normalWindowHeight,
                                                    false)
    }

    function defaultWidthForMode(targetMode) {
        if (targetMode === "basic") return 370
        if (targetMode === "conversion") return 380
        return 620
    }

    function defaultHeightForMode(targetMode) {
        return targetMode === "programming" ? 676 : 620
    }

    function minimumWidthForMode(targetMode) {
        if (targetMode === "basic" || targetMode === "programming") return 340
        if (targetMode === "conversion") return 380
        return 620
    }

    function minimumHeightForMode(targetMode) {
        return targetMode === "programming" ? 676 : 540
    }

    function openProgrammerHistory() {
        if (mode !== "programming" || programmerHistorySidecarActive) return

        windowStateSaveTimer.stop()
        programmerHistoryTransitioning = true
        programmerHistoryOpenedMaximized = visibility === Window.Maximized

        const currentWidth = Math.round(width)
        if (!programmerHistoryOpenedMaximized) {
            normalWindowWidth = currentWidth
            normalWindowHeight = Math.round(height)
            saveCurrentWindowState(false)
        }

        const availableWidth = Screen.desktopAvailableWidth > 0
            ? Screen.desktopAvailableWidth : Screen.width
        const desiredPanelWidth = 360
        const maximumCombinedWidth = availableWidth > 0
            ? availableWidth : currentWidth + desiredPanelWidth
        const combinedWidth = programmerHistoryOpenedMaximized
            ? currentWidth
            : Math.min(currentWidth + desiredPanelWidth, maximumCombinedWidth)
        const minimumCalculatorWidth = minimumWidthForMode("programming")
        const availablePanelWidth = Math.max(0,
            combinedWidth - minimumCalculatorWidth)

        programmerHistoryOriginalWidth = programmerHistoryOpenedMaximized
            ? normalWindowWidth : currentWidth
        programmerHistoryPanelWidth = Math.max(1,
            Math.min(desiredPanelWidth, availablePanelWidth))
        programmerHistoryCalculatorWidth = Math.max(minimumCalculatorWidth,
            combinedWidth - programmerHistoryPanelWidth)
        programmerHistorySidecarActive = true

        if (!programmerHistoryOpenedMaximized)
            width = programmerHistoryCalculatorWidth + programmerHistoryPanelWidth

        Qt.callLater(function() {
            window.programmerHistoryTransitioning = false
            programmerHistoryDrawer.open()
        })
    }

    function finishProgrammerHistoryClose() {
        if (!programmerHistorySidecarActive) return

        programmerHistoryTransitioning = true
        const restoreWidth = programmerHistoryOriginalWidth
        programmerHistorySidecarActive = false
        if (visibility === Window.Windowed && restoreWidth > 0)
            width = restoreWidth
        normalWindowWidth = restoreWidth > 0 ? restoreWidth : normalWindowWidth
        Qt.callLater(function() {
            window.programmerHistoryTransitioning = false
        })
    }

    function closeProgrammerHistory() {
        if (programmerHistoryDrawer.opened) {
            programmerHistoryDrawer.close()
        } else {
            finishProgrammerHistoryClose()
        }
    }

    function toggleProgrammerHistory() {
        if (programmerHistorySidecarActive)
            closeProgrammerHistory()
        else
            openProgrammerHistory()
    }

    function saveCurrentWindowState(maximized) {
        backend.saveWindowStateForMode(mode,
                                       normalWindowWidth,
                                       normalWindowHeight,
                                       maximized)
    }

    function restoreWindowStateForMode(targetMode) {
        if (mode !== targetMode) return
        const availableWidth = Screen.desktopAvailableWidth > 0
            ? Screen.desktopAvailableWidth : Screen.width
        const availableHeight = Screen.desktopAvailableHeight > 0
            ? Screen.desktopAvailableHeight : Screen.height
        const savedWidth = backend.savedWindowWidthForMode(targetMode)
        const savedHeight = backend.savedWindowHeightForMode(targetMode)
        const savedSizeFits = savedWidth >= minimumWidthForMode(targetMode)
            && savedHeight >= minimumHeightForMode(targetMode)
            && (availableWidth <= 0 || savedWidth <= availableWidth)
            && (availableHeight <= 0 || savedHeight <= availableHeight)
        const restoredWidth = savedSizeFits
            ? savedWidth : defaultWidthForMode(targetMode)
        const restoredHeight = savedSizeFits
            ? savedHeight : defaultHeightForMode(targetMode)
        const restoreMaximized = backend.windowMaximizedForMode(targetMode)

        normalWindowWidth = restoredWidth
        normalWindowHeight = restoredHeight

        if (!savedSizeFits) {
            backend.saveWindowStateForMode(targetMode,
                                           restoredWidth,
                                           restoredHeight,
                                           restoreMaximized)
        }

        function finishRestore() {
            if (window.mode === targetMode)
                window.windowStateReady = true
        }

        function applyNormalGeometry() {
            if (window.mode !== targetMode) return
            width = restoredWidth
            height = restoredHeight
        }

        function applyMaximizedState() {
            if (window.mode !== targetMode) return
            applyNormalGeometry()
            window.showMaximized()
            Qt.callLater(finishRestore)
        }

        if (restoreMaximized) {
            if (window.visibility === Window.Maximized) {
                window.showNormal()
                Qt.callLater(applyMaximizedState)
            } else {
                applyMaximizedState()
            }
        } else {
            if (window.visibility === Window.Maximized) {
                window.showNormal()
                Qt.callLater(function() {
                    applyNormalGeometry()
                    Qt.callLater(finishRestore)
                })
            } else {
                applyNormalGeometry()
                Qt.callLater(finishRestore)
            }
        }
    }

    Component.onCompleted: restoreWindowStateForMode(mode)

    onWidthChanged: {
        if (windowStateReady && visibility === Window.Windowed
                && programmerHistorySidecarActive
                && !programmerHistoryTransitioning) {
            programmerHistoryCalculatorWidth = Math.max(
                minimumWidthForMode("programming"),
                Math.round(width) - programmerHistoryPanelWidth)
            programmerHistoryOriginalWidth = programmerHistoryCalculatorWidth
            normalWindowWidth = programmerHistoryCalculatorWidth
            windowStateSaveTimer.restart()
        } else if (windowStateReady && visibility === Window.Windowed
                   && !programmerHistoryTransitioning) {
            normalWindowWidth = Math.round(width)
            windowStateSaveTimer.restart()
        }
    }

    onHeightChanged: {
        if (windowStateReady && visibility === Window.Windowed) {
            normalWindowHeight = Math.round(height)
            windowStateSaveTimer.restart()
        }
    }

    onVisibilityChanged: function() {
        if (!windowStateReady) return
        if (window.visibility === Window.Maximized) {
            windowStateSaveTimer.stop()
            saveCurrentWindowState(true)
        } else if (window.visibility === Window.Windowed) {
            Qt.callLater(function() {
                if (window.visibility === Window.Windowed) {
                    window.normalWindowWidth = Math.round(window.width)
                    window.normalWindowHeight = Math.round(window.height)
                    windowStateSaveTimer.restart()
                }
            })
        }
    }

    onClosing: function(close) {
        windowStateSaveTimer.stop()
        saveCurrentWindowState(window.visibility === Window.Maximized)
    }

    function keyText(label) {
        if (mode === "programming") return programmerRules.inputText(label, inverse, programBase)
        if (inverse) {
            const inverseMap = {"sin":"asin(","cos":"acos(","tan":"atan(","sinh":"asinh(","cosh":"acosh(","tanh":"atanh(","x²":"sqrt("}
            if (inverseMap[label] !== undefined) return inverseMap[label]
        }
        const map = {"÷":"/","×":"*","−":"-","mod":" mod ","x²":"^2","xʸ":"^","√":"√","x⁻¹":"^(-1)","⌈x⌉":"ceil(","⌊x⌋":"floor(","|x|":"abs(","log₂":"log2(","x!":"!"}
        if (map[label] !== undefined) return map[label]
        if (["sin","sinh","asin","asinh","cos","cosh","acos","acosh","tan","tanh","atan","atanh","log","ln","exp","round","int","frac","twos","swap"].indexOf(label) >= 0) return label + "("
        return label
    }

    function isEditorFormattingCharacter(text, index) {
        const character = text.charAt(index)
        return character === wrapHint
            || (character === ","
                && !programmerRules.isArgumentSeparator(text, index))
    }

    function logicalCursorIndex(text, position) {
        let logicalIndex = 0
        for (let index = 0; index < Math.min(position, text.length); ++index) {
            if (!isEditorFormattingCharacter(text, index)) ++logicalIndex
        }
        return logicalIndex
    }

    function editorCursorPosition(text, logicalIndex) {
        if (logicalIndex <= 0) return 0
        let visibleCharacters = 0
        for (let index = 0; index < text.length; ++index) {
            if (!isEditorFormattingCharacter(text, index)) ++visibleCharacters
            if (visibleCharacters === logicalIndex) {
                let position = index + 1
                while (position < text.length
                       && isEditorFormattingCharacter(text, position)) ++position
                return position
            }
        }
        return text.length
    }

    function escapedStyledText(text) {
        return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    function press(label) {
        if (label === "C" || label === "CLR") backend.clear()
        else if (label === "=") {
            calculate()
            return
        } else if (label === "⌫") backend.backspace()
        else if (label === "±") toggleSign()
        else if (label === "()") backend.insert(nextParenthesis())
        else if (label === "⇧⁻¹") inverse = !inverse
        else if (label === "deg") { angleMenu.popup(); return }
        else backend.insert(keyText(label))
        focusEditorAtEnd()
    }

    function nextParenthesis() {
        const text = backend.expression.replace(new RegExp(wrapHint, "g"), "")
        let balance = 0
        for (const character of text) {
            if (character === "(") balance++
            else if (character === ")" && balance > 0) balance--
        }
        return balance > 0 ? ")" : "("
    }

    function focusEditorAtEnd() {
        Qt.callLater(function() {
            editor.forceActiveFocus()
            editor.cursorPosition = editor.text.length
        })
    }

    function auxiliaryTextInputHasFocus() {
        let item = window.activeFocusItem
        while (item) {
            if (item.objectName === "auxiliaryTextInput") return true
            item = item.parent
        }
        return false
    }

    function programmerTypingAllowed(text, modifiers) {
        if (mode !== "programming" || text.length !== 1) return true
        if ((modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0)
            return true
        const textBeforeCursor = editor.text.slice(0, editor.cursorPosition)
        return programmerRules.typingAllowed(text, programBase, textBeforeCursor)
    }

    function routeExpressionTyping(event) {
        if (mode === "conversion") {
            if (modeMenu.opened || mainMenu.opened || about.visible
                    || preferencesDialog.visible || financeDialog.visible) return
            if (conversionLoader.item) conversionLoader.item.routeTyping(event)
            return
        }
        if (editor.activeFocus || auxiliaryTextInputHasFocus()
                || modeMenu.opened || mainMenu.opened || angleMenu.opened
                || rootMenu.opened || about.visible || customRootDialog.visible
                || financeDialog.visible) return

        const action = expressionTypingRouter.actionForEvent(event.key,
                                                             event.modifiers,
                                                             event.text)
        if (action === "selectAll") {
            editor.forceActiveFocus()
            editor.selectAll()
            event.accepted = true
            return
        }
        if (action === "paste") {
            editor.forceActiveFocus()
            editor.paste()
            event.accepted = true
            return
        }
        if (action === "backspace") {
            backend.backspace()
            focusEditorAtEnd()
            event.accepted = true
            return
        }
        if (action === "clear") {
            backend.clear()
            focusEditorAtEnd()
            event.accepted = true
            return
        }
        if (action !== "insert") return
        if (!programmerTypingAllowed(event.text, event.modifiers)) {
            event.accepted = true
            return
        }

        const insertionPoint = editor.cursorPosition
        editor.forceActiveFocus()
        editor.cursorPosition = insertionPoint
        editor.insert(editor.cursorPosition, event.text)
        event.accepted = true
    }

    function calculate() {
        if (mode === "programming") backend.calculateProgrammer(programBase, wordBits)
        else backend.calculate()
        focusEditorAtEnd()
    }

    function switchProgrammerBase(nextBase) {
        if (nextBase === programBase) {
            focusEditorAtEnd()
            return
        }

        const currentExpression = backend.expression.trim()
        if (currentExpression.length > 0) {
            let converted = backend.programmerValue(backend.expression,
                                                     programBase,
                                                     nextBase,
                                                     wordBits)
            if (converted.length === 0 && nextBase === 10)
                converted = programmerPreviewValue(10)
            if (converted.length === 0) return
            backend.applyExpression(converted)
        }
        programBase = nextBase
        backend.saveProgrammerState(programBase,
                                    wordBits,
                                    programmerBitPanelEnabled)
        focusEditorAtEnd()
    }

    function programmerPreviewValue(base) {
        if (programmerPreviewParts.length !== 4) return ""
        if (base === 16) return programmerPreviewParts[0]
        if (base === 10) return programmerPreviewParts[1]
        if (base === 8) return programmerPreviewParts[2]
        if (base === 2) return programmerPreviewParts[3]
        return ""
    }

    function switchProgrammerWordSize(nextBits) {
        if (nextBits === wordBits) {
            focusEditorAtEnd()
            return
        }
        const currentExpression = backend.expression.trim()
        if (currentExpression.length > 0) {
            const resized = backend.programmerResizedValue(backend.expression,
                                                            programBase,
                                                            wordBits,
                                                            nextBits)
            // Partial/invalid input has no complete value to resize. Keep it
            // editable and still honor the newly selected word size.
            if (resized.length > 0) {
                backend.applyExpression(resized)
            }
        }
        wordBits = nextBits
        backend.saveProgrammerState(programBase,
                                    wordBits,
                                    programmerBitPanelEnabled)
        focusEditorAtEnd()
    }

    function setProgrammerBitPanelEnabled(enabled) {
        if (programmerBitPanelEnabled === enabled) return
        programmerBitPanelEnabled = enabled
        backend.saveProgrammerState(programBase,
                                    wordBits,
                                    programmerBitPanelEnabled)
    }

    function applyProgrammerMenuOperation(operation) {
        const binaryFunctions = ["nand(", "nor(", "ashr(", "rol(", "ror("]
        const expression = backend.expression.trim()
        if (binaryFunctions.indexOf(operation) >= 0) {
            const leftOperand = expression.length > 0 ? backend.expression : "0"
            backend.applyExpression(operation + leftOperand + ",")
            focusEditorAtEnd()
            return
        }
        if (operation === "¬" && expression.length > 0) {
            backend.applyExpression("¬(" + backend.expression + ")")
            focusEditorAtEnd()
            return
        }
        press(operation)
    }

    function toggleProgrammerBit(bitIndex) {
        const binaryValue = backend.programmerValue(editor.text, programBase, 2, wordBits)
        const toggled = programmerRules.toggleBit(binaryValue, wordBits, bitIndex)
        const rendered = backend.programmerValue(toggled, 2, programBase, wordBits)
        if (rendered.length > 0) backend.applyExpression(rendered)
    }

    function undoHistory() {
        backend.undo()
        focusEditorAtEnd()
    }

    function redoHistory() {
        backend.redo()
        focusEditorAtEnd()
    }

    function clearAll() {
        backend.clear()
        backend.clearHistory()
        focusEditorAtEnd()
    }

    function insertRoot(text) {
        backend.insert(text)
        focusEditorAtEnd()
    }

    function switchMode(nextMode) {
        if (mode === nextMode) return
        windowStateSaveTimer.stop()
        if (windowStateReady)
            saveCurrentWindowState(visibility === Window.Maximized)
        windowStateReady = false
        backend.clearHistory()
        if (programmerHistorySidecarActive) {
            programmerHistoryDrawer.close()
            finishProgrammerHistoryClose()
        }
        mode = nextMode
        backend.setDigitGroupingActive(mode !== "programming"
                                       && backend.digitGroupingEnabled)
        Qt.callLater(function() {
            window.restoreWindowStateForMode(nextMode)
            window.requestUpdate()
        })
    }

    function toggleSign() {
        const text = backend.expression
        if (text.length === 0) {
            backend.applyExpression("-")
            return
        }
        if (text === "-") {
            backend.applyExpression("")
            return
        }
        if (/[+\-*/%^]$/.test(text)) {
            backend.insert("-")
            return
        }
        if (programmerRules.isArgumentSeparator(text, text.length - 1)) {
            backend.insert("-")
            return
        }
        let numberStart = text.length
        while (numberStart > 0 && /[0-9,.]/.test(text.charAt(numberStart - 1))) numberStart--
        if (numberStart === text.length) {
            backend.applyExpression("-(" + text + ")")
            return
        }
        const prefix = text.slice(0, numberStart)
        const number = text.slice(numberStart)
        if (prefix.charAt(prefix.length - 1) === "-") {
            const beforeMinus = prefix.charAt(prefix.length - 2)
            if (prefix.length === 1 || /[+\-*/%^(]/.test(beforeMinus)) backend.applyExpression(prefix.slice(0, -1) + number)
            else backend.applyExpression(prefix + "-" + number)
        } else {
            backend.applyExpression(prefix + "-" + number)
        }
    }

    component CalcKey: CalculatorKey {
        id: calcKey
        helpText: window.mode === "programming"
            ? programmerRules.tooltip(modelData)
            : modelData === "√"
                ? qsTr("Square root. Right click or hold for more roots")
            : programmerRules.isClearKey(modelData, false)
                ? qsTr("Clear. Shift click to clear history") : ""
        shiftClearEnabled: programmerRules.isClearKey(modelData,
                                                       window.mode === "programming")
        alternateEnabled: modelData === "√"
        onShiftClearRequested: window.clearAll()
        onAlternateRequested: rootMenu.popup(calcKey, 0, calcKey.height)
        triggerHandler: function(label, buttonIndex) {
            window.press(label)
        }
    }

    component EqualKey: Button {
        id: equalKey
        text: "="
        implicitWidth: 56
        implicitHeight: 52
        font.pixelSize: 25
        readonly property color accentColor: equalKey.palette.accent
        readonly property color fillColor:
            accentContrast.fillColor(accentColor)
        background: Rectangle {
            radius: 12
            color: equalKey.down ? Qt.darker(equalKey.fillColor, 1.12)
                                 : equalKey.fillColor
        }
        contentItem: Label {
            text: parent.text
            color: accentContrast.textColor(parent.fillColor,
                                            window.darkTheme)
            font: parent.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        onClicked: window.calculate()
    }

    component UnitComboBox: ComboBox {
        id: unitBox
        readonly property bool rightToLeft: Qt.application.layoutDirection === Qt.RightToLeft
        model: window.conversionUnits
        textRole: "display"
        valueRole: "unit"
        displayText: currentIndex >= 0 && model[currentIndex]
            ? model[currentIndex].display : ""
        readonly property int scrollBarGutter: 18
        contentItem: Label {
            leftPadding: unitBox.rightToLeft ? 32 : 12
            rightPadding: unitBox.rightToLeft ? 12 : 32
            text: unitBox.displayText
            color: unitBox.palette.buttonText
            font: unitBox.font
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 9
            horizontalAlignment: unitBox.rightToLeft
                ? Text.AlignRight : Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }
        indicator: Label {
            x: unitBox.rightToLeft ? 10 : unitBox.width - width - 10
            anchors.verticalCenter: parent.verticalCenter
            text: "▾"
            color: unitBox.palette.buttonText
            font.pixelSize: 12
        }
        background: Rectangle {
            color: unitBox.down
                ? Qt.darker(unitBox.palette.button, 1.08)
                : unitBox.palette.button
            border.width: unitBox.visualFocus ? 2 : 1
            border.color: unitBox.visualFocus
                ? unitBox.palette.highlight : unitBox.palette.mid
            radius: 6
        }
        delegate: ItemDelegate {
            id: unitItem
            required property int index
            required property var modelData
            width: Math.max(0, unitBox.width - unitBox.scrollBarGutter)
            height: modelData.header ? 34 : Math.max(40, unitLabel.implicitHeight + 14)
            enabled: !modelData.header
            opacity: 1
            clip: true
            highlighted: unitBox.highlightedIndex === index
            leftPadding: modelData.header ? 10 : 18
            rightPadding: 10
            contentItem: RowLayout {
                spacing: 8
                Rectangle {
                    visible: unitItem.modelData.header
                    Layout.fillWidth: true
                    Layout.preferredHeight: 2
                    color: unitBox.palette.text
                    opacity: window.darkTheme ? 0.42 : 0.34
                }
                Label {
                    id: unitLabel
                    text: unitItem.modelData.header
                        ? unitItem.modelData.category : unitItem.modelData.display
                    color: unitItem.modelData.header
                        ? (window.darkTheme ? "#ffffff" : "#000000")
                        : unitItem.palette.text
                    font.bold: unitItem.modelData.header
                    horizontalAlignment: unitItem.modelData.header
                        ? Text.AlignHCenter
                        : (unitBox.rightToLeft ? Text.AlignRight : Text.AlignLeft)
                    Layout.fillWidth: true
                    elide: Text.ElideNone
                    wrapMode: Text.WordWrap
                }
                Rectangle {
                    visible: unitItem.modelData.header
                    Layout.fillWidth: true
                    Layout.preferredHeight: 2
                    color: unitBox.palette.text
                    opacity: window.darkTheme ? 0.42 : 0.34
                }
            }
        }
        popup: Popup {
            y: unitBox.height
            width: unitBox.width
            implicitHeight: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, 360)
            padding: 1
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: unitBox.popup.visible ? unitBox.delegateModel : null
                currentIndex: unitBox.highlightedIndex
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOn
                }
            }
            background: Rectangle {
                color: unitBox.palette.window
                border.width: 1
                border.color: unitBox.palette.mid
                radius: 6
            }
        }
    }

    component PreferenceHelp: Label {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        color: palette.text
        opacity: 0.8
        wrapMode: Text.WordWrap
        horizontalAlignment: Qt.application.layoutDirection === Qt.RightToLeft
            ? Text.AlignRight : Text.AlignLeft
        font.pixelSize: 12
    }

    component PreferenceComboBox: ComboBox {
        readonly property bool rightToLeft: Qt.application.layoutDirection === Qt.RightToLeft
        Layout.minimumWidth: 112
        Layout.preferredWidth: 150
        Layout.maximumWidth: Math.min(170, preferencesContent.width * 0.48)

        contentItem: Label {
            leftPadding: parent.rightToLeft ? 30 : 10
            rightPadding: parent.rightToLeft ? 10 : 30
            text: parent.displayText
            color: parent.palette.buttonText
            font: parent.font
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 9
            horizontalAlignment: parent.rightToLeft
                ? Text.AlignRight : Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideNone
        }

        indicator: Label {
            x: parent.rightToLeft ? 10 : parent.width - width - 10
            anchors.verticalCenter: parent.verticalCenter
            text: "▾"
            color: parent.palette.buttonText
            font.pixelSize: 12
        }

        background: Rectangle {
            color: parent.down
                ? Qt.darker(parent.palette.button, 1.08)
                : parent.palette.button
            border.width: parent.visualFocus ? 2 : 1
            border.color: parent.visualFocus
                ? parent.palette.highlight : parent.palette.mid
            radius: 6
        }
    }

    UndoShortcuts {
        id: undoShortcuts
        enabled: window.mode !== "conversion"
        onUndoRequested: { if (enabled) window.undoHistory() }
        onRedoRequested: { if (enabled) window.redoHistory() }
    }
    ClearShortcuts {
        id: clearShortcuts
        enabled: window.mode !== "conversion"
        onClearRequested: {
            if (enabled) {
                backend.clear()
                window.focusEditorAtEnd()
            }
        }
    }
    TypingCursorVisibility {
        id: typingCursorVisibility
        revealDelay: 1000
    }
    Shortcut { sequence: "Shift+C"; enabled: window.mode !== "conversion"; context: Qt.ApplicationShortcut; onActivated: backend.clearHistory() }
    Shortcut { sequence: "="; enabled: window.mode !== "conversion" && !customRootDialog.visible; onActivated: window.calculate() }
    Shortcut { sequence: "Return"; enabled: window.mode !== "conversion" && !customRootDialog.visible && editor.activeFocus; onActivated: window.calculate() }
    Shortcut { sequence: "Enter"; enabled: window.mode !== "conversion" && !customRootDialog.visible && editor.activeFocus; onActivated: window.calculate() }
    Shortcut {
        sequence: "Ctrl+H"
        enabled: window.mode === "programming"
        context: Qt.ApplicationShortcut
        onActivated: window.toggleProgrammerHistory()
    }
    ProgrammerBaseShortcuts {
        shortcutsEnabled: window.mode === "programming"
        onBaseRequested: function(baseValue) {
            window.switchProgrammerBase(baseValue)
        }
    }

    Menu { id: angleMenu
        MenuItem { text: qsTr("Degrees"); onTriggered: backend.applyAngleUnit("degrees") }
        MenuItem { text: qsTr("Radians"); onTriggered: backend.applyAngleUnit("radians") }
        MenuItem { text: qsTr("Gradians"); onTriggered: backend.applyAngleUnit("gradians") }
    }

    Menu {
        id: rootMenu
        MenuItem { text: qsTr("Square root  √"); onTriggered: window.insertRoot("√") }
        MenuItem { text: qsTr("Cube root  ∛"); onTriggered: window.insertRoot("∛") }
        MenuItem { text: qsTr("Fourth root  ∜"); onTriggered: window.insertRoot("∜") }
        MenuSeparator {}
        MenuItem { text: qsTr("Custom root"); onTriggered: customRootDialog.open() }
    }

    header: ToolBar {
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) { window.routeExpressionTyping(event) }
        implicitHeight: 42
        RowLayout { anchors.fill: parent; anchors.leftMargin: 0; anchors.rightMargin: 0; spacing: 0
            ToolButton { text: "☰"; font.pixelSize: 22; Layout.preferredWidth: 32; Layout.fillHeight: true; Accessible.name: qsTr("Select calculator mode"); ToolTip.visible: hovered && !modeMenu.opened; ToolTip.text: qsTr("Calculator modes"); onClicked: modeMenu.opened ? modeMenu.close() : modeMenu.open()
                Menu { id: modeMenu; x: 0; y: parent.height + 2; closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
                    Repeater { model: [
                            { value: "basic", label: qsTr("Basic") },
                            { value: "advanced", label: qsTr("Advanced") },
                            { value: "financial", label: qsTr("Financial") },
                            { value: "programming", label: qsTr("Programming") },
                            { value: "conversion", label: qsTr("Conversion") }
                        ]
                        MenuItem {
                            id: modeItem
                            required property var modelData
                            readonly property bool currentMode: window.mode === modelData.value
                            text: modelData.label
                            font.bold: currentMode
                            leftPadding: 10
                            contentItem: RowLayout {
                                spacing: 8
                                Text {
                                    Layout.minimumWidth: 18
                                    Layout.preferredWidth: 18
                                    text: modeItem.currentMode ? "✓" : ""
                                    color: window.darkTheme ? "#ffffff" : "#000000"
                                    font.pixelSize: 16
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: modeItem.text
                                    color: modeItem.enabled ? modeItem.palette.text : modeItem.palette.mid
                                    font: modeItem.font
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            onTriggered: {
                                window.switchMode(modelData.value)
                            }
                        }
                }
            }
            }
            Item { Layout.fillWidth: true }
            ToolButton { visible: window.mode !== "programming"; text: "↶"; enabled: window.mode !== "conversion" && backend.canUndo; font.pixelSize: 20; Layout.preferredWidth: visible ? 32 : 0; Layout.fillHeight: true; Accessible.name: qsTr("Undo"); ToolTip.visible: hovered; ToolTip.text: qsTr("Undo") + "  \u2066Ctrl+Z\u2069"; onClicked: window.undoHistory() }
            ToolButton { visible: window.mode !== "programming"; text: "↷"; enabled: window.mode !== "conversion" && backend.canRedo; font.pixelSize: 20; Layout.preferredWidth: visible ? 32 : 0; Layout.fillHeight: true; Accessible.name: qsTr("Redo"); ToolTip.visible: hovered; ToolTip.text: qsTr("Redo") + "  \u2066Ctrl+Y\u2069 / \u2066Ctrl+Shift+Z\u2069"; onClicked: window.redoHistory() }
            ToolButton {
                id: historyToolButton
                Layout.preferredWidth: window.mode === "programming" ? 52 : 32
                Layout.fillHeight: true
                icon.name: "view-history"
                icon.width: 20
                icon.height: 20
                icon.color: palette.buttonText
                enabled: window.mode !== "conversion"
                text: programmerHistorySidecarActive ? "←" : "→"
                display: window.mode === "programming"
                    ? AbstractButton.TextBesideIcon : AbstractButton.IconOnly
                Accessible.name: window.mode === "programming"
                    ? (programmerHistorySidecarActive
                        ? qsTr("Close history panel") : qsTr("Open history panel"))
                    : qsTr("Clear history")
                ToolTip.visible: hovered
                ToolTip.text: window.mode === "programming"
                    ? (programmerHistorySidecarActive
                        ? qsTr("Close history") : qsTr("Open history") + "  Ctrl+H")
                    : qsTr("Clear history") + "  Shift+C"
                onClicked: {
                    if (window.mode === "programming") {
                        window.toggleProgrammerHistory()
                    } else {
                        backend.clearHistory()
                    }
                }
            }
            ToolButton { text: "⋮"; font.pixelSize: 22; Layout.preferredWidth: 32; Layout.fillHeight: true; Accessible.name: qsTr("Options"); ToolTip.visible: hovered && !mainMenu.opened; ToolTip.text: qsTr("Options"); onClicked: mainMenu.opened ? mainMenu.close() : mainMenu.open()
                Menu { id: mainMenu; x: parent.width - width; y: parent.height + 2; closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
                    MenuItem {
                        id: preferencesMenuItem
                        text: qsTr("Preferences")
                        contentItem: Label {
                            text: preferencesMenuItem.text
                            color: preferencesMenuItem.enabled
                                ? preferencesMenuItem.palette.text : preferencesMenuItem.palette.mid
                            font: preferencesMenuItem.font
                            horizontalAlignment: Qt.application.layoutDirection === Qt.RightToLeft
                                ? Text.AlignRight : Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                        }
                        onTriggered: preferencesDialog.open()
                    }
                    MenuItem {
                        id: aboutMenuItem
                        text: qsTr("About")
                        contentItem: Label {
                            text: aboutMenuItem.text
                            color: aboutMenuItem.enabled
                                ? aboutMenuItem.palette.text : aboutMenuItem.palette.mid
                            font: aboutMenuItem.font
                            horizontalAlignment: Qt.application.layoutDirection === Qt.RightToLeft
                                ? Text.AlignRight : Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                        }
                        onTriggered: about.open()
                    }
                }
            }
        }
    }

    ProgrammerHistoryDrawer {
        id: programmerHistoryDrawer
        objectName: "programmerHistoryDrawer"
        y: 0
        height: parent ? parent.height : window.height
        sidecarWidth: window.programmerHistoryPanelWidth
        enabled: window.mode === "programming"
        entries: backend.historyData.length > 0
            ? backend.historyData.split("\n") : []
        canUndo: backend.canUndo
        canRedo: backend.canRedo
        onUndoRequested: backend.undo()
        onRedoRequested: backend.redo()
        onClearRequested: backend.clearHistory()
        onClosed: window.finishProgrammerHistoryClose()
        onEntryRequested: function(expression, result, index) {
            backend.applyExpression(result.length > 0 ? result : expression)
        }
    }

    Dialog {
        id: about
        anchors.centerIn: parent
        width: Math.min(window.width - 24, 430)
        title: qsTr("Fluff Linux Calculator")
        standardButtons: Dialog.NoButton

        ColumnLayout {
            width: parent.width
            spacing: 14

            Label {
                Layout.fillWidth: true
                text: qsTr("Calculator For Fluff Linux")
                    + "\n" + qsTr("Version %1").arg("2026.09-2")
                    + "\n\nCopyright © 2026 FluffNet LLC"
                    + "\nGNU General Public License v3.0 or later"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }

        footer: DialogButtonBox {
            alignment: Qt.AlignRight

            Button {
                objectName: "githubPageButton"
                text: qsTr("GitHub Page")
                icon.name: "internet-web-browser"
                Accessible.name: qsTr("Open GitHub Page")
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Open the project on GitHub")
                DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
                onClicked: Qt.openUrlExternally(
                    "https://github.com/FluffNet/flufflinux-calculator")
            }

            Button {
                text: qsTr("OK")
                icon.name: "dialog-ok"
                Accessible.name: qsTr("OK")
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }

            onAccepted: about.accept()
        }
    }

    Dialog {
        id: preferencesDialog
        readonly property bool rightToLeft: Qt.application.layoutDirection === Qt.RightToLeft
        anchors.centerIn: parent
        width: Math.max(1, window.width - 24)
        height: Math.max(1, window.height - 24)
        modal: true
        title: qsTr("Preferences")
        standardButtons: Dialog.Close
        onOpened: {
            if (footer)
                footer.alignment = rightToLeft ? Qt.AlignLeft : Qt.AlignRight
        }

        header: Control {
            implicitHeight: 52
            contentItem: Item {
                Label {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 52
                    anchors.rightMargin: 52
                    anchors.verticalCenter: parent.verticalCenter
                    text: preferencesDialog.title
                    color: preferencesDialog.palette.windowText
                    font.pixelSize: 18
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                ToolButton {
                    x: preferencesDialog.rightToLeft ? 0 : parent.width - width
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: parent.height
                    text: "×"
                    font.pixelSize: 24
                    Accessible.name: preferencesDialog.title
                    onClicked: preferencesDialog.reject()
                }
            }
            background: Rectangle {
                color: preferencesDialog.palette.window
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: preferencesDialog.palette.mid
                    opacity: 0.65
                }
            }
        }

        ColumnLayout {
            id: preferencesContent
            width: parent.width
            spacing: 8

            Label {
                text: qsTr("Display")
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: preferencesDialog.rightToLeft
                    ? Text.AlignRight : Text.AlignLeft
            }
            CheckBox {
                id: groupingCheckBox
                text: qsTr("Digit grouping")
                checked: backend.digitGroupingEnabled
                onClicked: backend.applyDigitGrouping(checked)
                Layout.fillWidth: true
                indicator: Rectangle {
                    implicitWidth: 20
                    implicitHeight: 20
                    x: preferencesDialog.rightToLeft
                        ? groupingCheckBox.width - groupingCheckBox.rightPadding - width
                        : groupingCheckBox.leftPadding
                    y: groupingCheckBox.topPadding
                        + (groupingCheckBox.availableHeight - height) / 2
                    radius: 4
                    color: "transparent"
                    border.width: 1
                    border.color: groupingCheckBox.activeFocus
                        ? groupingCheckBox.palette.highlight : groupingCheckBox.palette.mid
                    Text {
                        anchors.centerIn: parent
                        visible: groupingCheckBox.checked
                        text: "✓"
                        color: window.darkTheme ? "#ffffff" : "#000000"
                        font.bold: true
                        font.pixelSize: 15
                    }
                }
                contentItem: Label {
                    leftPadding: preferencesDialog.rightToLeft ? 0
                        : groupingCheckBox.indicator.width + groupingCheckBox.spacing
                    rightPadding: preferencesDialog.rightToLeft
                        ? groupingCheckBox.indicator.width + groupingCheckBox.spacing : 0
                    text: groupingCheckBox.text
                    color: groupingCheckBox.palette.windowText
                    font: groupingCheckBox.font
                    horizontalAlignment: preferencesDialog.rightToLeft
                        ? Text.AlignRight : Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                }
            }
            PreferenceHelp {
                text: qsTr("Adds separators to large numbers. Example: 1000000 becomes 1,000,000. Not used in Programming.")
            }
            PreferenceHelp {
                text: qsTr("Result format and decimal places apply to Basic, Advanced, and Financial. Conversion chooses a sensible precision automatically.")
            }
            RowLayout {
                Layout.fillWidth: true
                layoutDirection: preferencesDialog.rightToLeft
                    ? Qt.RightToLeft : Qt.LeftToRight
                Label { text: qsTr("Result format"); Layout.fillWidth: true; wrapMode: Text.WordWrap; horizontalAlignment: preferencesDialog.rightToLeft ? Text.AlignRight : Text.AlignLeft }
                PreferenceComboBox {
                    id: resultFormatBox
                    model: [qsTr("Automatic"), qsTr("Fixed"), qsTr("Scientific"), qsTr("Engineering")]
                    currentIndex: ["automatic", "fixed", "scientific", "engineering"].indexOf(backend.format)
                    onActivated: backend.setFormatting(["automatic", "fixed", "scientific", "engineering"][currentIndex], backend.precision)
                }
            }
            PreferenceHelp {
                text: resultFormatBox.currentIndex === 0
                    ? qsTr("Automatic removes extra zeros. Example: 2.500 becomes 2.5.")
                    : resultFormatBox.currentIndex === 1
                    ? qsTr("Fixed always shows the selected decimal places. Example: 2.5 can become 2.500.")
                    : resultFormatBox.currentIndex === 2
                    ? qsTr("Scientific uses powers of ten. Example: 1,000,000 is shown using e6.")
                    : qsTr("Engineering uses powers in steps of three. Example: 12,000 is shown using e3.")
            }
            RowLayout {
                Layout.fillWidth: true
                layoutDirection: preferencesDialog.rightToLeft
                    ? Qt.RightToLeft : Qt.LeftToRight
                Label { text: qsTr("Decimal places"); Layout.fillWidth: true; wrapMode: Text.WordWrap; horizontalAlignment: preferencesDialog.rightToLeft ? Text.AlignRight : Text.AlignLeft }
                SpinBox {
                    Layout.minimumWidth: 100
                    Layout.preferredWidth: 120
                    Layout.maximumWidth: 130
                    from: 1
                    to: 100
                    value: backend.precision
                    editable: true
                    onValueModified: backend.setFormatting(backend.format, value)
                }
            }
            PreferenceHelp {
                text: qsTr("For Basic, Advanced, and Financial, sets digits after the decimal in Fixed, Scientific, and Engineering. With 3 places, 2.5 becomes 2.500.")
            }
            MenuSeparator { Layout.fillWidth: true }
            Label { text: qsTr("Calculation"); font.bold: true; Layout.fillWidth: true; horizontalAlignment: preferencesDialog.rightToLeft ? Text.AlignRight : Text.AlignLeft }
            RowLayout {
                Layout.fillWidth: true
                layoutDirection: preferencesDialog.rightToLeft
                    ? Qt.RightToLeft : Qt.LeftToRight
                Label { text: qsTr("Angle unit"); Layout.fillWidth: true; wrapMode: Text.WordWrap; horizontalAlignment: preferencesDialog.rightToLeft ? Text.AlignRight : Text.AlignLeft }
                PreferenceComboBox {
                    model: [qsTr("Degrees"), qsTr("Radians"), qsTr("Gradians")]
                    currentIndex: ["degrees", "radians", "gradians"].indexOf(backend.angleUnit)
                    onActivated: backend.applyAngleUnit(["degrees", "radians", "gradians"][currentIndex])
                }
            }
            PreferenceHelp {
                text: backend.angleUnit === "degrees"
                    ? qsTr("Uses 360 degrees per full turn. Example: sin(30) = 0.5.")
                    : backend.angleUnit === "radians"
                    ? qsTr("Uses 2π radians per full turn. Example: sin(π / 2) = 1.")
                    : qsTr("Uses 400 gradians per full turn. Example: sin(50) is about 0.707.")
            }
        }
    }

    Dialog {
        id: customRootDialog
        anchors.centerIn: parent
        width: Math.min(window.width - 40, 340)
        modal: true
        title: qsTr("Custom root")
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: {
            window.customRootDegree = rootDegreeBox.value
            window.insertRoot(rootNotation.symbol(rootDegreeBox.value))
        }

        ColumnLayout {
            width: parent.width
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Label { text: qsTr("Root degree"); Layout.fillWidth: true }
                SpinBox {
                    id: rootDegreeBox
                    from: 2
                    to: 999
                    value: window.customRootDegree
                    editable: true
                }
            }
            Label {
                Layout.fillWidth: true
                text: qsTr("Choose 3 for a cube root, 4 for a fourth root, or any higher degree.")
                wrapMode: Text.WordWrap
                color: palette.text
                opacity: 0.8
            }
        }
    }

    Dialog {
        id: financeDialog
        anchors.centerIn: parent
        width: Math.min(window.width - 40, 520)
        modal: true
        title: qsTr("Financial Calculation") + "  " + financeOperation
        property string financeOperation: "Fv"
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: backend.applyExpression(backend.financialValue(financeOperation, finPrincipal.text, finRate.text, finPeriods.text, finPayment.text))
        ColumnLayout { width: parent.width
            Label { text: qsTr("Use only the fields needed by this calculation."); wrapMode: Text.WordWrap; Layout.fillWidth: true }
            TextField { id: finPrincipal; Layout.fillWidth: true; placeholderText: qsTr("Principal / cost / present value") }
            TextField { id: finRate; Layout.fillWidth: true; placeholderText: qsTr("Rate (%)") }
            TextField { id: finPeriods; Layout.fillWidth: true; placeholderText: qsTr("Periods / life") }
            TextField { id: finPayment; Layout.fillWidth: true; placeholderText: qsTr("Payment / salvage / future value") }
        }
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: window.programmerHistorySidecarActive
            ? Math.min(parent.width, window.programmerHistoryCalculatorWidth)
            : parent.width
        spacing: 0
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) { window.routeExpressionTyping(event) }
        Item {
            visible: window.mode !== "conversion"
            Layout.fillWidth: true
            Layout.fillHeight: visible && window.mode !== "programming"
            Layout.preferredHeight: !visible ? 0
                : window.mode === "programming"
                    ? (editorRow.needsSecondLine || backend.error.length > 0
                        ? 269 : 233)
                    : 245
            ColumnLayout { anchors.fill: parent; spacing: 0
                Rectangle {
                    visible: window.mode !== "programming"
                    Layout.fillWidth: true
                    Layout.fillHeight: visible
                    Layout.preferredHeight: visible ? 1 : 0
                    color: palette.base
                    ListView {
                        id: historyView
                        anchors.fill: parent
                        clip: true
                        verticalLayoutDirection: ListView.TopToBottom
                        model: backend.historyData.length ? backend.historyData.split("\n") : []
                        onCountChanged: Qt.callLater(function() {
                            if (historyView.contentHeight > historyView.height) historyView.positionViewAtEnd()
                        })
                        delegate: Rectangle {
                            required property string modelData
                            readonly property string expressionText: modelData.split("\t")[0]
                            readonly property string resultText: modelData.split("\t")[1]
                            width: ListView.view.width
                            height: Math.max(46, historyRow.implicitHeight + 16)
                            color: palette.base

                            TextMetrics { id: historyEquationMetrics; font.pixelSize: 17; text: expressionText + " = " + resultText }

                            Text {
                                id: historyRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                text: window.escapedStyledText(expressionText) + " = <b>" + window.escapedStyledText(resultText) + "</b>"
                                textFormat: Text.StyledText
                                color: palette.text
                                font.pixelSize: Math.max(12, Math.min(17, Math.floor(17 * Math.max(1, width) * 3 / Math.max(1, historyEquationMetrics.advanceWidth))))
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            }
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: palette.mid; opacity: 0.55 }
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: palette.mid; opacity: 0.65 }
                Rectangle {
                    id: editorRow
                    readonly property real availableTextWidth: Math.max(1, width - 82)
                    readonly property int singleLineFontSize: Math.max(10, Math.min(22,
                        Math.floor(22 * availableTextWidth / Math.max(1, expressionMetrics.advanceWidth))))
                    readonly property bool needsSecondLine: expressionMetrics.advanceWidth > availableTextWidth && singleLineFontSize < 16
                    readonly property int fittedFontSize: needsSecondLine
                        ? Math.max(10, Math.min(16, Math.floor(22 * availableTextWidth * 2 / Math.max(1, expressionMetrics.advanceWidth))))
                        : singleLineFontSize
                    Layout.fillWidth: true
                    Layout.preferredHeight: needsSecondLine || backend.error.length > 0 ? 96 : 60
                    color: palette.window

                    TextMetrics {
                        id: expressionMetrics
                        font.pixelSize: 22
                        text: backend.expression.length > 0 ? backend.expression : "0"
                    }

                    TextArea {
                        id: editor
                        property int cursorSyncRevision: 0
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 58
                        anchors.topMargin: 8
                        anchors.bottomMargin: backend.error.length > 0 ? 26 : 8
                        text: backend.expression; color: palette.text; selectionColor: palette.highlight; selectedTextColor: palette.highlightedText
                        font.pixelSize: editorRow.fittedFontSize
                        verticalAlignment: TextEdit.AlignVCenter
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        selectByMouse: true
                        focus: true
                        clip: true
                        padding: 0
                        background: null
                        cursorVisible: activeFocus && typingCursorVisibility.cursorVisible
                        Keys.priority: Keys.BeforeItem
                        onTextChanged: {
                            cursorSyncRevision++
                            if (activeFocus && text !== backend.expression) {
                                typingCursorVisibility.typingActivity()
                                const logicalIndex = window.logicalCursorIndex(text, cursorPosition)
                                backend.applyExpression(text)
                                const revision = ++cursorSyncRevision
                                Qt.callLater(function() {
                                    if (editor.activeFocus && revision === editor.cursorSyncRevision)
                                        editor.cursorPosition = window.editorCursorPosition(editor.text, logicalIndex)
                                })
                            }
                        }
                        Keys.onPressed: function(event) {
                            if (!window.programmerTypingAllowed(event.text,
                                                                event.modifiers)) {
                                event.accepted = true
                            } else if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down,
                                 Qt.Key_Home, Qt.Key_End, Qt.Key_PageUp,
                                 Qt.Key_PageDown].indexOf(event.key) >= 0) {
                                typingCursorVisibility.revealNow()
                            }
                            const shiftOnly = (event.modifiers & Qt.ShiftModifier) !== 0
                                && (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) === 0
                            if (clearShortcuts.handleFocusedEditorKey(event.key,
                                                                      event.modifiers)) {
                                event.accepted = true
                            } else if (undoShortcuts.handleFocusedEditorKey(event.key, event.modifiers)) {
                                event.accepted = true
                            } else if (shiftOnly && event.key === Qt.Key_C) {
                                backend.clearHistory()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                window.calculate()
                                event.accepted = true
                            } else if (selectionStart === selectionEnd && event.key === Qt.Key_Left
                                       && cursorPosition > 0
                                       && window.isEditorFormattingCharacter(text,
                                                                             cursorPosition - 1)) {
                                cursorPosition = Math.max(0, cursorPosition - 2)
                                event.accepted = true
                            } else if (selectionStart === selectionEnd && event.key === Qt.Key_Right
                                       && cursorPosition < text.length
                                       && window.isEditorFormattingCharacter(text,
                                                                             cursorPosition)) {
                                cursorPosition = Math.min(text.length, cursorPosition + 2)
                                event.accepted = true
                            } else if (selectionStart === selectionEnd && event.key === Qt.Key_Right
                                       && cursorPosition + 1 < text.length
                                       && window.isEditorFormattingCharacter(text,
                                                                             cursorPosition + 1)) {
                                cursorPosition = Math.min(text.length, cursorPosition + 2)
                                event.accepted = true
                            } else if (selectionStart === selectionEnd && event.key === Qt.Key_Backspace
                                       && cursorPosition >= 2
                                       && window.isEditorFormattingCharacter(text,
                                                                             cursorPosition - 1)) {
                                remove(cursorPosition - 2, cursorPosition)
                                event.accepted = true
                            } else if (selectionStart === selectionEnd && event.key === Qt.Key_Delete
                                       && cursorPosition < text.length - 1
                                       && window.isEditorFormattingCharacter(text,
                                                                             cursorPosition)) {
                                remove(cursorPosition, cursorPosition + 2)
                                event.accepted = true
                            } else if (selectionStart === selectionEnd && event.key === Qt.Key_Delete
                                       && cursorPosition + 1 < text.length
                                       && window.isEditorFormattingCharacter(text,
                                                                             cursorPosition + 1)) {
                                remove(cursorPosition, cursorPosition + 2)
                                event.accepted = true
                            }
                        }
                    }
                    ToolButton {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 40
                        flat: true
                        icon.name: "edit-clear"
                        icon.width: 22
                        icon.height: 22
                        icon.color: palette.text
                        display: AbstractButton.IconOnly
                        Accessible.name: qsTr("Backspace")
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("Backspace")
                        onClicked: backend.backspace()
                    }
                    Label { visible: backend.error.length > 0; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 5; text: window.translatedErrorText(backend.error); color: "#c01c28"; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideNone; wrapMode: Text.WordWrap }
                }
                ProgrammerBasePreview {
                    id: programmerBasePreview
                    visible: window.mode === "programming"
                    Layout.fillWidth: true
                    Layout.minimumHeight: visible ? 172 : 0
                    Layout.preferredHeight: visible ? 172 : 0
                    currentBase: window.programBase
                    values: window.programmerPreviewParts
                    hasExpression: backend.expression.trim().length > 0
                    onBaseRequested: function(baseValue) {
                        window.switchProgrammerBase(baseValue)
                    }
                }
            }
        }

        StackLayout {
            id: calculatorPadStack
            visible: window.mode !== "conversion"
            Layout.fillWidth: true
            Layout.fillHeight: window.mode === "programming"
            Layout.preferredHeight: window.mode === "programming" ? 335 : 275
            currentIndex: window.mode === "advanced" ? 1
                : window.mode === "financial" ? 2
                : window.mode === "programming" ? 3 : 0

        Loader { id: basicLoader; active: calculatorPadStack.visible && StackLayout.isCurrentItem
            sourceComponent: Component {
        GridLayout { anchors.fill: parent; anchors.margins: 10; columns: 5; rows: 5; uniformCellWidths: true; uniformCellHeights: true; rowSpacing: 6; columnSpacing: 6
            Repeater { model: basicKeys
                CalcKey { Layout.row: index < 12 ? Math.floor(index/3) : 4; Layout.column: index < 12 ? index%3 : index === 12 ? 0 : 2; Layout.columnSpan: index >= 12 ? 2 : 1; Layout.fillWidth: true; Layout.fillHeight: true }
            }
            Repeater { model: actionKeys
                CalcKey { operatorKey: true; Layout.row: index; Layout.column: 3; Layout.fillWidth: true; Layout.fillHeight: true }
            }
            EqualKey { Layout.column: 4; Layout.row: 0; Layout.rowSpan: 5; Layout.fillWidth: true; Layout.fillHeight: true }
        }
            }
        }

        Loader { active: calculatorPadStack.visible && StackLayout.isCurrentItem
            sourceComponent: Component {
        RowLayout { anchors.fill: parent; anchors.margins: 10; spacing: 6
            GridLayout { Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; columns: 5; rows: 5; uniformCellWidths: true; uniformCellHeights: true; rowSpacing: 6; columnSpacing: 6
                Repeater { model: advancedKeys
                    CalcKey { Layout.fillWidth: true; Layout.fillHeight: true; highlighted: modelData === "⇧⁻¹" && window.inverse }
                }
            }
            GridLayout { Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; columns: 5; rows: 5; uniformCellWidths: true; uniformCellHeights: true; rowSpacing: 6; columnSpacing: 6
                Repeater { model: commonKeys
                    CalcKey { Layout.row: index < 16 ? Math.floor(index/4) : 4; Layout.column: index < 16 ? index%4 : index === 16 ? 0 : index-15; Layout.columnSpan: index === 16 ? 2 : 1; Layout.fillWidth: true; Layout.fillHeight: true }
                }
                Repeater { model: actionKeys
                    CalcKey { operatorKey: true; Layout.row: index; Layout.column: 4; Layout.fillWidth: true; Layout.fillHeight: true }
                }
                EqualKey { Layout.column: 4; Layout.row: 4; Layout.fillWidth: true; Layout.fillHeight: true }
            }
        }
            }
        }

        Loader { active: calculatorPadStack.visible && StackLayout.isCurrentItem
            sourceComponent: Component {
        RowLayout { id: financialPad; anchors.fill: parent; anchors.margins: 10; spacing: 6
            GridLayout { Layout.preferredWidth: Math.floor((financialPad.width - financialPad.spacing) * 0.375); Layout.fillHeight: true; columns: 3; rows: 5; uniformCellWidths: true; uniformCellHeights: true; rowSpacing: 6; columnSpacing: 6
                Repeater { model: financialKeys
                    CalcKey {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        triggerHandler: function(label, buttonIndex) {
                            if (["Ctrm", "Ddb", "Fv", "Gpm", "Pmt", "Pv", "Rate",
                                 "Sln", "Syd", "Term"].indexOf(label) >= 0) {
                                financeDialog.financeOperation = label
                                financeDialog.open()
                            } else {
                                window.press(label)
                            }
                        }
                    }
                }
            }
            GridLayout { Layout.fillWidth: true; Layout.fillHeight: true; columns: 5; rows: 5; uniformCellWidths: true; uniformCellHeights: true; rowSpacing: 6; columnSpacing: 6
                Repeater { model: commonKeys
                    CalcKey { Layout.row: index < 16 ? Math.floor(index/4) : 4; Layout.column: index < 16 ? index%4 : index === 16 ? 0 : index-15; Layout.columnSpan: index === 16 ? 2 : 1; Layout.fillWidth: true; Layout.fillHeight: true }
                }
                Repeater { model: actionKeys
                    CalcKey { operatorKey: true; Layout.row: index; Layout.column: 4; Layout.fillWidth: true; Layout.fillHeight: true }
                }
                EqualKey { Layout.column: 4; Layout.row: 4; Layout.fillWidth: true; Layout.fillHeight: true }
            }
        }
            }
        }

        Loader {
            id: programmingLoader
            active: calculatorPadStack.visible && StackLayout.isCurrentItem
            sourceComponent: Component {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        spacing: 6

                        ComboBox {
                            id: programmerWordSizeBox
                            Layout.minimumWidth: 104
                            Layout.preferredWidth: 146
                            Layout.fillHeight: true
                            Accessible.name: qsTr("Programmer word size")
                            model: ["8-bit", "16-bit", "32-bit", "64-bit", "128-bit",
                                    "256-bit", "512-bit", "1024-bit", "2048-bit", "4096-bit"]
                            currentIndex: [8, 16, 32, 64, 128, 256, 512, 1024,
                                           2048, 4096].indexOf(window.wordBits)
                            onActivated: window.switchProgrammerWordSize(
                                [8, 16, 32, 64, 128, 256, 512, 1024,
                                 2048, 4096][currentIndex])
                        }

                        ProgrammerControlRow {
                            id: programmerControls
                            Layout.minimumWidth: 172
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            currentView: window.programmerBitPanelEnabled
                                ? bitPanelView : keypadView
                            onViewRequested: function(view) {
                                window.setProgrammerBitPanelEnabled(view === bitPanelView)
                            }
                            onBitwiseOperationRequested: function(operation) {
                                window.applyProgrammerMenuOperation(operation)
                            }
                            onBitShiftOperationRequested: function(operation) {
                                window.applyProgrammerMenuOperation(operation)
                            }
                        }
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: window.programmerBitPanelEnabled ? 1 : 0

                        GridLayout {
                            columns: 5
                            rows: 6
                            uniformCellWidths: true
                            uniformCellHeights: true
                            rowSpacing: 6
                            columnSpacing: 6

                            Repeater {
                                model: window.programmerPadKeys
                                CalcKey {
                                    Layout.row: programmerKeySet.rowForIndex(index)
                                    Layout.column: programmerKeySet.columnForIndex(index)
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    operatorKey: ["÷", "×", "−", "+"].indexOf(modelData) >= 0
                                    enabled: programmerRules.isKeyEnabled(modelData,
                                                                          window.programBase)
                                    triggerHandler: function(label, buttonIndex) {
                                        if (programmerRules.isHexDigit(label)) {
                                            backend.insert(label)
                                            window.focusEditorAtEnd()
                                        } else {
                                            window.press(label)
                                        }
                                    }
                                }
                            }

                            EqualKey {
                                Layout.row: 4
                                Layout.column: 4
                                Layout.rowSpan: 2
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                            }
                        }

                        ProgrammerBitPanel {
                            wordBits: window.wordBits
                            binaryValue: window.programmerPreviewValue(2)
                            valueAvailable: backend.expression.trim().length === 0
                                || binaryValue.length > 0
                            unavailableText: window.programmerPreviewParts.length === 4
                                ? qsTr("Whole number required") : qsTr("Invalid input")
                            onBitToggled: function(bitIndex) {
                                window.toggleProgrammerBit(bitIndex)
                            }
                        }
                    }
                }
            }
        }

        }

        Loader {
            id: conversionLoader
            active: window.mode === "conversion"
            visible: active
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: Component {
                ColumnLayout {
                    id: conversionPanel
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6
                    property var activeValueField: fromValue
                    property bool showingIncompatibility: false
                    property string lastUsableFromValue: ""
                    property string lastUsableToValue: ""

                    function unitIndex(unit) {
                        for (let index = 0; index < conversionUnits.length; ++index) {
                            if (conversionUnits[index].unit === unit) return index
                        }
                        return 0
                    }

                    function isErrorText(text) {
                        return text === "Invalid value" || text === "Incompatible units"
                    }

                    function displayText(text) {
                        return window.translatedErrorText(text)
                    }

                    function selectedField() {
                        return activeValueField ? activeValueField : fromValue
                    }

                    function updateOther(source) {
                        const target = source === fromValue ? toValue : fromValue
                        const sourceUnit = source === fromValue ? fromUnit.currentValue : toUnit.currentValue
                        const targetUnit = source === fromValue ? toUnit.currentValue : fromUnit.currentValue
                        const compatibility = backend.convertValue("0", sourceUnit, targetUnit)
                        if (compatibility === "Incompatible units") {
                            if (!showingIncompatibility) {
                                lastUsableFromValue = isErrorText(fromValue.text)
                                    ? "" : fromValue.text
                                lastUsableToValue = isErrorText(toValue.text)
                                    ? "" : toValue.text
                            }
                            showingIncompatibility = true
                            fromValue.text = compatibility
                            toValue.text = compatibility
                            return
                        }
                        if (showingIncompatibility) {
                            fromValue.text = lastUsableFromValue
                            toValue.text = lastUsableToValue
                            showingIncompatibility = false
                        }
                        target.text = source.text.length > 0
                            ? backend.convertValue(source.text, sourceUnit, targetUnit) : ""
                        lastUsableFromValue = isErrorText(fromValue.text) ? "" : fromValue.text
                        lastUsableToValue = isErrorText(toValue.text) ? "" : toValue.text
                    }

                    function recalculate() {
                        let source = selectedField()
                        if (isErrorText(source.text)) source = source === fromValue ? toValue : fromValue
                        updateOther(source)
                    }

                    function saveUnits() {
                        backend.saveConversionUnits(fromUnit.currentValue, toUnit.currentValue)
                    }

                    function insertIntoField(text) {
                        const field = selectedField()
                        if (isErrorText(field.text)) field.clear()
                        field.forceActiveFocus()
                        field.insert(field.cursorPosition, text)
                        updateOther(field)
                    }

                    function clearField() {
                        const field = selectedField()
                        const other = field === fromValue ? toValue : fromValue
                        field.clear()
                        other.clear()
                        field.forceActiveFocus()
                    }

                    function backspaceField() {
                        const field = selectedField()
                        if (isErrorText(field.text)) {
                            clearField()
                            return
                        }
                        if (field.selectionStart !== field.selectionEnd)
                            field.remove(field.selectionStart, field.selectionEnd)
                        else if (field.cursorPosition > 0)
                            field.remove(field.cursorPosition - 1, field.cursorPosition)
                        updateOther(field)
                        field.forceActiveFocus()
                    }

                    function toggleSign() {
                        const field = selectedField()
                        if (isErrorText(field.text)) field.clear()
                        if (field.text.charAt(0) === "-") field.remove(0, 1)
                        else field.insert(0, "-")
                        field.cursorPosition = field.text.length
                        updateOther(field)
                        field.forceActiveFocus()
                    }

                    function swapValues() {
                        const oldFromIndex = fromUnit.currentIndex
                        const oldFromText = fromValue.text
                        fromUnit.currentIndex = toUnit.currentIndex
                        toUnit.currentIndex = oldFromIndex
                        fromValue.text = toValue.text
                        toValue.text = oldFromText
                        const oldUsableFromValue = lastUsableFromValue
                        lastUsableFromValue = lastUsableToValue
                        lastUsableToValue = oldUsableFromValue
                        saveUnits()
                        selectedField().forceActiveFocus()
                    }

                    function pressKey(label) {
                        if (label === "C") clearField()
                        else if (label === "⇅") swapValues()
                        else if (label === "⌫") backspaceField()
                        else if (label === "+/−") toggleSign()
                        else insertIntoField(label)
                    }

                    function routeTyping(event) {
                        const field = selectedField()
                        const controlPressed = (event.modifiers & Qt.ControlModifier) !== 0
                        if (controlPressed && event.key === Qt.Key_A) {
                            field.forceActiveFocus()
                            field.selectAll()
                            event.accepted = true
                            return
                        }
                        if (controlPressed && event.key === Qt.Key_V) {
                            field.forceActiveFocus()
                            field.paste()
                            Qt.callLater(function() { conversionPanel.updateOther(field) })
                            event.accepted = true
                            return
                        }
                        if ((event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0)
                            return
                        if (!event.text || !/[0-9.,+-]/.test(event.text)) return
                        insertIntoField(event.text)
                        event.accepted = true
                    }

                    Component.onCompleted: Qt.callLater(function() {
                        fromValue.forceActiveFocus()
                        conversionPanel.updateOther(fromValue)
                    })

                    Frame {
                        Layout.fillWidth: true
                        padding: 8
                        ColumnLayout {
                            width: parent.width
                            spacing: 4
                            Label {
                                text: qsTr("From")
                                font.bold: true
                                Layout.fillWidth: true
                                horizontalAlignment: Qt.application.layoutDirection === Qt.RightToLeft
                                    ? Text.AlignRight : Text.AlignLeft
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.preferredHeight: fromValue.implicitHeight
                                    TextField {
                                        id: fromValue
                                        objectName: "auxiliaryTextInput"
                                        anchors.fill: parent
                                        visible: !conversionPanel.isErrorText(text)
                                        placeholderText: qsTr("Value")
                                        font.pixelSize: 18
                                        horizontalAlignment: Qt.application.layoutDirection === Qt.RightToLeft
                                            ? TextInput.AlignRight : TextInput.AlignLeft
                                        selectByMouse: true
                                        onActiveFocusChanged: {
                                            if (activeFocus) conversionPanel.activeValueField = fromValue
                                        }
                                        onTextEdited: conversionPanel.updateOther(fromValue)
                                    }
                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        visible: conversionPanel.isErrorText(fromValue.text)
                                        text: conversionPanel.displayText(fromValue.text)
                                        color: window.palette.text
                                        font.pixelSize: 18
                                        fontSizeMode: Text.HorizontalFit
                                        minimumPixelSize: 12
                                        horizontalAlignment: Qt.application.layoutDirection === Qt.RightToLeft
                                            ? Text.AlignRight : Text.AlignLeft
                                        verticalAlignment: Text.AlignVCenter
                                        wrapMode: Text.NoWrap
                                    }
                                }
                                UnitComboBox {
                                    id: fromUnit
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    currentIndex: conversionPanel.unitIndex(backend.conversionFromUnit)
                                    onActivated: {
                                        conversionPanel.saveUnits()
                                        conversionPanel.recalculate()
                                    }
                                }
                            }
                        }
                    }

                    ToolButton {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 34
                        text: "⇅"
                        font.pixelSize: 20
                        Accessible.name: qsTr("Swap values and units")
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("Swap values and units")
                        onClicked: conversionPanel.swapValues()
                    }

                    Frame {
                        Layout.fillWidth: true
                        padding: 8
                        ColumnLayout {
                            width: parent.width
                            spacing: 4
                            Label {
                                text: qsTr("To")
                                font.bold: true
                                Layout.fillWidth: true
                                horizontalAlignment: Qt.application.layoutDirection === Qt.RightToLeft
                                    ? Text.AlignRight : Text.AlignLeft
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.preferredHeight: toValue.implicitHeight
                                    TextField {
                                        id: toValue
                                        objectName: "auxiliaryTextInput"
                                        anchors.fill: parent
                                        visible: !conversionPanel.isErrorText(text)
                                        placeholderText: qsTr("Value")
                                        font.pixelSize: 18
                                        horizontalAlignment: Qt.application.layoutDirection === Qt.RightToLeft
                                            ? TextInput.AlignRight : TextInput.AlignLeft
                                        selectByMouse: true
                                        onActiveFocusChanged: {
                                            if (activeFocus) conversionPanel.activeValueField = toValue
                                        }
                                        onTextEdited: conversionPanel.updateOther(toValue)
                                    }
                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        visible: conversionPanel.isErrorText(toValue.text)
                                        text: conversionPanel.displayText(toValue.text)
                                        color: window.palette.text
                                        font.pixelSize: 18
                                        fontSizeMode: Text.HorizontalFit
                                        minimumPixelSize: 12
                                        horizontalAlignment: Qt.application.layoutDirection === Qt.RightToLeft
                                            ? Text.AlignRight : Text.AlignLeft
                                        verticalAlignment: Text.AlignVCenter
                                        wrapMode: Text.NoWrap
                                    }
                                }
                                UnitComboBox {
                                    id: toUnit
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    currentIndex: conversionPanel.unitIndex(backend.conversionToUnit)
                                    onActivated: {
                                        conversionPanel.saveUnits()
                                        conversionPanel.recalculate()
                                    }
                                }
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 3
                        rows: 5
                        uniformCellWidths: true
                        uniformCellHeights: true
                        rowSpacing: 6
                        columnSpacing: 6
                        Repeater {
                            model: ["C","⇅","⌫","7","8","9","4","5","6","1","2","3","0",".","+/−"]
                            CalcKey {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                triggerHandler: function(label, buttonIndex) {
                                    conversionPanel.pressKey(label)
                                }
                            }
                        }
                    }
                }
            }
        }

    }
}
