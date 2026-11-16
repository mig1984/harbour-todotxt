import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0

FilePickerPage {
    nameFilters: [ "*.txt" ]
    onSelectedContentPropertiesChanged: {
        var path = selectedContentProperties.filePath
        if (path && path.length > 0)
            settings.todoFile = path
    }
}
