import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader { title: qsTr("Settings") }

            SectionHeader { text: qsTr("Folder") }
            TextField {
                id: pathField
                width: parent.width
                label: qsTr("Folder")
                description: qsTr("todo.txt and done.txt are kept here")
                text: settings.todoFolder
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: { settings.todoFolder = text; focus = false }
                onActiveFocusChanged: if (!activeFocus && text !== settings.todoFolder) settings.todoFolder = text
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Choose folder…")
                onClicked: {
                    var dlg = pageStack.push(Qt.resolvedUrl("PickFolderPage.qml"))
                    dlg.chosen.connect(function(path) { settings.todoFolder = path })
                }
            }
            Item { width: 1; height: Theme.paddingMedium }
            TextSwitch {
                text: qsTr("Windows line breaks (CRLF)")
                checked: settings.windowsEol
                onCheckedChanged: settings.windowsEol = checked
            }
            Slider {
                width: parent.width
                label: qsTr("Delay before saving")
                minimumValue: 0; maximumValue: 10; stepSize: 1
                value: settings.idleBeforeSave
                valueText: value + " s"
                onReleased: settings.idleBeforeSave = value
            }

            SectionHeader { text: qsTr("Tasks") }
            TextSwitch {
                text: qsTr("Add creation date to new tasks")
                checked: settings.prependDate
                onCheckedChanged: settings.prependDate = checked
            }
            TextSwitch {
                text: qsTr("Add new tasks at the end")
                checked: settings.appendAtEnd
                onCheckedChanged: settings.appendAtEnd = checked
            }
            TextSwitch {
                text: qsTr("Keep priority of completed tasks")
                checked: settings.keepPriority
                onCheckedChanged: settings.keepPriority = checked
            }
            TextSwitch {
                text: qsTr("Archive completed tasks automatically")
                description: qsTr("Move to done.txt right after completing")
                checked: settings.autoArchive
                onCheckedChanged: settings.autoArchive = checked
            }
            TextSwitch {
                text: qsTr("Capitalize new tasks")
                checked: settings.capitalizeTasks
                onCheckedChanged: settings.capitalizeTasks = checked
            }
            Slider {
                width: parent.width
                label: qsTr("Recurring tasks")
                minimumValue: 0
                maximumValue: 50
                stepSize: 1
                value: settings.recurrenceOccurrences
                valueText: value === 0 ? qsTr("Off") : qsTr("%1 occurrences").arg(value)
                onReleased: settings.recurrenceOccurrences = value
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Show this number of occurrences into the future and into the past")
            }

            SectionHeader { text: qsTr("Appearance") }
            TextSwitch {
                text: qsTr("Show dates on a separate line")
                checked: settings.showDateBar
                onCheckedChanged: settings.showDateBar = checked
            }
            TextSwitch {
                text: qsTr("Color due dates")
                checked: settings.colorDates
                onCheckedChanged: settings.colorDates = checked
            }
            TextSwitch {
                text: qsTr("Uppercase section headers")
                checked: settings.uppercaseHeaders
                onCheckedChanged: settings.uppercaseHeaders = checked
            }
            TextSwitch {
                text: qsTr("Case sensitive sorting")
                checked: settings.caseSensitiveSort
                onCheckedChanged: settings.caseSensitiveSort = checked
            }
            TextSwitch {
                text: qsTr("Use todo.txt terms (context/project)")
                description: qsTr("Instead of list/tag")
                checked: settings.todoTxtTerms
                onCheckedChanged: settings.todoTxtTerms = checked
            }
            Item { width: 1; height: Theme.paddingLarge }
        }
        VerticalScrollDecorator { }
    }
}
