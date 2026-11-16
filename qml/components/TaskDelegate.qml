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
    highlighted: down || menuOpen || (selectionMode && isSelected) || dragging
    menu: contextMenu

    onClicked: {
        if (selectionMode)
            taskModel.toggleSelected(taskId)
        else
            app.openTaskDialog([taskId])
    }

    function dateLine() {
        var parts = []
        if (age.length > 0 && !completed)
            parts.push(age)
        if (completionDate.length > 0)
            parts.push(qsTr("done %1").arg(completionDate))
        if (due.length > 0)
            parts.push("<font color=\"" + app.dateStateColor(completed ? 0 : dueState, Theme.secondaryColor) + "\">" + qsTr("due %1").arg(due) + "</font>")
        if (threshold.length > 0)
            parts.push("<font color=\"" + app.dateStateColor(completed ? 0 : thresholdState, Theme.secondaryColor) + "\">" + qsTr("t %1").arg(threshold) + "</font>")
        if (recurrence.length > 0)
            parts.push("rec:" + recurrence)
        return parts.join(" \u2022 ")
    }

    // Completion / selection mark
    Rectangle {
        id: mark
        anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
        width: Theme.iconSizeSmall + Theme.paddingSmall
        height: width
        radius: width / 2
        color: (selectionMode ? isSelected : completed) ? Theme.highlightColor : "transparent"
        border.color: selectionMode ? Theme.highlightColor : Theme.secondaryColor
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
                else store.toggleComplete(taskId)
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
        Label {
            width: parent.width
            visible: settings.showDateBar && text.length > 0
            wrapMode: Text.Wrap
            textFormat: Text.StyledText
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            text: dateLine()
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
            anchors.fill: parent
            preventStealing: true
            onPressed: {
                dragging = true
                dragBlocked = false
                view.interactive = false
            }
            onPositionChanged: {
                if (!dragging) return
                var p = mapToItem(view.contentItem, mouse.x, mouse.y)
                var idx = view.indexAt(p.x, p.y)
                if (idx < 0 || idx === index) return
                if (taskModel.canMove(index, idx)) {
                    dragBlocked = false
                    taskModel.previewMove(index, idx)
                } else {
                    dragBlocked = true
                }
            }
            onReleased: finish()
            onCanceled: finish()
            function finish() {
                if (!dragging) return
                dragging = false
                dragBlocked = false
                view.interactive = true
                taskModel.commitMove(index)
            }
        }
    }

    Component {
        id: contextMenu
        ContextMenu {
            MenuItem {
                text: completed ? qsTr("Mark incomplete") : qsTr("Complete")
                onClicked: store.toggleComplete(taskId)
            }
            MenuItem {
                text: qsTr("Priority")
                onClicked: {
                    var p = pageStack.push(Qt.resolvedUrl("../pages/PriorityPage.qml"), { "current": priority })
                    p.selected.connect(function(code) { store.setPriority([taskId], code) })
                }
            }
            MenuItem {
                text: qsTr("Due date")
                onClicked: {
                    var p = pageStack.push(Qt.resolvedUrl("../pages/DeferPage.qml"), { "title": qsTr("Due date"), "current": due })
                    p.selected.connect(function(d) { store.deferDue([taskId], d) })
                }
            }
            MenuItem {
                text: qsTr("Threshold date")
                onClicked: {
                    var p = pageStack.push(Qt.resolvedUrl("../pages/DeferPage.qml"), { "title": qsTr("Threshold date"), "current": threshold })
                    p.selected.connect(function(d) { store.deferThreshold([taskId], d) })
                }
            }
            Repeater {
                model: links
                MenuItem {
                    text: qsTr("Open %1").arg(modelData)
                    truncationMode: TruncationMode.Fade
                    onClicked: Qt.openUrlExternally(modelData)
                }
            }
            Repeater {
                model: phones
                MenuItem {
                    text: qsTr("Call %1").arg(modelData)
                    onClicked: Qt.openUrlExternally("tel:" + modelData)
                }
            }
            Repeater {
                model: mails
                MenuItem {
                    text: qsTr("Mail %1").arg(modelData)
                    onClicked: Qt.openUrlExternally("mailto:" + modelData)
                }
            }
            MenuItem {
                text: qsTr("Select")
                visible: !selectionMode
                onClicked: requestSelectionMode()
            }
            MenuItem {
                text: qsTr("Delete")
                onClicked: item.remorseAction(qsTr("Deleting"), function() { store.remove([taskId]) })
            }
        }
    }
}
