import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

Page {
    id: page

    property bool selectionMode: false
    property bool searchOpen: false

    // A filter set on the Filter page (contexts/projects/priorities), as
    // opposed to the search box. Only these show the header clear button, so
    // clearing the filter does not leave an open, filled search box behind.
    readonly property bool hasStructuredFilter: query.contexts.length > 0
            || query.projects.length > 0 || query.priorities.length > 0

    function openFilter() {
        pageStack.push(Qt.resolvedUrl("FilterPage.qml"))
    }

    // Scroll to the first task due on the given yyyy-MM-dd date.
    function scrollToDate(date) {
        var row = taskModel.rowForDueDate(date)
        if (row >= 0)
            listView.positionViewAtIndex(row, ListView.Beginning)
    }

    function openCalendar() {
        var p = pageStack.push(Qt.resolvedUrl("CalendarPage.qml"))
        p.dateSelected.connect(function(date) { page.scrollToDate(date) })
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
        var s = qsTr("%n tasks", "", taskModel.pendingCount)
        if (store.changesPending)
            s += " \u2022 " + qsTr("unsaved")
        return s
    }

    // On first start, if no folder has been chosen yet, ask for one by opening
    // the settings page where the todo.txt/done.txt folder is picked.
    function maybeChooseFolder() {
        if (!settings.todoFolderConfigured)
            pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
    }

    Component.onCompleted: folderPromptTimer.start()

    // Deferred so the page stack is ready before pushing.
    Timer {
        id: folderPromptTimer
        interval: 50
        onTriggered: page.maybeChooseFolder()
    }

    // The whole page is one flickable so the pull-down menu appears at the very
    // top (over the header) and can be pulled down by dragging the fixed header
    // itself, in addition to the usual pull at the top of the list.
    SilicaFlickable {
        id: scrollArea
        anchors.fill: parent
        contentWidth: width
        contentHeight: height

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
                text: qsTr("Reload file")
                visible: !selectionMode
                onClicked: store.reload()
            }
            MenuItem {
                text: qsTr("Archive completed tasks")
                visible: !selectionMode && taskModel.completedCount > 0
                onClicked: {
                    var ids = taskModel.allCompletedIds()
                    if (ids.length === 0) return
                    remorse.execute(qsTr("Archiving %n tasks", "", ids.length), function() {
                        store.archive(ids)
                    })
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

        Column {
            id: headerColumn
            width: scrollArea.width

            PageHeader {
                id: pageHeader
                title: headerTitle()
                description: headerDescription()

                // Elide a long filter summary with "..." and keep it clear of
                // the action buttons, which sit to the left of the title.
                _titleItem.truncationMode: TruncationMode.Elide
                _titleItem.width: Math.min(_titleItem.implicitWidth,
                    pageHeader.width - pageHeader.leftMargin - pageHeader.rightMargin
                    - Theme.horizontalPageMargin - calendarButton.width - filterButton.width
                    - searchButton.width - (clearButton.visible ? clearButton.width : 0))

                extraContent.children: [
                    IconButton {
                        id: clearButton
                        // In selection mode: cancel the selection (like clearing
                        // the filter). Otherwise: clear the active filter.
                        visible: page.selectionMode || page.hasStructuredFilter
                        anchors {
                            right: parent.right
                            rightMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                        icon.source: "image://theme/icon-m-clear"
                        onClicked: {
                            if (page.selectionMode) {
                                page.exitSelection()
                            } else {
                                query.clear()
                                page.searchOpen = false
                            }
                        }
                    },
                    IconButton {
                        id: calendarButton
                        anchors {
                            right: clearButton.visible ? clearButton.left : parent.right
                            rightMargin: clearButton.visible ? 0 : Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                        icon.source: "image://theme/icon-m-date"
                        onClicked: page.openCalendar()
                    },
                    IconButton {
                        id: filterButton
                        anchors {
                            right: calendarButton.left
                            verticalCenter: parent.verticalCenter
                        }
                        icon.source: "../symbols/icon-m-filter.svg"
                        onClicked: page.openFilter()
                    },
                    IconButton {
                        id: searchButton
                        anchors {
                            right: filterButton.left
                            verticalCenter: parent.verticalCenter
                        }
                        icon.source: "image://theme/icon-m-search"
                        onClicked: {
                            page.searchOpen = true
                            searchField.forceActiveFocus()
                        }
                    }
                ]
            }
            SearchField {
                id: searchField
                width: parent.width
                active: page.searchOpen
                placeholderText: qsTr("Search")
                text: query.search
                onActiveChanged: if (active) forceActiveFocus()
                onTextChanged: query.search = text
                canHide: true
                onFocusChanged: if (!focus && text.length === 0) page.searchOpen = false
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: {
                    if (text.length === 0) page.searchOpen = false
                    focus = false
                }
                // Tapping the clear ("x") button also hides the field.
                rightItem: IconButton {
                    icon.source: searchField.canHide && searchField.text.length === 0
                                 ? "image://theme/icon-m-input-remove"
                                 : "image://theme/icon-m-clear"
                    enabled: searchField.canHide || searchField.text.length > 0
                    opacity: enabled ? 1.0 : 0.0
                    Behavior on opacity { FadeAnimation {} }
                    onClicked: {
                        searchField.text = ""
                        page.searchOpen = false
                    }
                }
            }
        }

        SilicaListView {
            id: listView
            width: scrollArea.width
            y: headerColumn.height
            height: scrollArea.height - headerColumn.height
            model: taskModel
            currentIndex: -1
            clip: true
            // Row highlighted as the target while dragging a task to another
            // due-date group (set by TaskDelegate).
            property int dropIndex: -1

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
                text: !settings.todoFolderConfigured ? qsTr("No folder selected")
                    : (store.error.length > 0 ? store.error
                        : (query.hasFilter ? qsTr("No matching tasks") : qsTr("No tasks")))
                hintText: !settings.todoFolderConfigured ? qsTr("Choose the folder with todo.txt in Settings")
                    : (store.error.length > 0 ? store.todoFile
                        : (query.hasFilter ? qsTr("Tap the filter icon to change the filter") : qsTr("Pull down to add a task")))
            }

            VerticalScrollDecorator { }
        }
    }

    // Swipe left opens the new task dialog. The filter is opened from the
    // filter icon in the header.
    Connections {
        target: swipeDetector
        onSwipeLeft: {
            if (page.status === PageStatus.Active && !page.selectionMode)
                app.newTask()
        }
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
