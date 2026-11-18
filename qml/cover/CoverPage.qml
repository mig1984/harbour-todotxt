import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    id: cover

    Column {
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.paddingLarge }
        spacing: Theme.paddingSmall

        Label {
            width: parent.width
            text: query.name.length > 0 ? query.name : (query.hasFilter ? query.summary : qsTr("Todo.txt"))
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeSmall
            truncationMode: TruncationMode.Fade
        }
        Label {
            width: parent.width
            text: taskModel.pendingCount
            font.pixelSize: Theme.fontSizeHuge
        }
        Label {
            width: parent.width
            visible: taskModel.overdueCount > 0 || taskModel.dueTodayCount > 0
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            text: (taskModel.overdueCount > 0 ? "<font color=\"#ff5d5d\">" + qsTr("%n overdue", "", taskModel.overdueCount) + "</font> " : "")
                  + (taskModel.dueTodayCount > 0 ? "<font color=\"#5dc85d\">" + qsTr("%n today", "", taskModel.dueTodayCount) + "</font>" : "")
            textFormat: Text.StyledText
        }
        ListView {
            width: parent.width
            height: cover.height * 0.55
            clip: true
            interactive: false
            model: taskModel.coverTasks
            delegate: Label {
                width: parent.width
                text: (modelData.priority !== "-" ? "(" + modelData.priority + ") " : "")
                      + modelData.text.replace(/<[^>]*>/g, "")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.primaryColor
                truncationMode: TruncationMode.Fade
            }
        }
    }

    CoverActionList {
        CoverAction {
            iconSource: "image://theme/icon-cover-new"
            onTriggered: {
                app.activate()
                app.newTask()
            }
        }
    }
}
