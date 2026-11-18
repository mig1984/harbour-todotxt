import QtQuick 2.0
import Sailfish.Silica 1.0

ListItem {
    id: item

    property bool selectionMode: false
    property var view
    property bool dragging: false
    property bool dragBlocked: false
    readonly property bool manual: query.manualSort && !selectionMode && !completed

    signal requestSelectionMode()

    width: ListView.view ? ListView.view.width : Screen.width
    contentHeight: content.height + 2 * Theme.paddingMedium
    highlighted: down || menuOpen || (selectionMode && isSelected)
                 || (view && view.dropIndex === index)

    // The row being dragged is dimmed grey, so it is not confused with the
    // blue highlight of the drop target.
    Rectangle {
        anchors.fill: parent
        visible: item.dragging
        color: Theme.rgba(Theme.secondaryColor, 0.15)
    }

    onClicked: {
        if (selectionMode)
            taskModel.toggleSelected(taskId)
        else
            app.openTaskDialog([taskId])
    }

    // Completing/uncompleting shows a remorse bar; tapping it cancels the change.
    function toggleCompleteWithUndo() {
        var id = taskId
        item.remorseAction(completed ? qsTr("Marking incomplete") : qsTr("Completing"),
                           function() { store.toggleComplete(id) })
    }

    // Segments of the date line under the task. Each entry is rendered as a
    // small label; a missed threshold gets a coloured "chip" (see below).
    function dateParts() {
        var list = []
        if (createDate.length > 0 && !completed)
            list.push({ "text": app.formatDate(createDate), "color": Theme.secondaryColor, "chip": false })
        if (completionDate.length > 0)
            list.push({ "text": qsTr("done %1").arg(completionDate), "color": Theme.secondaryColor, "chip": false })
        if (due.length > 0)
            list.push({ "text": app.formatDate(due), "color": app.dateColor(completed ? "" : due, Theme.secondaryColor), "chip": false })
        if (threshold.length > 0) {
            // A threshold of a not-completed task is always a yellow chip.
            list.push({ "text": app.thresholdMark + " " + app.formatDate(threshold),
                        "color": completed ? Theme.secondaryColor : "#000000",
                        "chip": !completed })
        }
        if (recurrence.length > 0)
            list.push({ "text": "rec:" + recurrence, "color": Theme.secondaryColor, "chip": false })
        var out = []
        for (var i = 0; i < list.length; i++) {
            // A missed threshold is a coloured chip; no separator before it.
            if (i > 0 && !list[i].chip)
                out.push({ "text": "\u2022", "color": Theme.secondaryColor, "chip": false })
            out.push(list[i])
        }
        return out
    }

    // Completion / selection mark
    Rectangle {
        id: mark
        anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
        width: Theme.iconSizeSmall + Theme.paddingSmall
        height: width
        radius: width / 2
        color: selectionMode
               ? (isSelected ? app.selectionColor : "transparent")
               : (completed ? Theme.highlightColor : "transparent")
        border.color: selectionMode
                      ? (isSelected ? app.selectionColor : Theme.secondaryColor)
                      : Theme.secondaryColor
        border.width: Math.max(1, Theme.paddingSmall / 3)
        Icon {
            anchors.centerIn: parent
            source: "image://theme/icon-s-checkmark"
            visible: selectionMode ? isSelected : completed
            color: Theme.primaryColor
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.paddingMedium
            onClicked: {
                if (selectionMode) taskModel.toggleSelected(taskId)
                else item.toggleCompleteWithUndo()
            }
        }
    }

    Column {
        id: content
        anchors {
            left: mark.right; leftMargin: Theme.paddingLarge
            right: handle.visible ? handle.left : parent.right
            rightMargin: handle.visible ? Theme.paddingSmall : Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.paddingSmall / 2

        Label {
            width: parent.width
            wrapMode: Text.Wrap
            textFormat: Text.StyledText
            font.strikeout: completed
            color: completed ? Theme.secondaryColor : (item.highlighted ? Theme.highlightColor : Theme.primaryColor)
            text: (priority !== "-" ? "<font color=\"" + app.priorityColor(priority) + "\">(" + priority + ")</font> " : "")
                  + display.replace(/#SEC#/g, Theme.secondaryColor).replace(/#LINK#/g, Theme.highlightColor)
        }
        Flow {
            id: dateFlow
            width: parent.width
            spacing: Theme.paddingSmall
            visible: settings.showDateBar && parts.length > 0
            readonly property var parts: item.dateParts()
            Repeater {
                model: dateFlow.parts
                Item {
                    width: seg.implicitWidth + (modelData.chip ? 2 * Theme.paddingSmall : 0)
                    height: seg.implicitHeight
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.paddingSmall / 2
                        color: app.thresholdColor
                        visible: modelData.chip
                    }
                    Label {
                        id: seg
                        anchors.centerIn: parent
                        text: modelData.text
                        color: modelData.color
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }
        }
    }

    // Drag handle for manual ordering
    Item {
        id: handle
        visible: manual
        width: visible ? Theme.itemSizeSmall : 0
        height: parent.height
        anchors.right: parent.right
        Icon {
            anchors.centerIn: parent
            source: dragBlocked ? "image://theme/icon-m-cancel" : "image://theme/icon-m-menu"
            color: dragging ? Theme.highlightColor : Theme.secondaryColor
            opacity: 0.8
        }
        MouseArea {
            id: dragArea
            anchors.fill: parent
            preventStealing: true

            // Pointer position in scene coordinates, so it stays valid while
            // the list auto-scrolls under a still finger.
            property real pointerX: 0
            property real pointerY: 0
            readonly property real sceneTop: view ? view.mapToItem(null, 0, 0).y : 0
            readonly property real sceneBottom: view ? view.mapToItem(null, 0, view.height).y : 0
            readonly property real edge: Theme.itemSizeLarge
            readonly property int scrollStep: 8

            function updateTarget() {
                var p = view.contentItem.mapFromItem(null, pointerX, pointerY)
                var idx = view.indexAt(p.x, p.y)
                if (idx < 0 || idx === index) { view.dropIndex = -1; return }
                if (query.sectionKey === "by_due_date"
                        && taskModel.dueAt(idx) !== taskModel.dueAt(index)) {
                    // Dragging into another due-date group changes the due date.
                    view.dropIndex = idx
                    dragBlocked = false
                } else {
                    view.dropIndex = -1
                    if (taskModel.canMove(index, idx)) {
                        dragBlocked = false
                        taskModel.previewMove(index, idx)
                    } else {
                        dragBlocked = true
                    }
                }
            }

            onPressed: {
                dragging = true
                dragBlocked = false
                view.interactive = false
                // Keep the dragged delegate alive while auto-scrolling.
                view.cacheBuffer = Theme.itemSizeMedium * 60
                var s = mapToItem(null, mouse.x, mouse.y)
                pointerX = s.x
                pointerY = s.y
            }
            onPositionChanged: {
                if (!dragging) return
                var s = mapToItem(null, mouse.x, mouse.y)
                pointerX = s.x
                pointerY = s.y
                updateTarget()
            }
            onReleased: finish()
            onCanceled: finish()
            function finish() {
                if (!dragging) return
                var target = view.dropIndex
                dragging = false
                dragBlocked = false
                view.interactive = true
                view.dropIndex = -1
                view.cacheBuffer = Theme.itemSizeMedium * 8
                if (target >= 0)
                    taskModel.moveToDue(index, target)
                else
                    taskModel.commitMove(index)
            }

            // Slowly auto-scroll while the finger is dragged past an edge.
            Timer {
                interval: 20
                repeat: true
                running: dragging
                         && (dragArea.pointerY < dragArea.sceneTop + dragArea.edge
                             || dragArea.pointerY > dragArea.sceneBottom - dragArea.edge)
                onTriggered: {
                    var dy = 0
                    if (dragArea.pointerY < dragArea.sceneTop + dragArea.edge)
                        dy = -dragArea.scrollStep
                    else if (dragArea.pointerY > dragArea.sceneBottom - dragArea.edge)
                        dy = dragArea.scrollStep
                    if (dy === 0) return
                    var maxY = Math.max(0, view.contentHeight - view.height)
                    var y = Math.max(0, Math.min(view.contentY + dy, maxY))
                    if (y !== view.contentY) {
                        view.contentY = y
                        dragArea.updateTarget()
                    }
                }
            }
        }
    }

    // Long press enters multi-selection (and selects the pressed task) instead
    // of opening a context menu, matching the usual Sailfish pattern.
    onPressAndHold: {
        if (selectionMode)
            taskModel.setSelected(taskId, true)
        else
            requestSelectionMode()
    }
}
