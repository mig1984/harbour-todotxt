import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

Page {
    id: page

    property bool selectionMode: false
    property bool searching: query.search.length > 0

    onStatusChanged: {
        if (status === PageStatus.Active) {
            if (!pageStack.nextPage(page))
                pageStack.pushAttached(Qt.resolvedUrl("FilterPage.qml"))
        }
    }

    // Scroll the list to today's task, or the nearest one by due date.
    function scrollToDue() {
        var row = taskModel.nearestDueRow()
        if (row >= 0)
            listView.positionViewAtIndex(row, ListView.Beginning)
    }

    function exitSelection() {
        selectionMode = false
        taskModel.clearSelection()
    }

    function withSelected(fn) {
        var ids = taskModel.selectedIds()
        if (ids.length > 0) fn(ids)
    }

    function headerTitle() {
        if (selectionMode)
            return qsTr("%n selected", "", taskModel.selectedCount)
        if (query.name.length > 0)
            return query.name
        if (query.hasFilter)
            return query.summary
        return qsTr("All tasks")
    }

    function headerDescription() {
        var s = ""
        if (query.hasFilter || taskModel.count !== taskModel.totalCount)
            s = taskModel.count + " / " + taskModel.totalCount
        else
            s = qsTr("%n tasks", "", taskModel.count)
        if (store.changesPending)
            s += " \u2022 " + qsTr("unsaved")
        return s
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: taskModel
        currentIndex: -1
        clip: true

        PullDownMenu {
            MenuItem {
                text: qsTr("Settings")
                visible: !selectionMode
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("Saved filters")
                visible: !selectionMode
                onClicked: pageStack.push(Qt.resolvedUrl("SavedFiltersPage.qml"))
            }
            MenuItem {
                text: qsTr("Sort order")
                visible: !selectionMode
                onClicked: pageStack.push(Qt.resolvedUrl("SortPage.qml"))
            }
            MenuItem {
                text: searching ? qsTr("Hide search") : qsTr("Search")
                visible: !selectionMode
                onClicked: {
                    if (searching) {
                        query.search = ""
                        searching = false
                    } else {
                        searching = true
                    }
                }
            }
            MenuItem {
                text: selectionMode ? qsTr("Cancel selection") : qsTr("Select tasks")
                onClicked: {
                    if (selectionMode) exitSelection()
                    else selectionMode = true
                }
            }
            MenuItem {
                text: qsTr("Select all")
                visible: selectionMode
                onClicked: taskModel.selectAll()
            }
            MenuItem {
                text: qsTr("Mark incomplete")
                visible: selectionMode
                onClicked: withSelected(function(ids) { store.uncomplete(ids); exitSelection() })
            }
            MenuItem {
                text: qsTr("Threshold date")
                visible: selectionMode
                onClicked: withSelected(function(ids) {
                    var p = pageStack.push(Qt.resolvedUrl("DeferPage.qml"), { "title": qsTr("Threshold date") })
                    p.selected.connect(function(d) { store.deferThreshold(ids, d) })
                })
            }
            MenuItem {
                text: app.tagsTerm
                visible: selectionMode
                onClicked: withSelected(function(ids) {
                    pageStack.push(Qt.resolvedUrl("ItemsPage.qml"), { "taskIds": ids, "isLists": false })
                })
            }
            MenuItem {
                text: qsTr("Archive")
                visible: selectionMode
                onClicked: withSelected(function(ids) {
                    remorse.execute(qsTr("Archiving"), function() { store.archive(ids); exitSelection() })
                })
            }
            MenuItem {
                text: qsTr("New task")
                visible: !selectionMode
                onClicked: app.newTask()
            }
        }

        PushUpMenu {
            visible: !selectionMode
            MenuItem {
                text: qsTr("Reload file")
                onClicked: store.reload()
            }
            MenuItem {
                text: qsTr("Archive completed tasks")
                onClicked: {
                    var ids = taskModel.completedVisibleIds()
                    if (ids.length === 0) return
                    remorse.execute(qsTr("Archiving %n tasks", "", ids.length), function() {
                        store.archive(ids)
                    })
                }
            }
        }

        header: Column {
            width: parent.width
            PageHeader {
                id: pageHeader
                title: headerTitle()
                description: headerDescription()
                extraContent.children: [
                    IconButton {
                        id: clearButton
                        visible: query.hasFilter
                        anchors {
                            right: parent.right
                            rightMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                        icon.source: "image://theme/icon-m-clear"
                        onClicked: query.clear()
                    },
                    IconButton {
                        anchors {
                            right: clearButton.visible ? clearButton.left : parent.right
                            rightMargin: clearButton.visible ? 0 : Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                        icon.source: "image://theme/icon-m-date"
                        onClicked: page.scrollToDue()
                    }
                ]
            }
            SearchField {
                id: searchField
                width: parent.width
                visible: searching
                onVisibleChanged: if (visible) forceActiveFocus()
                placeholderText: qsTr("Search")
                text: query.search
                onTextChanged: query.search = text
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }
        }

        section.property: "section"
        section.criteria: ViewSection.FullString
        section.delegate: SectionHeader {
            text: settings.uppercaseHeaders ? section.toUpperCase() : section
            visible: text.length > 0
            height: text.length > 0 ? implicitHeight : 0
        }

        delegate: TaskDelegate {
            selectionMode: page.selectionMode
            view: listView
            onRequestSelectionMode: {
                page.selectionMode = true
                taskModel.setSelected(taskId, true)
            }
        }

        ViewPlaceholder {
            enabled: listView.count === 0 && store.loaded
            text: store.error.length > 0 ? store.error
                : (query.hasFilter ? qsTr("No matching tasks") : qsTr("No tasks"))
            hintText: store.error.length > 0 ? store.todoFile
                : (query.hasFilter ? qsTr("Swipe left to change the filter") : qsTr("Pull down to add a task"))
        }

        VerticalScrollDecorator { }
    }

    RemorsePopup { id: remorse }

    DockedPanel {
        id: panel
        width: parent.width
        height: Theme.itemSizeLarge
        dock: Dock.Bottom
        open: selectionMode

        Row {
            anchors.centerIn: parent
            spacing: Theme.paddingMedium
            IconButton {
                icon.source: "image://theme/icon-m-acknowledge"
                enabled: taskModel.selectedCount > 0
                onClicked: withSelected(function(ids) { store.complete(ids); exitSelection() })
            }
            IconButton {
                icon.source: "image://theme/icon-m-edit"
                enabled: taskModel.selectedCount > 0
                onClicked: withSelected(function(ids) {
                    var dlg = app.openTaskDialog(ids)
                    dlg.accepted.connect(exitSelection)
                })
            }
            IconButton {
                icon.source: "image://theme/icon-m-date"
                enabled: taskModel.selectedCount > 0
                onClicked: withSelected(function(ids) {
                    var p = pageStack.push(Qt.resolvedUrl("DeferPage.qml"), { "title": qsTr("Due date") })
                    p.selected.connect(function(d) { store.deferDue(ids, d) })
                })
            }
            IconButton {
                icon.source: "image://theme/icon-m-favorite"
                enabled: taskModel.selectedCount > 0
                onClicked: withSelected(function(ids) {
                    var p = pageStack.push(Qt.resolvedUrl("PriorityPage.qml"))
                    p.selected.connect(function(code) { store.setPriority(ids, code) })
                })
            }
            IconButton {
                icon.source: "image://theme/icon-m-note"
                enabled: taskModel.selectedCount > 0
                onClicked: withSelected(function(ids) {
                    pageStack.push(Qt.resolvedUrl("ItemsPage.qml"), { "taskIds": ids, "isLists": true })
                })
            }
            IconButton {
                icon.source: "image://theme/icon-m-delete"
                enabled: taskModel.selectedCount > 0
                onClicked: withSelected(function(ids) {
                    remorse.execute(qsTr("Deleting %n tasks", "", ids.length), function() { store.remove(ids); exitSelection() })
                })
            }
        }
    }
}
