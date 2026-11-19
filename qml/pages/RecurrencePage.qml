import QtQuick 2.0
import Sailfish.Silica 1.0

// Editor for a task's recurrence (rec:). Presets are buttons that apply
// immediately (the active one is highlighted); the Custom section has controls
// and a "Set: ..." button. Emits selected("") to clear, or "1w" / "+1m"
// (the + means "from the due date", strict).
Page {
    id: page

    property string current: ""
    property int customCount: 1
    property string customUnit: "d"
    property bool customStrict: false

    signal selected(string value)

    function pick(v) {
        selected(v)
        pageStack.pop()
    }
    function customValue() {
        return (customStrict ? "+" : "") + customCount + customUnit
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader { title: qsTr("Recurrence") }

            SectionHeader { text: qsTr("Presets") }
            Flow {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingSmall
                Repeater {
                    model: ListModel {
                        ListElement { label: QT_TR_NOOP("No repetition"); value: "" }
                        ListElement { label: QT_TR_NOOP("Every day"); value: "1d" }
                        ListElement { label: QT_TR_NOOP("Every 2 days"); value: "2d" }
                        ListElement { label: QT_TR_NOOP("Every week"); value: "1w" }
                        ListElement { label: QT_TR_NOOP("Every 2 weeks"); value: "2w" }
                        ListElement { label: QT_TR_NOOP("Every month"); value: "1m" }
                        ListElement { label: QT_TR_NOOP("Every year"); value: "1y" }
                        ListElement { label: QT_TR_NOOP("Every week, from due"); value: "+1w" }
                        ListElement { label: QT_TR_NOOP("Every month, from due"); value: "+1m" }
                        ListElement { label: QT_TR_NOOP("Every year, from due"); value: "+1y" }
                    }
                    Button {
                        width: implicitWidth
                        text: qsTr(model.label)
                        color: page.current === model.value ? Theme.highlightColor : Theme.primaryColor
                        backgroundColor: page.current === model.value
                                         ? Theme.rgba(Theme.highlightColor, Theme.opacityLow)
                                         : Theme.rgba(Theme.primaryColor, Theme.opacityFaint)
                        onClicked: page.pick(model.value)
                    }
                }
            }

            SectionHeader { text: qsTr("Custom") }
            TextSwitch {
                text: qsTr("From due date (strict)")
                description: qsTr("Otherwise the next date counts from completion")
                checked: page.customStrict
                onCheckedChanged: page.customStrict = checked
            }
            Slider {
                width: parent.width
                label: qsTr("Every N")
                minimumValue: 1
                maximumValue: 30
                stepSize: 1
                value: page.customCount
                valueText: value
                onReleased: page.customCount = value
            }
            Flow {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingLarge
                Repeater {
                    model: ListModel {
                        ListElement { unit: "d"; label: QT_TR_NOOP("days") }
                        ListElement { unit: "b"; label: QT_TR_NOOP("working days") }
                        ListElement { unit: "w"; label: QT_TR_NOOP("weeks") }
                        ListElement { unit: "m"; label: QT_TR_NOOP("months") }
                        ListElement { unit: "y"; label: QT_TR_NOOP("years") }
                    }
                    // Plain links: they only set the unit, nothing is saved.
                    Label {
                        text: qsTr(model.label)
                        font.pixelSize: Theme.fontSizeSmall
                        font.underline: page.customUnit === model.unit
                        color: page.customUnit === model.unit ? Theme.primaryColor : Theme.highlightColor
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -Theme.paddingMedium
                            onClicked: page.customUnit = model.unit
                        }
                    }
                }
            }
            Item { width: 1; height: Theme.paddingLarge }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Set: %1").arg(page.customValue())
                onClicked: page.pick(page.customValue())
            }

            Item { width: 1; height: Theme.paddingLarge }
        }

        VerticalScrollDecorator { }
    }
}
