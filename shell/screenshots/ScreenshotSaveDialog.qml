import QtQuick
import QtCore
import QtQuick.Dialogs
import "../services"
FileDialog {
    title:"Save screenshot"
    fileMode:FileDialog.SaveFile
    nameFilters:["PNG image (*.png)"]
    defaultSuffix:"png"
    currentFolder:"file://"+StandardPaths.writableLocation(StandardPaths.PicturesLocation)
    selectedFile:currentFolder+"/Screenshot-"+Qt.formatDateTime(new Date(),"yyyyMMdd-HHmmss")+".png"
    onAccepted:ScreenshotService.save(selectedFile.toString())
}
