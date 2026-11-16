import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    SilicaListView {
        id: view
        anchors.fill: parent
        model: query.effectiveSorts

        PullDownMenu {
            MenuItem {
                text: qsTr("Reset to default")
                onClicked: query.sorts = []
            }
        }

        header: PageHeader {
            title: qsTr("Sort order")
            description: query.manualSort ? qsTr("Manual ordering active") : qsTr("Tap to flip direction, long press to move")
        }

        delegate: ListItem {
            id: item
            property bool reversed: modelData.charAt(0) === "-"
            property string key: modelData.substring(2)
            contentHeight: Theme.itemSizeSmall
            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Move to top")
                    enabled: index > 0
                    onClicked: query.moveSort(index, 0)
                }
                MenuItem {
                    text: qsTr("Move up")
                    enabled: index > 0
                    onClicked: query.moveSort(index, index - 1)
                }
                MenuItem {
                    text: qsTr("Move down")
                    enabled: index < view.count - 1
                    onClicked: query.moveSort(index, index + 1)
                }
            }
            onClicked: query.setSortDirection(index, !reversed)

            Label {
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                text: (index + 1) + ". " + (key === "by_context" ? app.listTerm
                                           : key === "by_project" ? app.tagTerm
                                           : query.sortKeyLabel(key))
                color: highlighted ? Theme.highlightColor : Theme.primaryColor
            }
            Icon {
                anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                source: reversed ? "image://theme/icon-m-up" : "image://theme/icon-m-down"
                color: highlighted ? Theme.highlightColor : Theme.secondaryColor
            }
        }
        VerticalScrollDecorator { }
    }
}
