import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property string current: "-"
    signal selected(string code)

    function pick(code) {
        selected(code)
        pageStack.pop()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            PageHeader { title: qsTr("Priority") }

            ListItem {
                contentHeight: Theme.itemSizeSmall
                highlighted: down || current === "-"
                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("No priority")
                    color: highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                onClicked: pick("-")
            }

            Grid {
                id: grid
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                columns: 6
                Repeater {
                    model: 26
                    BackgroundItem {
                        property string code: String.fromCharCode(65 + index)
                        width: grid.width / grid.columns
                        height: Theme.itemSizeMedium
                        highlighted: down || code === current
                        Label {
                            anchors.centerIn: parent
                            text: code
                            font.pixelSize: Theme.fontSizeLarge
                            font.bold: index < 4
                            color: index < 4 ? app.priorityColor(code) : (parent.highlighted ? Theme.highlightColor : Theme.primaryColor)
                        }
                        onClicked: pick(code)
                    }
                }
            }
        }
    }
}
