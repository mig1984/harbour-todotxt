import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

// Month view of the due dates of the tasks in the current filter.
// Tapping a day jumps back to the task list at the first task due that day.
// The shown month/year is remembered in the settings; the "Today" button
// resets the view to the current month.
Page {
    id: page

    signal dateSelected(string date)

    function saveShown() {
        settings.calendarYear = cal.shownYear
        settings.calendarMonth = cal.shownMonth
    }

    Component.onCompleted: {
        if (settings.calendarYear > 0)
            cal.shownYear = settings.calendarYear
        if (settings.calendarMonth >= 0)
            cal.shownMonth = settings.calendarMonth
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Calendar")
                description: cal ? app.monthLabel(cal.shownYear, cal.shownMonth) : ""
            }

            Button {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Today")
                onClicked: cal.today()
            }

            Item { width: 1; height: Theme.paddingLarge }

            MonthCalendar {
                id: cal
                width: parent.width
                onlyMarked: true
                dueDates: taskModel.dueDates()
                thresholdDates: taskModel.thresholdDates()
                onDaySelected: {
                    page.dateSelected(date)
                    pageStack.pop()
                }
                onMonthChanged: page.saveShown()
            }

            Item { width: 1; height: Theme.paddingLarge }
        }

        VerticalScrollDecorator { }
    }
}
