import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    SilicaListView {
        id: view
        anchors.fill: parent
        model: filterStore.names

        PullDownMenu {
            MenuItem {
                text: qsTr("Save current filter")
                onClicked: {
                    var dlg = pageStack.push(Qt.resolvedUrl("NameDialog.qml"), {
                        "name": query.name.length > 0 ? query.name : query.proposedName,
                        "title": qsTr("Save filter")
                    })
                    dlg.accepted.connect(function() {
                        query.name = dlg.name
                        filterStore.save(dlg.name, query.toJson())
                    })
                }
            }
        }

        header: PageHeader { title: qsTr("Saved filters") }

        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeSmall
            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Update with current filter")
                    onClicked: {
                        query.name = modelData
                        filterStore.save(modelData, query.toJson())
                    }
                }
                MenuItem {
                    text: qsTr("Rename")
                    onClicked: {
                        var dlg = pageStack.push(Qt.resolvedUrl("NameDialog.qml"), { "name": modelData, "title": qsTr("Rename filter") })
                        dlg.accepted.connect(function() {
                            if (query.name === modelData) query.name = dlg.name
                            filterStore.rename(modelData, dlg.name)
                        })
                    }
                }
                MenuItem {
                    text: qsTr("Delete")
                    onClicked: item.remorseAction(qsTr("Deleting"), function() { filterStore.remove(modelData) })
                }
            }
            onClicked: {
                query.fromJson(filterStore.get(modelData))
                query.name = modelData
                pageStack.pop()
            }
            Label {
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                text: modelData
                color: highlighted || query.name === modelData ? Theme.highlightColor : Theme.primaryColor
            }
        }

        ViewPlaceholder {
            enabled: view.count === 0
            text: qsTr("No saved filters")
            hintText: qsTr("Set up a filter and pull down to save it")
        }
        VerticalScrollDecorator { }
    }
}
