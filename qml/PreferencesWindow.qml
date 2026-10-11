import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.kde.desktop as Desktop

ApplicationWindow {
    id: root
    required property var calculatorBackend
    property bool programmerMode: false
    property bool rightToLeft: Qt.application.layoutDirection === Qt.RightToLeft
    readonly property real uiScale: Math.min(1.6, Math.max(1, Math.min(width / 640, height / 680)))
    property bool positioned: false
    signal dismissed()

    title: qsTranslate("Main", "Preferences")
    visible: false
    modality: Qt.WindowModal
    flags: Qt.Dialog | Qt.WindowTitleHint | Qt.WindowSystemMenuHint
        | Qt.WindowCloseButtonHint | Qt.WindowMaximizeButtonHint
    minimumWidth: Math.min(480, Math.max(1, Screen.desktopAvailableWidth - 32))
    minimumHeight: Math.min(540, Math.max(1, Screen.desktopAvailableHeight - 64))
    width: Math.min(640, Math.max(minimumWidth, Screen.desktopAvailableWidth - 32))
    height: Math.min(760, Math.max(minimumHeight, Screen.desktopAvailableHeight - 64))
    font.pixelSize: Math.round(16 * uiScale)

    function open() {
        if (!positioned && transientParent) {
            x = Math.max(Screen.virtualX + 16, Math.min(
                transientParent.x + (transientParent.width - width) / 2,
                Screen.virtualX + Screen.desktopAvailableWidth - width - 16))
            y = Math.max(Screen.virtualY + 32, Math.min(
                transientParent.y + (transientParent.height - height) / 2,
                Screen.virtualY + Screen.desktopAvailableHeight - height - 32))
            positioned = true
        }
        show()
        raise()
        requestActivate()
    }

    onClosing: Qt.callLater(function() { root.dismissed() })

    Shortcut {
        sequence: "Esc"
        enabled: root.visible
        context: Qt.WindowShortcut
        onActivated: root.close()
    }

    component HelpText: Label {
        Layout.fillWidth: true
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        horizontalAlignment: root.rightToLeft ? Text.AlignRight : Text.AlignLeft
        color: palette.text
        opacity: 0.8
        font.pixelSize: Math.round(14 * root.uiScale)
    }

    component SettingLabel: Label {
        Layout.fillWidth: true
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        horizontalAlignment: root.rightToLeft ? Text.AlignRight : Text.AlignLeft
    }

    component SettingControlBackground: Rectangle {
        required property var control
        color: control.down ? Qt.darker(control.palette.button, 1.08)
            : control.hovered ? Qt.lighter(control.palette.button, 1.04) : control.palette.button
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? control.palette.highlight : control.palette.mid
        radius: 6
    }

    component SettingButton: Button {
        id: button
        implicitHeight: Math.max(42 * root.uiScale, implicitContentHeight + topPadding + bottomPadding)
        padding: 10 * root.uiScale
        leftPadding: 14 * root.uiScale
        rightPadding: 14 * root.uiScale
        font.pixelSize: Math.round(16 * root.uiScale)
        contentItem: Label {
            text: button.text
            font: button.font
            color: button.palette.buttonText
            opacity: button.enabled ? 1 : 0.4
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }
        background: SettingControlBackground { control: button; opacity: button.enabled ? 1 : 0.6 }
    }

    component SettingComboBox: ComboBox {
        id: combo
        Layout.preferredWidth: 200 * root.uiScale
        Layout.maximumWidth: settingsContent.width * 0.52
        Layout.minimumWidth: 150
        implicitHeight: Math.max(42 * root.uiScale, implicitContentHeight + topPadding + bottomPadding)
        padding: 10 * root.uiScale
        leftPadding: root.rightToLeft ? 34 * root.uiScale : 10 * root.uiScale
        rightPadding: root.rightToLeft ? 10 * root.uiScale : 34 * root.uiScale
        font.pixelSize: Math.round(16 * root.uiScale)
        LayoutMirroring.enabled: root.rightToLeft
        LayoutMirroring.childrenInherit: true
        contentItem: Label {
            text: combo.displayText
            LayoutMirroring.enabled: false
            font: combo.font
            color: combo.palette.buttonText
            horizontalAlignment: root.rightToLeft ? Text.AlignRight : Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }
        indicator: Label {
            text: "▾"
            font: combo.font
            color: combo.palette.buttonText
            x: root.rightToLeft ? 10 * root.uiScale : combo.width - width - 10 * root.uiScale
            anchors.verticalCenter: parent.verticalCenter
        }
        background: SettingControlBackground { control: combo }
        delegate: MenuItem {
            id: choice
            required property int index
            required property string modelData
            text: modelData
            font: combo.font
            highlighted: combo.highlightedIndex === index
            implicitWidth: choiceMetrics.advanceWidth + 28 * root.uiScale
            implicitHeight: Math.max(42 * root.uiScale, implicitContentHeight + topPadding + bottomPadding)
            padding: 10 * root.uiScale
            contentItem: Label {
                text: choice.text
                LayoutMirroring.enabled: false
                font: choice.font
                color: choice.palette.text
                horizontalAlignment: root.rightToLeft ? Text.AlignRight : Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
            background: Rectangle {
                color: choice.highlighted ? choice.palette.highlight : choice.palette.window
                radius: 4
            }
            TextMetrics { id: choiceMetrics; text: choice.text; font: choice.font }
        }
    }

    Desktop.ScrollView {
        id: settingsScroll
        objectName: "settingsScroll"
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        background: null
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        // Desktop.ScrollView supplies Kirigami wheel handling and native touch scrolling.

        Item {
            width: settingsScroll.availableWidth
            implicitHeight: settingsContent.implicitHeight + 48 * root.uiScale

            ColumnLayout {
                id: settingsContent
                anchors.horizontalCenter: parent.horizontalCenter
                y: 24 * root.uiScale
                width: Math.max(1, Math.min(parent.width - 48 * root.uiScale, 780 * root.uiScale))
                spacing: 20 * root.uiScale

                SettingLabel {
                    text: qsTranslate("Main", "Display")
                    font.bold: true
                    font.pixelSize: Math.round(20 * root.uiScale)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8 * root.uiScale
                    CheckBox {
                        id: groupingCheckBox
                        objectName: "groupingCheckBox"
                        Layout.fillWidth: true
                        implicitHeight: 40 * root.uiScale
                        font.pixelSize: Math.round(16 * root.uiScale)
                        text: qsTranslate("Main", "Digit grouping")
                        checked: root.calculatorBackend.digitGroupingEnabled
                        LayoutMirroring.enabled: root.rightToLeft
                        LayoutMirroring.childrenInherit: true
                        onClicked: {
                            root.calculatorBackend.applyDigitGrouping(checked)
                            if (root.programmerMode)
                                root.calculatorBackend.setDigitGroupingActive(false)
                        }
                    }
                    HelpText {
                        text: qsTranslate("Main", "Adds separators to large numbers. Example: 1000000 becomes 1,000,000. Not used in Programming.")
                    }
                }

                HelpText {
                    text: qsTranslate("Main", "Result format and decimal places apply to Basic, Advanced, and Financial. Conversion chooses a sensible precision automatically.")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8 * root.uiScale
                    RowLayout {
                        Layout.fillWidth: true
                        layoutDirection: root.rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
                        spacing: 16 * root.uiScale
                        SettingLabel { objectName: "formatLabel"; text: qsTranslate("Main", "Result format") }
                        SettingComboBox {
                            id: resultFormatBox
                            objectName: "resultFormatBox"
                            model: [qsTranslate("Main", "Automatic"), qsTranslate("Main", "Fixed"), qsTranslate("Main", "Scientific"), qsTranslate("Main", "Engineering")]
                            currentIndex: ["automatic", "fixed", "scientific", "engineering"].indexOf(root.calculatorBackend.format)
                            onActivated: root.calculatorBackend.setFormatting(["automatic", "fixed", "scientific", "engineering"][currentIndex], root.calculatorBackend.precision)
                        }
                    }
                    HelpText {
                        text: resultFormatBox.currentIndex === 0
                            ? qsTranslate("Main", "Automatic removes extra zeros. Example: 2.500 becomes 2.5.")
                            : resultFormatBox.currentIndex === 1
                            ? qsTranslate("Main", "Fixed always shows the selected decimal places. Example: 2.5 can become 2.500.")
                            : resultFormatBox.currentIndex === 2
                            ? qsTranslate("Main", "Scientific uses powers of ten. Example: 1,000,000 is shown using e6.")
                            : qsTranslate("Main", "Engineering uses powers in steps of three. Example: 12,000 is shown using e3.")
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8 * root.uiScale
                    RowLayout {
                        Layout.fillWidth: true
                        layoutDirection: root.rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
                        spacing: 16 * root.uiScale
                        SettingLabel { text: qsTranslate("Main", "Decimal places") }
                        SpinBox {
                            id: precisionBox
                            objectName: "precisionBox"
                            Layout.preferredWidth: 160 * root.uiScale
                            implicitHeight: 42 * root.uiScale
                            font.pixelSize: Math.round(16 * root.uiScale)
                            from: 1
                            to: 100
                            value: root.calculatorBackend.precision
                            editable: true
                            LayoutMirroring.enabled: root.rightToLeft
                            LayoutMirroring.childrenInherit: true
                            onValueModified: root.calculatorBackend.setFormatting(root.calculatorBackend.format, value)
                            // The desktop style assigns value while editing, removing a normal binding.
                            Connections {
                                target: root.calculatorBackend
                                function onPrecisionChanged() {
                                    if (precisionBox.value !== root.calculatorBackend.precision)
                                        precisionBox.value = root.calculatorBackend.precision
                                }
                            }
                        }
                    }
                    HelpText {
                        text: qsTranslate("Main", "For Basic, Advanced, and Financial, sets digits after the decimal in Fixed, Scientific, and Engineering. With 3 places, 2.5 becomes 2.500.")
                    }
                }

                MenuSeparator { Layout.fillWidth: true }

                SettingLabel {
                    text: qsTranslate("Main", "Calculation")
                    font.bold: true
                    font.pixelSize: Math.round(20 * root.uiScale)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8 * root.uiScale
                    RowLayout {
                        Layout.fillWidth: true
                        layoutDirection: root.rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
                        spacing: 16 * root.uiScale
                        SettingLabel { text: qsTranslate("Main", "Angle unit") }
                        SettingComboBox {
                            objectName: "angleUnitBox"
                            model: [qsTranslate("Main", "Degrees"), qsTranslate("Main", "Radians"), qsTranslate("Main", "Gradians")]
                            currentIndex: ["degrees", "radians", "gradians"].indexOf(root.calculatorBackend.angleUnit)
                            onActivated: root.calculatorBackend.applyAngleUnit(["degrees", "radians", "gradians"][currentIndex])
                        }
                    }
                    HelpText {
                        text: root.calculatorBackend.angleUnit === "degrees"
                            ? qsTranslate("Main", "Uses 360 degrees per full turn. Example: sin(30) = 0.5.")
                            : root.calculatorBackend.angleUnit === "radians"
                            ? qsTranslate("Main", "Uses 2π radians per full turn. Example: sin(π / 2) = 1.")
                            : qsTranslate("Main", "Uses 400 gradians per full turn. Example: sin(50) is about 0.707.")
                    }
                }
            }
        }
    }

    footer: ToolBar {
        padding: 16 * root.uiScale
        RowLayout {
            anchors.fill: parent
            layoutDirection: root.rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
            spacing: 16 * root.uiScale
            SettingButton {
                objectName: "resetSettingsButton"
                text: qsTranslate("Main", "Reset settings")
                enabled: root.calculatorBackend.preferencesModified
                onClicked: root.calculatorBackend.resetPreferences(root.programmerMode)
            }
            Item { Layout.fillWidth: true }
            SettingButton {
                objectName: "closeSettingsButton"
                text: qsTranslate("Main", "Close")
                onClicked: root.close()
            }
        }
    }
}
