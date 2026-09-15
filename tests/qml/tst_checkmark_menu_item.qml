import QtQuick
import QtQuick.Controls
import QtTest
import "../../qml" as Calculator

TestCase {
    name: "CheckmarkMenuItem"

    Calculator.CheckmarkMenuItem {
        id: item
        text: "Automatic"
    }

    function test_selection_indicator() {
        item.selected = false
        compare(item.indicatorText, "")
        verify(!item.font.bold)

        item.selected = true
        compare(item.indicatorText, "✓")
        verify(item.font.bold)

        item.indicatorColor = "#ffffff"
        compare(item.indicatorColor, "#ffffff")
    }
}
