import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property var lists: []
    property var tags: []
    property var prios: []

    function refreshItems() {
        lists = ["-"].concat(store.allLists())
        tags = ["-"].concat(store.allTags())
        prios = ["-"].concat(store.allPriorities())
    }

    onStatusChanged: if (status === PageStatus.Activating) refreshItems()

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: qsTr("Clear filter")
                enabled: query.hasFilter
                onClicked: query.clear()
            }
            MenuItem {
                text: qsTr("Sort order")
                onClicked: pageStack.push(Qt.resolvedUrl("SortPage.qml"))
            }
            MenuItem {
                text: qsTr("Save as filter")
                onClicked: {
                    var dlg = pageStack.push(Qt.resolvedUrl("NameDialog.qml"), {
                        "name": query.name.length > 0 ? query.name : query.proposedName,
                        "title": qsTr("Save filter")
                    })
                    dlg.accepted.connect(function() {
                        query.name = dlg.name
                        filterStore.save(dlg.name, query.toJson())
                    })
                }
            }
        }

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Filter")
                description: query.hasFilter ? query.summary : qsTr("No filter")
            }

            ExpandingSectionGroup {
                currentIndex: 0

                ExpandingSection {
                    title: app.listsTerm + (query.contexts.length > 0 ? " (" + query.contexts.length + ")" : "")
                    content.sourceComponent: Column {
                        width: page.width
                        Button {
                            text: qsTr("Clear")
                            x: Theme.horizontalPageMargin
                            enabled: query.contexts.length > 0 || query.contextsNot
                            onClicked: query.clearContexts()
                        }
                        TextSwitch {
                            text: qsTr("Invert")
                            description: qsTr("Show tasks NOT matching the selection")
                            checked: query.contextsNot
                            onCheckedChanged: query.contextsNot = checked
                        }
                        Repeater {
                            model: lists
                            TextSwitch {
                                text: modelData === "-" ? qsTr("Without %1").arg(app.listTerm.toLowerCase()) : "@" + modelData
                                checked: query.contexts.indexOf(modelData) >= 0
                                automaticCheck: false
                                onClicked: query.toggleContext(modelData, !checked)
                            }
                        }
                    }
                }

                ExpandingSection {
                    title: app.tagsTerm + (query.projects.length > 0 ? " (" + query.projects.length + ")" : "")
                    content.sourceComponent: Column {
                        width: page.width
                        Button {
                            text: qsTr("Clear")
                            x: Theme.horizontalPageMargin
                            enabled: query.projects.length > 0 || query.projectsNot
                            onClicked: query.clearProjects()
                        }
                        TextSwitch {
                            text: qsTr("Invert")
                            description: qsTr("Show tasks NOT matching the selection")
                            checked: query.projectsNot
                            onCheckedChanged: query.projectsNot = checked
                        }
                        Repeater {
                            model: tags
                            TextSwitch {
                                text: modelData === "-" ? qsTr("Without %1").arg(app.tagTerm.toLowerCase()) : "+" + modelData
                                checked: query.projects.indexOf(modelData) >= 0
                                automaticCheck: false
                                onClicked: query.toggleProject(modelData, !checked)
                            }
                        }
                    }
                }

                ExpandingSection {
                    title: qsTr("Priorities") + (query.priorities.length > 0 ? " (" + query.priorities.length + ")" : "")
                    content.sourceComponent: Column {
                        width: page.width
                        Button {
                            text: qsTr("Clear")
                            x: Theme.horizontalPageMargin
                            enabled: query.priorities.length > 0 || query.prioritiesNot
                            onClicked: query.clearPriorities()
                        }
                        TextSwitch {
                            text: qsTr("Invert")
                            checked: query.prioritiesNot
                            onCheckedChanged: query.prioritiesNot = checked
                        }
                        Repeater {
                            model: prios
                            TextSwitch {
                                text: modelData === "-" ? qsTr("No priority") : "(" + modelData + ")"
                                checked: query.priorities.indexOf(modelData) >= 0
                                automaticCheck: false
                                onClicked: query.togglePriority(modelData, !checked)
                            }
                        }
                    }
                }

                ExpandingSection {
                    title: qsTr("Other")
                    content.sourceComponent: Column {
                        width: page.width
                        TextSwitch {
                            text: qsTr("Show completed")
                            checked: !query.hideCompleted
                            onCheckedChanged: query.hideCompleted = !checked
                        }
                        TextSwitch {
                            text: qsTr("Show future")
                            description: qsTr("Tasks with a threshold date in the future")
                            checked: !query.hideFuture
                            onCheckedChanged: query.hideFuture = !checked
                        }
                        TextSwitch {
                            text: qsTr("Show hidden")
                            description: qsTr("Tasks with h:1")
                            checked: !query.hideHidden
                            onCheckedChanged: query.hideHidden = !checked
                        }
                        TextSwitch {
                            text: qsTr("Show %1 in tasks").arg(app.listsTerm.toLowerCase())
                            checked: !query.hideLists
                            onCheckedChanged: query.hideLists = !checked
                        }
                        TextSwitch {
                            text: qsTr("Show %1 in tasks").arg(app.tagsTerm.toLowerCase())
                            checked: !query.hideTags
                            onCheckedChanged: query.hideTags = !checked
                        }
                        TextSwitch {
                            text: qsTr("Creation date is threshold")
                            checked: query.createIsThreshold
                            onCheckedChanged: query.createIsThreshold = checked
                        }
                    }
                }
            }
        }
        VerticalScrollDecorator { }
    }
}
