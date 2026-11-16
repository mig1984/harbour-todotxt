import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: dialog
    property string title: qsTr("Name")
    property string name: ""

    canAccept: field.text.trim().length > 0
    onAccepted: name = field.text.trim()

    Column {
        width: parent.width
        DialogHeader { title: dialog.title }
        TextField {
            id: field
            width: parent.width
            text: dialog.name
            label: qsTr("Name")
            placeholderText: label
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: dialog.accept()
            Component.onCompleted: { forceActiveFocus(); selectAll() }
        }
    }
}
