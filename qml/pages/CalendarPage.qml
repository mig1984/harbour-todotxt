import QtQuick 2.0
import Sailfish.Silica 1.0

// Month view of the due dates of the tasks in the current filter.
// Tapping a day jumps back to the task list at the first task due that day.
// The shown month/year is remembered in the settings; the "Today" button
// resets the view to the current month.
Page {
    id: page

    property int shownYear: new Date().getFullYear()
    property int shownMonth: new Date().getMonth()
    property var dueMap: ({})

    signal dateSelected(string date)

    // Persist the shown month only when the user navigates, so that tearing
    // the page down does not overwrite it with the default value.
    function saveShown() {
        settings.calendarYear = shownYear
        settings.calendarMonth = shownMonth
    }

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
    function updateDueMap() {
        var d = {}
        var a = taskModel.dueDates()
        for (var i = 0; i < a.length; i++) d[a[i]] = true
        dueMap = d
    }
    function shiftMonth(delta) {
        var d = new Date(shownYear, shownMonth + delta, 1)
        shownYear = d.getFullYear()
        shownMonth = d.getMonth()
        saveShown()
    }
    function shiftYear(delta) {
        shownYear += delta
        saveShown()
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

    Component.onCompleted: {
        if (settings.calendarYear > 0)
            shownYear = settings.calendarYear
        if (settings.calendarMonth >= 0)
            shownMonth = settings.calendarMonth
        updateDueMap()
    }

    Connections {
        target: taskModel
        onCountChanged: page.updateDueMap()
        onDataChanged: page.updateDueMap()
        onModelReset: page.updateDueMap()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Calendar")
                description: Qt.formatDate(new Date(page.shownYear, page.shownMonth, 1), "MMMM yyyy")
            }

            Button {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Today")
                onClicked: {
                    var now = new Date()
                    page.shownYear = now.getFullYear()
                    page.shownMonth = now.getMonth()
                    page.saveShown()
                }
            }

            Item { width: 1; height: Theme.paddingLarge }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingSmall
                IconButton {
                    icon.source: "image://theme/icon-m-previous"
                    onClicked: page.shiftYear(-1)
                }
                IconButton {
                    icon.source: "image://theme/icon-m-left"
                    onClicked: page.shiftMonth(-1)
                }
                Item {
                    width: Theme.itemSizeExtraLarge * 1.6
                    height: Theme.itemSizeMedium
                    Label {
                        anchors.centerIn: parent
                        text: Qt.formatDate(new Date(page.shownYear, page.shownMonth, 1), "MMMM yyyy")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.highlightColor
                    }
                }
                IconButton {
                    icon.source: "image://theme/icon-m-right"
                    onClicked: page.shiftMonth(1)
                }
                IconButton {
                    icon.source: "image://theme/icon-m-next"
                    onClicked: page.shiftYear(1)
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
                    model: page.cells
                    Item {
                        width: grid.width / 7
                        height: width * 0.95

                        property string key: modelData > 0
                                             ? page.dateKey(page.shownYear, page.shownMonth, modelData) : ""
                        property bool marked: modelData > 0 && page.dueMap[key] === true

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height) * 0.78
                            height: width
                            radius: width / 2
                            visible: parent.marked
                            color: parent.marked ? page.stateColor(parent.key) : "transparent"
                        }
                        Label {
                            anchors.centerIn: parent
                            text: modelData > 0 ? modelData : ""
                            color: parent.marked ? page.stateTextColor(parent.key) : Theme.primaryColor
                            opacity: modelData > 0 ? 1.0 : 0.0
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: parent.marked
                            onClicked: {
                                page.dateSelected(parent.key)
                                pageStack.pop()
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: Theme.paddingLarge }
        }

        VerticalScrollDecorator { }
    }
}
