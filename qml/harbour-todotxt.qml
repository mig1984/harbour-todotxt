import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"
import "cover"

ApplicationWindow {
    id: app

    // Which Filter page section is expanded (-1 = none). Kept across visits
    // within the session so re-opening the filter keeps the last state.
    property int filterSection: -1

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

    // Due date colors: missed red, today green, tomorrow/day after tomorrow
    // blue, anything later left as the fallback (secondary) color.
    readonly property string dateMissedColor: "#ff5d5d"
    readonly property string dateTodayColor: "#5dc85d"
    readonly property string dateSoonColor: "#5d9cff"

    // Selection mode accent: the header band and the selected task check
    // circles share this color so a selection is easy to spot.
    readonly property string selectionColor: "#ff5d5d"

    // Color a yyyy-MM-dd date according to how far it is from today.
    // Returns fallback when the date is empty or when date coloring is off.
    function dateColor(date, fallback) {
        if (!settings.colorDates || !date)
            return fallback
        var p = date.split("-")
        if (p.length !== 3)
            return fallback
        var t = taskModel.today().split("-")
        var due = new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))
        var today = new Date(parseInt(t[0]), parseInt(t[1]) - 1, parseInt(t[2]))
        var diff = Math.round((due.getTime() - today.getTime()) / 86400000)
        if (diff < 0) return dateMissedColor
        if (diff === 0) return dateTodayColor
        if (diff <= 2) return dateSoonColor
        return fallback
    }

    // Threshold dates are prefixed with this mark in the list so they are not
    // confused with due dates (both are shown as a bare date there).
    readonly property string thresholdMark: "\u2264"
    // Colour of a threshold day / a missed threshold in the list (yellow).
    readonly property string thresholdColor: "#ffd400"

    // A date as shown in the list and section headers: "<weekday> yyyy-MM-dd"
    // (e.g. "st 2026-11-18").
    function formatDate(iso) {
        if (!iso)
            return ""
        var p = iso.split("-")
        if (p.length !== 3)
            return iso
        var d = new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))
        return Qt.formatDate(d, "ddd") + " " + iso
    }

    // Section header text: date sections use formatDate, other keys
    // (context/project/priority/None) are left as-is; both may be uppercased.
    function sectionText(s, upper) {
        var base = /^\d{4}-\d{2}-\d{2}$/.test(s) ? formatDate(s) : s
        return upper ? base.toUpperCase() : base
    }

    // Standalone (nominative) month name, e.g. "květen 2026" not "května 2026".
    function monthLabel(year, month) {
        return Qt.locale().standaloneMonthName(month, Locale.LongFormat) + " " + year
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
