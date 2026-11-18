import QtQuick 2.0
import Sailfish.Silica 1.0

// Pick a date: none, relative interval, or a specific date.
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

    SilicaListView {
        anchors.fill: parent
        header: PageHeader {
            title: page.title
            description: current.length > 0 ? current : ""
        }
        model: ListModel {
            ListElement { label: QT_TR_NOOP("Today"); value: "0d" }
            ListElement { label: QT_TR_NOOP("Tomorrow"); value: "1d" }
            ListElement { label: QT_TR_NOOP("Day after tomorrow"); value: "2d" }
            ListElement { label: QT_TR_NOOP("In one week"); value: "1w" }
            ListElement { label: QT_TR_NOOP("In two weeks"); value: "2w" }
            ListElement { label: QT_TR_NOOP("In one month"); value: "1m" }
            ListElement { label: QT_TR_NOOP("No date"); value: "" }
            ListElement { label: QT_TR_NOOP("Pick a date\u2026"); value: "pick" }
        }
        delegate: ListItem {
            Label {
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr(label)
                color: highlighted ? Theme.highlightColor : Theme.primaryColor
            }
            onClicked: {
                if (value === "pick") {
                    var init = current.length > 0 ? new Date(current) : new Date()
                    var dlg = pageStack.push("Sailfish.Silica.DatePickerDialog", {
                        "date": init,
                        "acceptDestination": pageStack.previousPage(page),
                        "acceptDestinationAction": PageStackAction.Pop
                    })
                    dlg.accepted.connect(function() {
                        selected(Qt.formatDate(dlg.date, "yyyy-MM-dd"))
                    })
                } else {
                    pick(value)
                }
            }
        }
    }
}
