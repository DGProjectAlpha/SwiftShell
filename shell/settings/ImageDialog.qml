import QtQuick
import QtQuick.Dialogs
import "../services"

FileDialog {
    id: dialog

    title: "Choose wallpaper"
    nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)"]
    fileMode: FileDialog.OpenFile
    onAccepted: {
        var text = dialog.selectedFile.toString()
        if (text.indexOf("file://") === 0)
            text = text.slice(7)
        SettingsStore.setWallpaperPath(text)
    }
}
