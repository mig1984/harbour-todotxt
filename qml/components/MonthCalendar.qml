import QtQuick 2.0
import Sailfish.Silica 1.0

// Month grid with year/month navigation, shared by CalendarPage (jump to a
// task's due date) and DeferPage (pick a date). The owner decides what a
// selected day means; this only draws the grid and marks the given dates.
Item {
    id: cal

    property int shownYear: new Date().getFullYear()
    property int shownMonth: new Date().getMonth()
    // "yyyy-MM-dd" dates to mark (coloured); empty for a plain calendar.
    property var dueDates: []
    // Threshold dates; a missed (past) one marks its day yellow.
    property var thresholdDates: []
    // Today's date, used to decide whether a threshold is missed.
    readonly property string todayKey: taskModel.today()
    // When true only marked days can be tapped (e.g. jumping to a task).
    property bool onlyMarked: false

    signal daySelected(string date)
    signal monthChanged()

    width: parent ? parent.width : 0
    implicitHeight: column.height

    function pad(n) { return n < 10 ? "0" + n : "" + n }
    function dateKey(y, m, d) { return y + "-" + pad(m + 1) + "-" + pad(d) }
    function keyToDate(k) {
        var p = k.split("-")
        return new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))
    }
    function daysFromToday(k) {
        var t = keyToDate(taskModel.today())
        var d = keyToDate(k)
        return Math.round((d.getTime() - t.getTime()) / 86400000)
    }
    function stateColor(k) {
        var diff = daysFromToday(k)
        if (diff < 0) return app.dateMissedColor       // missed
        if (diff === 0) return app.dateTodayColor      // today
        if (diff <= 2) return app.dateSoonColor        // tomorrow / day after
        return Theme.secondaryColor                    // later
    }
    function stateTextColor(k) {
        return daysFromToday(k) > 2 ? "#000000" : "#ffffff"
    }
    function shiftMonth(delta) {
        var d = new Date(shownYear, shownMonth + delta, 1)
        shownYear = d.getFullYear()
        shownMonth = d.getMonth()
        monthChanged()
    }
    function shiftYear(delta) {
        shownYear += delta
        monthChanged()
    }
    function today() {
        var now = new Date()
        shownYear = now.getFullYear()
        shownMonth = now.getMonth()
        monthChanged()
    }

    property var dueMap: ({})
    property var thresholdMap: ({})
    function refreshMarks() {
        var d = {}
        for (var i = 0; i < dueDates.length; i++)
            d[dueDates[i]] = true
        dueMap = d
        var t = {}
        for (var j = 0; j < thresholdDates.length; j++)
            t[thresholdDates[j]] = true
        thresholdMap = t
    }
    onDueDatesChanged: refreshMarks()
    onThresholdDatesChanged: refreshMarks()
    Component.onCompleted: refreshMarks()

    // dueDates() is a plain function call; the model does not notify bindings,
    // so refresh the marks explicitly when the list changes.
    Connections {
        target: taskModel
        onCountChanged: cal.refreshMarks()
        onDataChanged: cal.refreshMarks()
        onModelReset: cal.refreshMarks()
    }

    property var cells: {
        var out = []
        var first = new Date(shownYear, shownMonth, 1)
        var lead = (first.getDay() + 6) % 7
        var days = new Date(shownYear, shownMonth + 1, 0).getDate()
        for (var i = 0; i < lead; i++) out.push(0)
        for (var d = 1; d <= days; d++) out.push(d)
        while (out.length % 7) out.push(0)
        return out
    }

    Column {
        id: column
        width: parent.width

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingSmall
            IconButton {
                icon.source: "image://theme/icon-m-previous"
                onClicked: cal.shiftYear(-1)
            }
            IconButton {
                icon.source: "image://theme/icon-m-left"
                onClicked: cal.shiftMonth(-1)
            }
            Item {
                width: Theme.itemSizeExtraLarge * 1.6
                height: Theme.itemSizeMedium
                Label {
                    anchors.centerIn: parent
                    text: Qt.formatDate(new Date(cal.shownYear, cal.shownMonth, 1), "MMMM yyyy")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.highlightColor
                }
            }
            IconButton {
                icon.source: "image://theme/icon-m-right"
                onClicked: cal.shiftMonth(1)
            }
            IconButton {
                icon.source: "image://theme/icon-m-next"
                onClicked: cal.shiftYear(1)
            }
        }

        Row {
            width: parent.width
            Repeater {
                model: 7
                Label {
                    width: column.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    text: Qt.formatDate(new Date(2024, 0, 1 + index), "ddd")
                }
            }
        }

        Grid {
            id: grid
            width: parent.width
            columns: 7

            Repeater {
                model: cal.cells
                Item {
                    width: grid.width / 7
                    height: width * 0.95

                    property string key: modelData > 0
                                         ? cal.dateKey(cal.shownYear, cal.shownMonth, modelData) : ""
                    property bool isToday: key.length > 0 && key === cal.todayKey
                    property bool hasDue: modelData > 0 && cal.dueMap[key] === true
                    property bool hasThr: key.length > 0 && cal.thresholdMap[key] === true
                    property bool marked: isToday || hasDue || hasThr

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.78
                        height: width
                        radius: width / 2
                        visible: parent.marked
                        color: parent.isToday ? app.dateTodayColor
                             : parent.hasThr ? app.thresholdColor
                             : cal.stateColor(parent.key)
                    }
                    Label {
                        anchors.centerIn: parent
                        text: modelData > 0 ? modelData : ""
                        color: parent.isToday ? "#ffffff"
                             : parent.hasThr ? "#000000"
                             : (parent.marked ? cal.stateTextColor(parent.key) : Theme.primaryColor)
                        opacity: modelData > 0 ? 1.0 : 0.0
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.key.length > 0 && (cal.onlyMarked ? parent.marked : true)
                        onClicked: cal.daySelected(parent.key)
                    }
                }
            }
        }
    }
}
