import QtQuick 2.0
import Sailfish.Silica 1.0

// Pick lists (@) or tags (+). Two modes:
//  - taskIds set: applies to the tasks on accept (tri-state for mixed)
//  - checked set: emits changed(added, removed) on accept (used by TaskDialog)
Dialog {
    id: dialog

    property bool isLists: true
    property var taskIds: []
    property var checked: []
    property string newText: ""

    signal changed(var added, var removed)

    readonly property string prefix: isLists ? "@" : "+"

    ListModel { id: items }

    function stateFor(name) {
        if (taskIds.length > 0)
            return isLists ? taskModel.listState(taskIds, name) : taskModel.tagState(taskIds, name)
        return checked.indexOf(name) >= 0 ? 2 : 0
    }

    function addItem(name, initial) {
        for (var i = 0; i < items.count; i++)
            if (items.get(i).name === name) return
        items.append({ "name": name, "initial": initial, "state": initial })
    }

    Component.onCompleted: {
        var all = isLists ? store.allLists() : store.allTags()
        for (var i = 0; i < all.length; i++)
            addItem(all[i], stateFor(all[i]))
        for (var j = 0; j < checked.length; j++)
            addItem(checked[j], 2)
    }

    onAccepted: {
        var added = [], removed = []
        var extra = newText.trim()
        if (extra.length > 0) {
            var words = extra.split(/\s+/)
            for (var w = 0; w < words.length; w++)
                if (added.indexOf(words[w]) < 0) added.push(words[w])
        }
        for (var i = 0; i < items.count; i++) {
            var it = items.get(i)
            if (it.state === 2 && it.initial !== 2) added.push(it.name)
            else if (it.state === 0 && it.initial !== 0) removed.push(it.name)
        }
        if (taskIds.length > 0) {
            if (removed.length > 0) isLists ? store.removeLists(taskIds, removed) : store.removeTags(taskIds, removed)
            if (added.length > 0) isLists ? store.addLists(taskIds, added) : store.addTags(taskIds, added)
        } else {
            changed(added, removed)
        }
    }

    SilicaListView {
        id: view
        anchors.fill: parent
        model: items
        header: Column {
            width: parent.width
            DialogHeader {
                title: isLists ? app.listsTerm : app.tagsTerm
                acceptText: qsTr("Apply")
            }
            TextField {
                id: newField
                width: parent.width
                placeholderText: isLists ? qsTr("New %1 (space separated)").arg(app.listTerm.toLowerCase())
                                         : qsTr("New %1 (space separated)").arg(app.tagTerm.toLowerCase())
                label: placeholderText
                onTextChanged: dialog.newText = text
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: dialog.accept()
            }
        }
        delegate: TextSwitch {
            text: prefix + name
            description: state === 1 ? qsTr("on some of the selected tasks") : ""
            checked: state === 2
            automaticCheck: false
            onClicked: items.setProperty(index, "state", state === 2 ? 0 : 2)
        }
        VerticalScrollDecorator { }
    }
}
