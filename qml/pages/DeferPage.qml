import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

// Pick a date: none, a relative interval, or an exact date from the calendar.
// Emits selected("") / selected("1w") / selected("YYYY-MM-DD").
Page {
    id: page

    property string title: qsTr("Date")
    property string current: ""

    signal selected(string value)

    function pick(v) {
        selected(v)
        pageStack.pop()
    }

    Component.onCompleted: {
        if (current.length > 0) {
            var p = current.split("-")
            if (p.length === 3) {
                cal.shownYear = parseInt(p[0])
                cal.shownMonth = parseInt(p[1]) - 1
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: page.title
                description: page.current.length > 0 ? app.formatDate(page.current) : ""
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
                onlyMarked: false
                dueDates: taskModel.dueDates()
                thresholdDates: taskModel.thresholdDates()
                onDaySelected: page.pick(date)
            }

            Item { width: 1; height: Theme.paddingLarge }

            // Two columns; "No date" spans the whole row so the last (odd) one
            // is not left alone under the left column.
            Flow {
                id: quick
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingSmall

                Repeater {
                    model: ListModel {
                        ListElement { label: QT_TR_NOOP("Today"); value: "0d" }
                        ListElement { label: QT_TR_NOOP("Tomorrow"); value: "1d" }
                        ListElement { label: QT_TR_NOOP("Day after tomorrow"); value: "2d" }
                        ListElement { label: QT_TR_NOOP("In one week"); value: "1w" }
                        ListElement { label: QT_TR_NOOP("In two weeks"); value: "2w" }
                        ListElement { label: QT_TR_NOOP("In one month"); value: "1m" }
                        ListElement { label: QT_TR_NOOP("No date"); value: "" }
                    }
                    Button {
                        width: model.value === "" ? quick.width : (quick.width - quick.spacing) / 2
                        text: qsTr(model.label)
                        onClicked: page.pick(model.value)
                    }
                }
            }

            Item { width: 1; height: Theme.paddingLarge }
        }

        VerticalScrollDecorator { }
    }
}
