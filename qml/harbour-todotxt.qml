import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"
import "cover"

ApplicationWindow {
    id: app

    initialPage: Component { MainPage { } }
    cover: Component { CoverPage { } }
    allowedOrientations: defaultAllowedOrientations

    // Terminology: Simpletask's "list/tag" vs todo.txt "context/project"
    readonly property string listTerm: settings.todoTxtTerms ? qsTr("Context") : qsTr("List")
    readonly property string listsTerm: settings.todoTxtTerms ? qsTr("Contexts") : qsTr("Lists")
    readonly property string tagTerm: settings.todoTxtTerms ? qsTr("Project") : qsTr("Tag")
    readonly property string tagsTerm: settings.todoTxtTerms ? qsTr("Projects") : qsTr("Tags")

    function priorityColor(p) {
        switch (p) {
        case "A": return "#ff5d5d"
        case "B": return "#ffa500"
        case "C": return "#5dc85d"
        case "D": return "#5d9cff"
        default: return Theme.secondaryColor
        }
    }

    // 0 none, 1 overdue, 2 today, 3 tomorrow, 4 later
    function dateStateColor(state, fallback) {
        if (!settings.colorDates) return fallback
        switch (state) {
        case 1: return "#ff5d5d"
        case 2: return "#5dc85d"
        case 3: return "#5d9cff"
        default: return fallback
        }
    }

    function openTaskDialog(ids) {
        var text = ""
        var lines = []
        for (var i = 0; i < ids.length; i++)
            lines.push(store.taskText(ids[i]))
        var dlg = pageStack.push(Qt.resolvedUrl("pages/TaskDialog.qml"), {
            "taskIds": ids,
            "text": lines.join("\n")
        })
        return dlg
    }

    function newTask(prefillText) {
        var prefill = prefillText !== undefined ? prefillText : query.prefill
        // Put the cursor after a leading priority token, so the task text is
        // typed in the right place. A space is left at the cursor so that
        // typing pushes the prefilled context/project to the right:
        // "(A) " + typed text + " @home +proj".
        var pos = 0
        var m = prefill.match(/^\([^)]+\)\s+/)
        if (m) pos = m[0].length
        var text = prefill.length > 0
                ? prefill.substring(0, pos) + " " + prefill.substring(pos) : ""
        var dlg = pageStack.push(Qt.resolvedUrl("pages/TaskDialog.qml"), {
            "taskIds": [],
            "text": text,
            "initialCursor": pos
        })
        return dlg
    }

    Connections {
        target: Qt.application
        onActiveChanged: if (Qt.application.active) taskModel.refresh()
    }
}
