import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    // Local copy of all sort keys. Active keys come first in sort order
    // (with direction), inactive keys follow. Edits happen on this model and
    // are written to query.sorts on release / on each discrete action.
    ListModel { id: sortModel }

    function activeCount() {
        var n = 0
        for (var i = 0; i < sortModel.count; i++)
            if (sortModel.get(i).active) n++
        return n
    }

    function reload() {
        sortModel.clear()
        var active = query.effectiveSorts
        for (var i = 0; i < active.length; i++)
            sortModel.append({ "spec": active[i], "active": true })
        var all = query.allKeys()
        for (var j = 0; j < all.length; j++) {
            var found = false
            for (var k = 0; k < active.length; k++)
                if (active[k].substring(2) === all[j]) found = true
            if (!found)
                sortModel.append({ "spec": "+!" + all[j], "active": false })
        }
    }

    function commit() {
        var a = []
        for (var i = 0; i < sortModel.count; i++)
            if (sortModel.get(i).active)
                a.push(sortModel.get(i).spec)
        query.sorts = a
    }

    function flip(i) {
        var s = sortModel.get(i).spec
        sortModel.setProperty(i, "spec", (s.charAt(0) === "-" ? "+" : "-") + s.substring(1))
        commit()
    }

    // Move within the active block only.
    function moveLocal(from, to) {
        var n = activeCount()
        if (from === to || from < 0 || to < 0 || from >= n || to >= n)
            return false
        sortModel.move(from, to, 1)
        return true
    }

    function move(from, to) {
        if (moveLocal(from, to))
            commit()
    }

    function activate(i) {
        sortModel.setProperty(i, "active", true)
        // append to the end of the active block
        var target = activeCount() - 1
        if (i !== target)
            sortModel.move(i, target, 1)
        commit()
    }

    function deactivate(i) {
        if (activeCount() <= 1)
            return
        sortModel.setProperty(i, "active", false)
        // move to the start of the inactive block
        var target = activeCount()
        if (i !== target)
            sortModel.move(i, target, 1)
        commit()
    }

    onStatusChanged: if (status === PageStatus.Activating) reload()

    SilicaListView {
        id: view
        anchors.fill: parent
        model: sortModel

        PullDownMenu {
            MenuItem {
                text: qsTr("Reset to default")
                onClicked: {
                    query.sorts = []
                    page.reload()
                }
            }
        }

        header: PageHeader {
            title: qsTr("Sort order")
            description: query.manualSort ? qsTr("Manual ordering active") : qsTr("Tap to flip direction, long press to move")
        }

        delegate: ListItem {
            id: item
            property bool reversed: spec.charAt(0) === "-"
            property string key: spec.substring(2)
            property bool dragging: false
            contentHeight: Theme.itemSizeSmall
            highlighted: down || menuOpen || dragging
            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Move to top")
                    visible: active
                    enabled: index > 0
                    onClicked: page.move(index, 0)
                }
                MenuItem {
                    text: qsTr("Move up")
                    visible: active
                    enabled: index > 0
                    onClicked: page.move(index, index - 1)
                }
                MenuItem {
                    text: qsTr("Move down")
                    visible: active
                    enabled: index < page.activeCount() - 1
                    onClicked: page.move(index, index + 1)
                }
                MenuItem {
                    text: qsTr("Remove from sort")
                    visible: active
                    enabled: page.activeCount() > 1
                    onClicked: page.deactivate(index)
                }
                MenuItem {
                    text: qsTr("Add to sort")
                    visible: !active
                    onClicked: page.activate(index)
                }
            }
            onClicked: active ? page.flip(index) : page.activate(index)

            Label {
                x: Theme.horizontalPageMargin
                anchors {
                    verticalCenter: parent.verticalCenter
                    right: direction.left
                    rightMargin: Theme.paddingSmall
                }
                truncationMode: TruncationMode.Fade
                opacity: active ? 1.0 : 0.4
                text: (active ? (index + 1) + ". " : "") + (key === "by_context" ? app.listTerm
                                           : key === "by_project" ? app.tagTerm
                                           : query.sortKeyLabel(key))
                color: highlighted ? Theme.highlightColor : Theme.primaryColor
            }
            Icon {
                id: direction
                visible: active
                anchors { right: handle.left; rightMargin: Theme.paddingSmall; verticalCenter: parent.verticalCenter }
                source: reversed ? "image://theme/icon-m-up" : "image://theme/icon-m-down"
                color: highlighted ? Theme.highlightColor : Theme.secondaryColor
            }

            // Drag handle: drag an active row to a new position, applied on release.
            Item {
                id: handle
                visible: active
                width: visible ? Theme.itemSizeSmall : 0
                height: parent.height
                anchors.right: parent.right
                Icon {
                    anchors.centerIn: parent
                    source: "image://theme/icon-m-menu"
                    color: item.dragging ? Theme.highlightColor : Theme.secondaryColor
                    opacity: 0.8
                }
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    onPressed: {
                        item.dragging = true
                        view.interactive = false
                    }
                    onPositionChanged: {
                        if (!item.dragging) return
                        var p = mapToItem(view.contentItem, mouse.x, mouse.y)
                        var idx = view.indexAt(p.x, p.y)
                        if (idx >= 0 && idx !== index)
                            page.moveLocal(index, idx)
                    }
                    onReleased: finish()
                    onCanceled: finish()
                    function finish() {
                        if (!item.dragging) return
                        item.dragging = false
                        view.interactive = true
                        page.commit()
                    }
                }
            }
        }
        VerticalScrollDecorator { }
    }
}
