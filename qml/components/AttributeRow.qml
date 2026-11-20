import QtQuick 2.0
import Sailfish.Silica 1.0

// An editor value row (label + value, taps open the full picker page) with an
// inline, horizontally swipeable strip of quick suggestions on the right. The
// label/value part is a separate clickable area, so tapping it opens the page
// while the strip next to it can be swiped and its chips tapped. With
// `separator` a thin divider is drawn between the current value and the strip
// (useful when items can be added on top of an existing value).
Item {
    id: root

    property string label
    property string value
    property color valueColor: Theme.highlightColor
    // Suggestions are shown only when asked (typically when nothing is picked).
    property bool showSuggestions: false
    property var suggestions: []
    property string suggestionPrefix: ""
    property var suggestionColor: function(item) { return Theme.highlightColor }
    // Draw a divider between the current value and the suggestion strip.
    property bool separator: false

    signal opened()
    signal picked(string item)

    width: parent ? parent.width : 0
    readonly property bool stripVisible: showSuggestions && suggestions.length > 0
    readonly property bool separatorVisible: separator && stripVisible
    height: Math.max(mainArea.height, stripVisible ? suggestionsStrip.height : 0)

    BackgroundItem {
        id: mainArea
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: Math.min(parent.width, contentRow.width + 2 * Theme.paddingMedium)
        height: Math.max(Theme.itemSizeSmall, contentRow.height + 2 * Theme.paddingSmall)
        onClicked: root.opened()

        Row {
            id: contentRow
            anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
            spacing: Theme.paddingMedium
            Label {
                id: titleText
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: mainArea.down ? Theme.highlightColor : Theme.primaryColor
            }
            Label {
                id: valueText
                anchors.verticalCenter: parent.verticalCenter
                text: root.value
                // Cap the width so the suggestions strip keeps its place even
                // when many items are already on the line.
                width: Math.min(implicitWidth, root.width * 0.35)
                elide: Text.ElideRight
                color: mainArea.down ? Theme.highlightColor : root.valueColor
            }
        }
    }

    Rectangle {
        id: divider
        visible: root.separatorVisible
        anchors { left: mainArea.right; leftMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
        width: Math.max(1, Math.round(Theme.paddingSmall / 3))
        height: Math.round(Theme.itemSizeSmall * 0.6)
        color: Theme.secondaryColor
        opacity: 0.6
    }

    Flickable {
        id: suggestionsStrip
        anchors {
            left: root.separatorVisible ? divider.right : mainArea.right
            leftMargin: Theme.paddingSmall
            right: parent.right; rightMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
        height: root.stripVisible ? chips.implicitHeight : 0
        contentWidth: chips.width
        contentHeight: chips.implicitHeight
        clip: true
        visible: root.stripVisible
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width

        Row {
            id: chips
            spacing: Theme.paddingSmall
            Repeater {
                model: root.suggestions
                BackgroundItem {
                    // Comfortable, consistent tap target (single-letter priority
                    // chips would otherwise be tiny).
                    width: Math.max(Theme.itemSizeSmall, chipLabel.implicitWidth + 2 * Theme.paddingMedium)
                    height: Theme.itemSizeSmall
                    onClicked: root.picked(modelData)
                    Label {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: root.suggestionPrefix + modelData
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.suggestionColor(modelData)
                    }
                }
            }
        }
        HorizontalScrollDecorator { }
    }
}
