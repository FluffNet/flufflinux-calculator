import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

MenuItem {
    id: item
    property bool selected: false
    property color indicatorColor: palette.text
    readonly property string indicatorText: selected ? "✓" : ""

    font.bold: selected
    leftPadding: 10
    contentItem: RowLayout {
        spacing: 8

        Text {
            Layout.minimumWidth: 18
            Layout.preferredWidth: 18
            text: item.indicatorText
            color: item.enabled ? item.indicatorColor : item.palette.mid
            font.pixelSize: 16
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Label {
            Layout.fillWidth: true
            text: item.text
            color: item.enabled ? item.palette.text : item.palette.mid
            font: item.font
            verticalAlignment: Text.AlignVCenter
        }
    }
}
