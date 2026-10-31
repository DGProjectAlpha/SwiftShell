import QtQuick
import QtQuick.Dialogs
import "../logic/wallpaper.js" as Wallpaper

FolderDialog {
    id: dialog

    signal folderSelected(string path)

    title: "Choose slideshow folder"
    onAccepted: {
        var path = Wallpaper.pathFromFileUrl(dialog.selectedFolder.toString())
        if (path !== "")
            dialog.folderSelected(path)
    }
}
