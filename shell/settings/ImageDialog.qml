import QtQuick
import QtQuick.Dialogs
import "../logic/wallpaper.js" as Wallpaper
import "../services"

FileDialog {
    id: dialog

    title: "Choose wallpaper"
    nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)"]
    fileMode: FileDialog.OpenFile
    onAccepted: {
        var path = Wallpaper.pathFromFileUrl(dialog.selectedFile.toString())
        if (path !== "")
            SettingsStore.setWallpaperPath(path)
    }
}
