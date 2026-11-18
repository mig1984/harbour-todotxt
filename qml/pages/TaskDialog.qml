import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: dialog

    property var taskIds: []      // empty = new task(s)
    property string text: ""
    property int initialCursor: -1
    readonly property bool editing: taskIds.length > 0
    // One task per line, except when editing a single task, where the editor
    // stays on a single line. Adding tasks is multi-line: Enter starts the
    // next task.
    readonly property bool singleLine: taskIds.length === 1

    canAccept: editing || hasTaskText(editor.text)

    onAccepted: {
        if (editing)
            store.updateTasks(taskIds, editor.text)
        else
            store.addTasks(tasksOnly(editor.text))
    }

    // True if the line holds any text besides todo.txt structure (priority,
    // dates, key:value such as due:/t:, @lists and +tags).
    function hasTaskText(line) {
        var s = line
            .replace(/^\s*x\s+/i, " ")
            .replace(/(^|\s)(due|t|thr|rec|h|uuid|pri):\S+/ig, " ")
            .replace(/\d{4}-\d{2}-\d{2}/g, " ")
            .replace(/(^|\s)\(\w\)/g, " ")
            .replace(/(^|\s)[@+]\S+/g, " ")
        return s.trim().length > 0
    }

    function tasksOnly(text) {
        var lines = text.split("\n")
        var keep = []
        for (var i = 0; i < lines.length; i++)
            if (hasTaskText(lines[i])) keep.push(lines[i])
        return keep.join("\n")
    }

    // Prefill for the next task when Enter is pressed: the structure of the
    // current line (priority, due:, t:, @lists, +tags), with the cursor placed
    // before it so the typed text goes first and the attributes end up at the
    // end of the line - matching how the ValueButtons edit the line.
    function nextLinePrefill(line) {
        var m = line.match(/^(?:x \d{4}-\d{2}-\d{2} )?\((\w)\) /)
        var head = m ? "(" + m[1] + ") " : ""
        var tokens = []
        var due = line.match(/(^|\s)due:(\d{4}-\d{2}-\d{2})/i)
        if (due) tokens.push("due:" + due[2])
        var thr = line.match(/(^|\s)t:(\d{4}-\d{2}-\d{2})/i)
        if (thr) tokens.push("t:" + thr[2])
        var lists = line.match(/(^|\s)@\S+/g) || []
        for (var i = 0; i < lists.length; i++) tokens.push(lists[i].trim())
        var tags = line.match(/(^|\s)\+\S+/g) || []
        for (var j = 0; j < tags.length; j++) tokens.push(tags[j].trim())
        if (head.length > 0)
            return { "text": tokens.length > 0 ? head + " " + tokens.join(" ") : head, "pos": head.length }
        if (tokens.length > 0)
            return { "text": " " + tokens.join(" "), "pos": 0 }
        return { "text": "", "pos": 0 }
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

    function uniqueMatch(list) {
        var out = []
        for (var i = 0; i < list.length; i++)
            if (list[i].length > 0 && out.indexOf(list[i]) < 0)
                out.push(list[i])
        return out
    }

    // Openable links / phone numbers / e-mail addresses in the edited text,
    // offered as actions (the task long-press menu used to have them).
    function foundOpenItems() {
        var items = []
        var links = uniqueMatch(editor.text.match(/[a-zA-Z][a-zA-Z0-9+.-]*:\/\/[^\s]+/g) || [])
        for (var i = 0; i < links.length; i++)
            items.push({ "label": qsTr("Open %1").arg(links[i]), "url": links[i] })
        var mails = uniqueMatch(editor.text.match(/[a-zA-Z0-9+._%\-]+@[a-zA-Z0-9][a-zA-Z0-9\-]{0,64}(?:\.[a-zA-Z0-9][a-zA-Z0-9\-]{0,25})+/g) || [])
        for (i = 0; i < mails.length; i++)
            items.push({ "label": qsTr("Mail %1").arg(mails[i]), "url": "mailto:" + mails[i] })
        var phones = uniqueMatch((editor.text.match(/(?:^|\s)(\+?[0-9][0-9,#()\-]{3,})(?=\s|$)/g) || []).map(function(s) { return s.trim() }))
        for (i = 0; i < phones.length; i++) {
            if (/^\d{4}-\d{2}-\d{2}$/.test(phones[i]) || /^#\d+$/.test(phones[i]))
                continue
            items.push({ "label": qsTr("Call %1").arg(phones[i]), "url": "tel:" + phones[i].replace(/[^+0-9]/g, "") })
        }
        return items
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            DialogHeader {
                title: editing ? qsTr("Update") : qsTr("Add tasks")
                acceptText: qsTr("Save")
            }

            TextArea {
                id: editor
                width: parent.width
                text: dialog.text
                placeholderText: dialog.singleLine ? qsTr("Task") : qsTr("One task per line")
                inputMethodHints: settings.capitalizeTasks ? Qt.ImhNone : Qt.ImhNoAutoUppercase
                // Text as it was before the last edit, to spot a line break
                // added by pressing Enter; adjusting guards our own edits.
                property string previousText: ""
                property bool adjusting: false

                function newlineCount(s) { return s.split("\n").length - 1 }

                onTextChanged: {
                    if (adjusting) { previousText = text; return }
                    if (dialog.singleLine) {
                        if (text.indexOf("\n") < 0) { previousText = text; return }
                        var pos = cursorPosition
                        var collapsed = text.replace(/\s*\n+\s*/g, " ")
                        adjusting = true
                        text = collapsed
                        cursorPosition = Math.min(pos, collapsed.length)
                        adjusting = false
                        previousText = text
                        return
                    }
                    // Multi-line: a line break was just added at the cursor. The
                    // editor may have split the line at the cursor, so rebuild
                    // the whole line we left and add a new task below, prefilled
                    // with all of its attributes.
                    if (newlineCount(text) === newlineCount(previousText) + 1
                            && cursorPosition > 0 && text.charAt(cursorPosition - 1) === "\n") {
                        var at = cursorPosition
                        var lineStart = text.lastIndexOf("\n", at - 2) + 1
                        var lineEnd = text.indexOf("\n", at)
                        if (lineEnd < 0) lineEnd = text.length
                        var original = text.substring(lineStart, at - 1) + text.substring(at, lineEnd)
                        var p = nextLinePrefill(original)
                        adjusting = true
                        // Assigning text resets cursorPosition, so set it after.
                        text = text.substring(0, lineStart) + original + "\n" + p.text + text.substring(lineEnd)
                        cursorPosition = lineStart + original.length + 1 + p.pos
                        adjusting = false
                        previousText = text
                        return
                    }
                    previousText = text
                }
                Component.onCompleted: {
                    cursorPosition = initialCursor >= 0 ? initialCursor : text.length
                    forceActiveFocus()
                    previousText = text
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
            property var openItems: { editor.text; return foundOpenItems() }

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
            Repeater {
                model: column.openItems
                ValueButton {
                    label: modelData.label
                    onClicked: Qt.openUrlExternally(modelData.url)
                }
            }
            Item { width: 1; height: Theme.paddingLarge }
        }
        VerticalScrollDecorator { }
    }
}
