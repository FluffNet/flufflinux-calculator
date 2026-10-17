import QtQuick
import QtQuick.Controls
import QtTest
import "../../qml" as Calculator

TestCase {
    id: testCase
    name: "PreferencesWindow"
    when: host.visible
    property int clearCount: 0

    QtObject {
        id: backend
        property string format: "fixed"
        property int precision: 3
        property string angleUnit: "radians"
        property bool digitGroupingEnabled: false
        property bool groupingActive: false
        readonly property bool preferencesModified: format !== "automatic" || precision !== 9
            || angleUnit !== "degrees" || !digitGroupingEnabled
        property int resetCount: 0
        function setFormatting(value, places) { format = value; precision = places }
        function applyAngleUnit(value) { angleUnit = value }
        function applyDigitGrouping(value) { digitGroupingEnabled = value; groupingActive = value }
        function setDigitGroupingActive(value) { groupingActive = value }
        function resetPreferences(programming) {
            format = "automatic"
            precision = 9
            angleUnit = "degrees"
            digitGroupingEnabled = true
            groupingActive = !programming
            resetCount++
        }
    }

    ApplicationWindow {
        id: host
        width: 340
        height: 540
        visible: true
        TextArea { id: expression; text: "123+3" }
        Calculator.ClearShortcuts {
            enabled: !preferences.visible
            onClearRequested: { testCase.clearCount++; expression.clear() }
        }
    }

    Calculator.PreferencesWindow {
        id: preferences
        calculatorBackend: backend
        transientParent: host
    }

    function control(name) { return findChild(preferences.contentItem, name) || findChild(preferences.footer, name) }
    function click(name) {
        const button = control(name)
        verify(button !== null, name)
        mouseClick(button, button.width / 2, button.height / 2)
    }
    function init() {
        preferences.close()
        preferences.rightToLeft = false
        preferences.programmerMode = false
        preferences.width = 640
        preferences.height = 760
        backend.format = "fixed"
        backend.precision = 3
        backend.angleUnit = "radians"
        backend.digitGroupingEnabled = false
        backend.groupingActive = false
        backend.resetCount = 0
        clearCount = 0
        expression.text = "123+3"
        preferences.open()
        tryVerify(function() { return preferences.visible && preferences.active })
    }
    function cleanup() { preferences.close(); host.requestActivate() }

    function test_separate_modal_window_has_minimum_size() {
        compare(preferences.transientParent, host)
        compare(preferences.modality, Qt.WindowModal)
        verify(preferences.width > host.width)
        verify(preferences.minimumWidth >= 480)
        verify(preferences.minimumHeight >= 540)
        verify((preferences.flags & Qt.WindowMaximizeButtonHint) !== 0)
    }

    function test_reset_updates_all_settings_without_clearing_expression() {
        click("resetSettingsButton")
        compare(backend.resetCount, 1)
        compare(control("resultFormatBox").currentIndex, 0)
        compare(control("precisionBox").value, 9)
        compare(control("angleUnitBox").currentIndex, 0)
        verify(control("groupingCheckBox").checked)
        verify(backend.groupingActive)
        compare(expression.text, "123+3")
        compare(clearCount, 0)
        verify(preferences.visible)
        verify(!control("resetSettingsButton").enabled)
    }

    function test_reset_is_disabled_at_defaults_and_tracks_each_setting() {
        backend.resetPreferences(false)
        const reset = control("resetSettingsButton")
        verify(!reset.enabled)
        const unchangedCount = backend.resetCount
        click("resetSettingsButton")
        compare(backend.resetCount, unchangedCount)
        for (const change of [
            function() { backend.setFormatting("fixed", 9) },
            function() { backend.setFormatting("automatic", 12) },
            function() { backend.applyAngleUnit("radians") },
            function() { backend.applyDigitGrouping(false) }
        ]) {
            change()
            verify(reset.enabled)
            click("resetSettingsButton")
            verify(!reset.enabled)
        }
        backend.applyAngleUnit("radians")
        verify(reset.enabled)
        backend.applyAngleUnit("degrees")
        verify(!reset.enabled)
    }

    function test_programming_reset_preserves_ungrouped_display() {
        preferences.programmerMode = true
        click("resetSettingsButton")
        verify(backend.digitGroupingEnabled)
        verify(!backend.groupingActive)
    }

    function test_reset_refreshes_an_edited_decimal_field() {
        const spin = control("precisionBox")
        preferences.requestActivate()
        spin.contentItem.forceActiveFocus()
        tryVerify(function() { return spin.contentItem.activeFocus })
        spin.contentItem.selectAll()
        keyClick(Qt.Key_1)
        keyClick(Qt.Key_2)
        keyClick(Qt.Key_Tab)
        compare(spin.value, 12)
        compare(backend.precision, 12)
        click("resetSettingsButton")
        compare(backend.precision, 9)
        compare(spin.value, 9)
        compare(spin.contentItem.text, spin.textFromValue(9, spin.locale))
    }

    function test_wheel_scrolls_settings_and_stops_at_bounds() {
        preferences.width = preferences.minimumWidth
        preferences.height = preferences.minimumHeight
        const scroll = control("settingsScroll")
        const view = scroll.contentItem
        tryVerify(function() { return view.contentHeight > scroll.availableHeight })
        view.contentY = 0
        mouseWheel(scroll, 10, scroll.height / 2, 0, -120)
        tryVerify(function() { return view.contentY > 0 })
        for (let i = 0; i < 5; ++i) mouseWheel(scroll, 10, scroll.height / 2, 0, 1200)
        tryCompare(view, "contentY", 0)
        compare(view.contentX, 0)
    }

    function test_touch_drag_keeps_native_flicking() {
        preferences.width = preferences.minimumWidth
        preferences.height = preferences.minimumHeight
        const scroll = control("settingsScroll")
        const view = scroll.contentItem
        tryVerify(function() { return view.contentHeight > scroll.availableHeight })
        view.contentY = 0
        const sequence = touchEvent(scroll)
        sequence.press(0, scroll, 10, scroll.height - 10).commit()
        wait(20)
        for (let y = scroll.height - 20; y > 10; y -= 20) {
            sequence.move(0, scroll, 10, y).commit()
            wait(20)
        }
        sequence.release(0, scroll, 10, 10).commit()
        tryVerify(function() { return view.contentY > 0 })
        verify(view.interactive)
        view.cancelFlick()
        view.returnToBounds()
    }

    function test_expanded_window_scales_controls_and_text() {
        const originalHeight = control("precisionBox").height
        const originalFontSize = control("formatLabel").font.pixelSize
        preferences.width = 1280
        preferences.height = 1000
        tryVerify(function() { return control("precisionBox").height > originalHeight })
        verify(control("formatLabel").font.pixelSize > originalFontSize)
        verify(preferences.uiScale <= 1.6)
        for (const name of ["groupingCheckBox", "resultFormatBox", "angleUnitBox", "resetSettingsButton", "closeSettingsButton"]) {
            const item = control(name)
            compare(item.contentItem.font.pixelSize, Math.round(16 * preferences.uiScale))
        }
        compare(host.width, 340)
        compare(host.height, 540)
    }

    function test_long_checkbox_label_wraps_and_grows() {
        preferences.width = preferences.minimumWidth
        preferences.height = preferences.minimumHeight
        const grouping = control("groupingCheckBox")
        grouping.text = "ZusammengehörigeZiffernFürDieErgebnisdarstellungAutomatischGruppieren"
        tryVerify(function() { return grouping.contentItem.lineCount > 1 })
        tryVerify(function() { return grouping.contentItem.contentHeight <= grouping.contentItem.height + 1 })
        verify(!grouping.contentItem.truncated)
        verify(grouping.contentItem.contentWidth <= grouping.contentItem.width + 1)
        grouping.text = Qt.binding(function() { return qsTranslate("Main", "Digit grouping") })
    }

    function test_dropdown_popup_changes_the_selected_format() {
        const combo = control("resultFormatBox")
        mouseClick(combo, combo.width / 2, combo.height / 2)
        tryVerify(function() { return combo.popup.visible })
        const choice = typeof combo.popup.itemAt === "function"
            ? combo.popup.itemAt(2) : combo.popup.contentItem.itemAtIndex(2)
        verify(choice !== null)
        compare(choice.text, "Scientific")
        verify(waitForRendering(choice))
        compare(choice.contentItem.font.pixelSize, combo.font.pixelSize)
        mouseClick(choice, choice.width / 2, choice.height / 2)
        tryCompare(backend, "format", "scientific")
        tryCompare(combo.popup, "visible", false)
    }

    function test_long_button_and_dropdown_labels_wrap_without_clipping() {
        preferences.width = preferences.minimumWidth
        preferences.height = preferences.minimumHeight
        const reset = control("resetSettingsButton")
        reset.text = "Standardeinstellungen wiederherstellen und alle geänderten Einstellungen zurücksetzen"
        const close = control("closeSettingsButton")
        close.text = "Dieses Einstellungsfenster vollständig schließen"
        const combo = control("resultFormatBox")
        combo.model = ["WissenschaftlicheErgebnisdarstellungMitNachkommastellen"]
        combo.currentIndex = 0
        tryVerify(function() { return reset.contentItem.lineCount > 1 && combo.contentItem.lineCount > 1 })
        for (const item of [reset, close, combo]) {
            verify(!item.contentItem.truncated)
            verify(item.contentItem.contentWidth <= item.contentItem.width + 1)
            tryVerify(function() { return item.contentItem.contentHeight <= item.contentItem.height + 1 }, 1000, item.objectName + ": " + item.contentItem.contentHeight + " > " + item.contentItem.height)
        }
        verify(reset.x + reset.width <= close.x)
        verify(close.x + close.width <= preferences.footer.width + 1,
            "close bounds: " + close.x + ", " + close.width + ", " + preferences.footer.width)
        verify(reset.x >= -1)
        // Restore text and model bindings for subsequent tests.
        reset.text = Qt.binding(function() { return qsTranslate("Main", "Reset settings") })
        close.text = Qt.binding(function() { return qsTranslate("Main", "Close") })
        combo.model = Qt.binding(function() {
            return [qsTranslate("Main", "Automatic"), qsTranslate("Main", "Fixed"), qsTranslate("Main", "Scientific"), qsTranslate("Main", "Engineering")]
        })
        combo.currentIndex = Qt.binding(function() { return ["automatic", "fixed", "scientific", "engineering"].indexOf(backend.format) })
    }

    function test_rtl_mirrors_setting_rows_and_footer() {
        const label = control("formatLabel")
        const combo = control("resultFormatBox")
        tryVerify(function() { return label.x < combo.x })
        preferences.rightToLeft = true
        tryVerify(function() { return label.x > combo.x })
        verify(combo.mirrored)
        compare(combo.contentItem.effectiveHorizontalAlignment, Text.AlignRight)
        verify(control("groupingCheckBox").mirrored)
        compare(label.horizontalAlignment, Text.AlignRight)
        verify(control("resetSettingsButton").x > control("closeSettingsButton").x)
    }

    function test_minimum_size_scrolls_and_keeps_footer_accessible() {
        preferences.width = preferences.minimumWidth
        preferences.height = preferences.minimumHeight
        const scroll = control("settingsScroll")
        tryVerify(function() { return scroll.contentItem.contentHeight > scroll.availableHeight })
        scroll.contentItem.contentY = scroll.contentItem.contentHeight - scroll.availableHeight
        verify(control("resetSettingsButton").visible)
        verify(control("closeSettingsButton").visible)
        click("resetSettingsButton")
        compare(backend.resetCount, 1)
    }

    function test_escape_closes_preferences_and_preserves_expression() {
        control("precisionBox").forceActiveFocus()
        keyClick(Qt.Key_Escape)
        tryCompare(preferences, "visible", false)
        compare(expression.text, "123+3")
        compare(clearCount, 0)
        verify(host.visible)
        preferences.open()
        tryVerify(function() { return preferences.visible })
    }
}
