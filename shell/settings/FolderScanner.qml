import QtQuick
import Qt.labs.folderlistmodel
import "../logic/wallpaper.js" as Wallpaper

Item {
    id: root

    property string folderPath: ""
    property bool ready: false
    property bool collectScheduled: false
    signal scanFinished(var paths, string error)

    function scan(path) {
        root.folderPath = ""
        Qt.callLater(function () { root.folderPath = path })
    }

    function collect() {
        var paths = []
        for (var index = 0; index < files.count && paths.length < 64; index++) {
            var url = files.get(index, "fileUrl")
            var path = Wallpaper.pathFromFileUrl(url ? url.toString() : "")
            if (Wallpaper.resolveSource(path).source === "file")
                paths.push(path)
        }
        root.scanFinished(paths, paths.length > 0 ? "" : "No readable png, jpeg, or webp files were found.")
    }

    function scheduleCollect() {
        if (root.collectScheduled)
            return
        root.collectScheduled = true
        Qt.callLater(function () {
            root.collectScheduled = false
            root.collect()
        })
    }

    FolderListModel {
        id: files
        folder: root.folderPath === "" ? "" : Wallpaper.fileUrl(root.folderPath)
        showDirs: false
        showDotAndDotDot: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"]
        sortField: FolderListModel.Name
        sortReversed: false
        onCountChanged: {
            if (root.ready)
                root.scheduleCollect()
        }
        onStatusChanged: {
            root.ready = status === FolderListModel.Ready
            if (root.ready)
                root.scheduleCollect()
            else if (status === FolderListModel.Error)
                root.scanFinished([], "That folder could not be read.")
        }
    }
}
