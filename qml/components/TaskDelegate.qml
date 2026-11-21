import QtQuick 2.0
import Sailfish.Silica 1.0

ListItem {
    id: item

    property bool selectionMode: false
    property var view
    property var outerFlick
    property bool dragBlocked: false
    // Logical row of the dragged task and the row the finger currently wants it
    // at. Kept as state (not inferred from the live delegate index, which shifts
    // as rows are preview-moved) so reordering steps one row at a time without
    // flip-flopping at a row boundary.
    property int dragRow: -1
    property int dropRow: -1
    // Margin the index probe has to clear past a row boundary before the target
    // changes, so rows of different heights cannot oscillate.
    readonly property real hysteresis: Theme.itemSizeSmall / 2
    // Only the base row of a task can be reordered/dragged by hand.
    readonly property bool manual: query.manualSort && !selectionMode && !completed && occurrence === 0

    signal requestSelectionMode()

    width: ListView.view ? ListView.view.width : Screen.width
    contentHeight: content.height + 2 * Theme.paddingMedium
    highlighted: down || menuOpen || (selectionMode && isSelected)
                 || (view && view.dropIndex === index)

    // The row being dragged is dimmed grey, so it is not confused with the
    // blue highlight of the drop target.
    Rectangle {
        anchors.fill: parent
        visible: handle.dragging
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
        var d = due
        var rec = recurring
        item.remorseAction(completed ? qsTr("Marking incomplete") : qsTr("Completing"),
                           function() {
                               if (rec)
                                   store.toggleDone(id, d)
                               else
                                   store.toggleComplete(id)
                           })
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
        if (recurrence.length > 0 && occurrence === 0)
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

    // Drag handle for manual ordering.
    DragHandle {
        id: handle
        anchors.right: parent.right
        listView: view
        scrollFlickable: outerFlick
        active: item.manual
        blocked: item.dragBlocked
        onStarted: {
            item.dragBlocked = false
            item.dragRow = item.indexAtScene(sceneX, sceneY)
            if (item.dragRow < 0)
                item.dragRow = item.index
            item.dropRow = item.dragRow
            item.dragAnchorSceneY = item.sceneYOfRow()
        }
        onMoved: item.updateTarget(sceneX, sceneY)
        onFinished: item.finishDrag()
    }

    // The mid-scene Y of the dragged row. Used as the anchor for the step
    // hysteresis so a row taller than the finger's movement does not flip the
    // target back and forth at a row boundary.
    property real dragAnchorSceneY: 0
    // Scene Y of the dragged row: map the dragged delegate's centre to the scene.
    function sceneYOfRow() {
        return view.contentItem.mapToItem(null, 0, y + height / 2).y
    }

    // Row index at a scene position (independent of which delegate this is).
    function indexAtScene(sceneX, sceneY) {
        var p = view.contentItem.mapFromItem(null, sceneX, sceneY)
        return view.indexAt(p.x, p.y)
    }

    // Resolve a drop at the given scene position to a target row and reflect it:
    // a live reorder within the same due group, or a highlight of the target
    // when the drop would move the task to another due date.
    //
    // indexAt() is computed at a probe point shifted from the finger by a
    // hysteresis margin in the movement direction. Rows reordered here have
    // different heights (task text can wrap), so sampling exactly at the finger
    // makes the boundary between a short and a tall row oscillate: the probe has
    // to clear the boundary by a margin before the target changes.
    function updateTarget(sceneX, sceneY) {
        if (dragRow < 0)
            dragRow = index

        var dir = sceneY < dragAnchorSceneY ? -1 : (sceneY > dragAnchorSceneY ? 1 : 0)
        var probeY = sceneY
        if (dir < 0)
            probeY -= hysteresis
        else if (dir > 0)
            probeY += hysteresis

        var idx = indexAtScene(sceneX, probeY)
        if (idx < 0)
            return
        dropRow = idx
        if (idx === dragRow) { view.dropIndex = -1; return }

        var step = idx > dragRow ? 1 : -1
        if (query.sectionKey === "by_due_date"
                && taskModel.dueAt(idx) !== taskModel.dueAt(dragRow)) {
            // Dragging into another due-date group changes the due date.
            view.dropIndex = idx
            dragBlocked = false
        } else {
            view.dropIndex = -1
            // Reordering within the same due group is shown live, one row at a
            // time, so it does not jump over rows.
            if (taskModel.canMove(dragRow, dragRow + step)) {
                dragBlocked = false
                if (taskModel.previewMove(dragRow, dragRow + step)) {
                    dragRow += step
                    dragAnchorSceneY = sceneY
                }
            } else {
                dragBlocked = true
            }
        }
    }

    function finishDrag() {
        var target = view.dropIndex
        dragBlocked = false
        view.dropIndex = -1
        var row = dragRow >= 0 ? dragRow : index
        dragRow = -1
        dropRow = -1
        if (target >= 0)
            taskModel.moveToDue(row, target)
        else
            taskModel.commitMove(row)
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
