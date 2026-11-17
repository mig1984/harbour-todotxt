import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.FileManager 1.0

// Pick the folder that holds todo.txt (and done.txt). A simple browser with a
// "Choose" action in the header (the stock folder picker has no visible accept).
Dialog {
    id: dialog

    property string folder: settings.todoFolder.length > 0 ? settings.todoFolder : StandardPaths.home
    signal chosen(string path)

    canAccept: folder.length > 0
    onAccepted: dialog.chosen(dialog.folder)

    function parentOf(p) {
        var s = p.replace(/\/+$/, "")
        var i = s.lastIndexOf("/")
        return i <= 0 ? "/" : s.substring(0, i)
    }

    SilicaListView {
        id: listView
        anchors.fill: parent

        model: FileModel {
            id: fileModel
            path: dialog.folder
            active: dialog.status === PageStatus.Active
            includeDirectories: true
            includeFiles: false
        }

        header: Column {
            width: parent.width

            DialogHeader {
                title: dialog.folder
                acceptText: qsTr("Choose")
                cancelText: qsTr("Back")
            }

            ListItem {
                visible: dialog.folder !== "" && dialog.folder !== "/"
                contentHeight: Theme.itemSizeSmall
                Label {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }
                    text: ".."
                    color: Theme.highlightColor
                }
                onClicked: dialog.folder = dialog.parentOf(dialog.folder)
            }
        }

        delegate: BackgroundItem {
            Label {
                anchors {
                    left: parent.left
                    leftMargin: Theme.horizontalPageMargin
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                text: model.fileName
                truncationMode: TruncationMode.Fade
            }
            onClicked: dialog.folder = model.absolutePath
        }

        ViewPlaceholder {
            enabled: listView.count === 0
            text: qsTr("No subfolders")
        }

        VerticalScrollDecorator { }
    }
}
