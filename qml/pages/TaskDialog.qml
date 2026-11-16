import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: dialog

    property var taskIds: []      // empty = new task(s)
    property string text: ""
    property int initialCursor: -1
    readonly property bool editing: taskIds.length > 0
    // The editor works with a single line; the exception is editing several
    // selected tasks at once, where each line still maps to one task.
    readonly property bool singleLine: taskIds.length <= 1

    canAccept: editing || editor.text.trim().length > 0

    onAccepted: {
        if (editing)
            store.updateTasks(taskIds, editor.text)
        else
            store.addTasks(editor.text)
    }

    // Returns [lineStart, lineEnd] of the line containing the cursor
    function currentLineRange() {
        var t = editor.text
        var pos = editor.cursorPosition
        var start = t.lastIndexOf("\n", pos - 1) + 1
        var end = t.indexOf("\n", pos)
        if (end < 0) end = t.length
        return [start, end]
    }

    function currentLine() {
        var r = currentLineRange()
        return editor.text.substring(r[0], r[1])
    }

    function replaceCurrentLine(newLine) {
        var r = currentLineRange()
        var t = editor.text
        editor.text = t.substring(0, r[0]) + newLine + t.substring(r[1])
        editor.cursorPosition = r[0] + newLine.length
    }

    // Append words to the current line (if not already there)
    function appendToLine(words) {
        var line = currentLine()
        var tokens = line.split(" ")
        var add = []
        for (var i = 0; i < words.length; i++)
            if (tokens.indexOf(words[i]) < 0) add.push(words[i])
        if (add.length === 0) return
        var trimmed = line.replace(/\s+$/, "")
        replaceCurrentLine((trimmed.length > 0 ? trimmed + " " : "") + add.join(" "))
    }

    function removeFromLine(words) {
        var line = currentLine()
        var tokens = line.split(" ")
        var out = []
        for (var i = 0; i < tokens.length; i++)
            if (words.indexOf(tokens[i]) < 0) out.push(tokens[i])
        replaceCurrentLine(out.join(" "))
    }

    function setKeyValue(key, value) {
        // key e.g. "due" -> replaces due:... token on the current line
        var line = currentLine()
        var re = new RegExp("(^|\\s)" + key + ":\\S+", "i")
        var stripped = line.replace(re, "").replace(/\s+$/, "")
        if (value.length > 0)
            stripped = (stripped.length > 0 ? stripped + " " : "") + key + ":" + value
        replaceCurrentLine(stripped)
    }

    function setPriority(code) {
        var line = currentLine()
        var m = line.match(/^(x \d{4}-\d{2}-\d{2} )?(\(\w\) )?(.*)$/)
        var head = m[1] || ""
        var rest = m[3]
        replaceCurrentLine(head + (code !== "-" && code.length > 0 ? "(" + code + ") " : "") + rest)
    }

    function lineItems(prefix) {
        var r = []
        var tokens = currentLine().split(" ")
        for (var i = 0; i < tokens.length; i++)
            if (tokens[i].length > 1 && tokens[i].charAt(0) === prefix) r.push(tokens[i].substring(1))
        return r
    }

    function dateFromLine(key) {
        var m = currentLine().match(new RegExp("(^|\\s)" + key + ":(\\d{4}-\\d{2}-\\d{2})", "i"))
        return m ? m[2] : ""
    }

    function deferValue(d) {
        // DeferPage gives "", "YYYY-MM-DD" or interval like "1w" (relative to today)
        if (d.length === 0 || /^\d{4}-\d{2}-\d{2}$/.test(d)) return d
        return addInterval(new Date(), d)
    }

    function addInterval(date, interval) {
        var m = interval.match(/^(\d*)([dwmyb])$/)
        if (!m) return ""
        var n = m[1].length > 0 ? parseInt(m[1]) : 1
        var dt = new Date(date.getFullYear(), date.getMonth(), date.getDate())
        switch (m[2]) {
        case "d": dt.setDate(dt.getDate() + n); break
        case "w": dt.setDate(dt.getDate() + 7 * n); break
        case "m": dt.setMonth(dt.getMonth() + n); break
        case "y": dt.setFullYear(dt.getFullYear() + n); break
        case "b":
            while (n > 0) {
                var dow = dt.getDay()
                dt.setDate(dt.getDate() + (dow === 5 ? 3 : dow === 6 ? 2 : 1))
                n--
            }
            break
        }
        return Qt.formatDate(dt, "yyyy-MM-dd")
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            DialogHeader {
                title: editing ? qsTr("Update") : qsTr("Add task")
                acceptText: qsTr("Save")
            }

            TextArea {
                id: editor
                width: parent.width
                text: dialog.text
                placeholderText: dialog.singleLine ? qsTr("Task") : qsTr("One task per line")
                inputMethodHints: settings.capitalizeTasks ? Qt.ImhNone : Qt.ImhNoAutoUppercase
                onTextChanged: {
                    if (!dialog.singleLine || text.indexOf("\n") < 0) return
                    var pos = cursorPosition
                    var t = text.replace(/\s*\n+\s*/g, " ")
                    text = t
                    cursorPosition = Math.min(pos, t.length)
                }
                Component.onCompleted: {
                    cursorPosition = initialCursor >= 0 ? initialCursor : text.length
                    forceActiveFocus()
                }
            }

            // Live values from the line under the cursor
            property string lineLists: { editor.text; editor.cursorPosition; return lineItems("@").map(function(x) { return "@" + x }).join(" ") }
            property string lineTags: { editor.text; editor.cursorPosition; return lineItems("+").map(function(x) { return "+" + x }).join(" ") }
            property string linePriority: {
                editor.text; editor.cursorPosition
                var m = currentLine().match(/^(x \d{4}-\d{2}-\d{2} )?\((\w)\) /)
                return m ? m[2] : "-"
            }
            property string lineDue: { editor.text; editor.cursorPosition; return dateFromLine("due") }
            property string lineThreshold: { editor.text; editor.cursorPosition; return dateFromLine("t") }

            ValueButton {
                label: app.listsTerm
                value: column.lineLists.length > 0 ? column.lineLists : qsTr("None")
                onClicked: {
                    var p = pageStack.push(Qt.resolvedUrl("ItemsPage.qml"), {
                        "isLists": true, "checked": lineItems("@") })
                    p.changed.connect(function(added, removed) {
                        removeFromLine(removed.map(function(x) { return "@" + x }))
                        appendToLine(added.map(function(x) { return "@" + x }))
                    })
                }
            }
            ValueButton {
                label: app.tagsTerm
                value: column.lineTags.length > 0 ? column.lineTags : qsTr("None")
                onClicked: {
                    var p = pageStack.push(Qt.resolvedUrl("ItemsPage.qml"), {
                        "isLists": false, "checked": lineItems("+") })
                    p.changed.connect(function(added, removed) {
                        removeFromLine(removed.map(function(x) { return "+" + x }))
                        appendToLine(added.map(function(x) { return "+" + x }))
                    })
                }
            }
            ValueButton {
                label: qsTr("Priority")
                value: column.linePriority !== "-" ? column.linePriority : qsTr("No priority")
                valueColor: column.linePriority !== "-" ? app.priorityColor(column.linePriority) : Theme.highlightColor
                onClicked: {
                    var p = pageStack.push(Qt.resolvedUrl("PriorityPage.qml"), { "current": column.linePriority })
                    p.selected.connect(setPriority)
                }
            }
            ValueButton {
                label: qsTr("Due")
                value: column.lineDue.length > 0 ? column.lineDue + " (" + taskModel.relativeDate(column.lineDue) + ")" : qsTr("No date")
                onClicked: {
                    var p = pageStack.push(Qt.resolvedUrl("DeferPage.qml"), { "title": qsTr("Due date"), "current": column.lineDue })
                    p.selected.connect(function(d) { setKeyValue("due", deferValue(d)) })
                }
            }
            ValueButton {
                label: qsTr("Threshold")
                value: column.lineThreshold.length > 0 ? column.lineThreshold + " (" + taskModel.relativeDate(column.lineThreshold) + ")" : qsTr("No date")
                onClicked: {
                    var p = pageStack.push(Qt.resolvedUrl("DeferPage.qml"), { "title": qsTr("Threshold date"), "current": column.lineThreshold })
                    p.selected.connect(function(d) { setKeyValue("t", deferValue(d)) })
                }
            }
            Item { width: 1; height: Theme.paddingLarge }
        }
        VerticalScrollDecorator { }
    }
}
