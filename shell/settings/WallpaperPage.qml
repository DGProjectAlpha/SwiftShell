import QtQuick
import Quickshell
import "../components"
import "../logic/settingsNav.js" as Nav
import "../logic/slideshow.js" as Slideshow
import "../logic/wallpaper.js" as Wallpaper
import "../services"
import "../themes"

Item {
    id: page

    property string query: ""
    property string highlightId: ""
    property string dialogReason: ""
    property string pickerOutput: ""
    property string folderReason: ""
    property string selectedFolder: ""
    property string pathNote: ""
    property bool previewFailed: false
    signal revealRequested(real y, real itemHeight)
    signal edited(var patch)

    implicitWidth: 560
    implicitHeight: column.implicitHeight
    height: implicitHeight

    readonly property url packagedSource: Qt.resolvedUrl("../assets/wallpapers/swiftshell-default-crimson.png")
    readonly property var previewChoice: Wallpaper.resolveSource(SettingsStore.wallpaperPath)

    function shows(id) {
        return Nav.controlVisible(page.query, id)
    }

    function marked(id) {
        return page.highlightId === id
    }

    function moveHighlight(delta) {
        page.highlightId = Nav.moveSelection(page.query, page.highlightId, delta)
    }

    function focusHighlight() {
        pathField.forceActiveFocus()
    }

    function addSlide(text) {
        var choice = Wallpaper.resolveSource(text)
        page.pathNote = choice.reason
        if (choice.source === "file") {
            SettingsStore.addSlide(choice.path)
            slideField.text = ""
        }
    }

    function scanFolder(path) {
        page.selectedFolder = path
        page.folderReason = ""
        if (folderScanner.status === Loader.Ready && folderScanner.item)
            folderScanner.item.scan(path)
        else
            folderScanner.active = true
    }

    function folderScanned(paths, error) {
        page.folderReason = error
        if (paths && paths.length > 0)
            SettingsStore.setSlidesJson(JSON.stringify(paths))
    }

    function outputPath(name) {
        var map = Wallpaper.outputMap(SettingsStore.wallpaperOutputsJson)
        return map && map[name] ? map[name] : ""
    }

    function sourceUrl(choice) {
        if (choice && choice.source === "file")
            return Wallpaper.fileUrl(choice.path)
        return packagedSource
    }

    function itemFor(id) {
        for (var index = 0; index < column.children.length; index++) {
            if (column.children[index].controlId === id)
                return column.children[index]
        }
        return null
    }

    onQueryChanged: page.highlightId = Nav.firstControlId(page.query)
    onHighlightIdChanged: {
        var item = itemFor(page.highlightId)
        if (item)
            revealRequested(item.y, item.height)
    }

    onPreviewChoiceChanged: previewFailed = false

    function pickColor(field,current) {
        if(colorPicker.status === Loader.Ready) {
            colorPicker.item.field=field
            colorPicker.item.selectedColor=current || (field === "manualText" ? Theme.settingsText : Theme.panelColor)
            colorPicker.item.open()
        } else { page.colorField=field;colorPicker.active=true }
    }
    property string colorField: ""
    Loader {
        id:colorPicker
        active:false
        source:"ColorPicker.qml"
        onLoaded: {
            item.colorChosen.connect(function(field,value){const patch={};patch[field]=value;page.edited(patch)})
            page.pickColor(page.colorField,page.colorField === "manualText" ? SettingsStore.manualText : SettingsStore.manualPanel)
        }
        onStatusChanged:if(status === Loader.Error) page.pathNote="Color picker unavailable."
    }

    Loader {
        id: dialogLoader
        active: false
        source: "ImageDialog.qml"
        onStatusChanged: {
            if (status === Loader.Error) {
                page.dialogReason = "Image picker unavailable. You can enter an image path."
                active = false
            }
            if (status === Loader.Ready && item) { item.outputName=page.pickerOutput;item.open() }
        }
    }

    Loader {
        id: folderDialog
        active: false
        source: "FolderPicker.qml"
        onStatusChanged: {
            if (status === Loader.Error) {
                page.folderReason = "Folder picker unavailable. Add images individually."
                active = false
            } else if (status === Loader.Ready && item) {
                item.folderSelected.connect(page.scanFolder)
                item.open()
            }
        }
    }

    Loader {
        id: folderScanner
        active: false
        source: "FolderScanner.qml"
        onStatusChanged: {
            if (status === Loader.Error) {
                page.folderReason = "This folder could not be read."
                active = false
            } else if (status === Loader.Ready && item) {
                item.scanFinished.connect(page.folderScanned)
                item.scan(page.selectedFolder)
            }
        }
    }

    Column {
        id: column
        width: page.width
        spacing: Theme.settingsSpacing

        Text {
            width: parent.width
            text: "Wallpaper"
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSize + 4
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Choose a shared background or a different image for each screen. Images are limited to " + Wallpaper.MAX_EDGE + " pixels wide."
            color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        Image {
            width: 320
            height: 180
            asynchronous: true
            fillMode: SettingsStore.wallpaperFit === "contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            sourceSize.width: 640
            source: page.previewFailed ? page.packagedSource : page.sourceUrl(page.previewChoice)
            onStatusChanged: {
                if (status === Image.Error && !page.previewFailed)
                    page.previewFailed = true
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: page.previewChoice.source === "file" ? page.previewChoice.path : "Packaged crimson image"
            color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
            elide: Text.ElideRight
        }

        SettingsToggle {
            controlId: "wallpaperEnabled"
            visible: page.shows("wallpaperEnabled")
            marked: page.marked("wallpaperEnabled")
            label: "Draw wallpaper"
            checked: SettingsStore.wallpaperEnabled
            onToggled: function (next) { SettingsStore.setWallpaperEnabled(next) }
        }

        SettingsRow {
            controlId: "wallpaperFit"
            visible: page.shows("wallpaperFit")
            marked: page.marked("wallpaperFit")
            width: parent.width
            label: "Fit"

            Row {
                spacing: Theme.settingsSpacing

                FlatButton {
                    label: "Cover"
                    emphasized: SettingsStore.wallpaperFit !== "contain"
                    onActivated: SettingsStore.setWallpaperFit("cover")
                }

                FlatButton {
                    label: "Contain"
                    emphasized: SettingsStore.wallpaperFit === "contain"
                    onActivated: SettingsStore.setWallpaperFit("contain")
                }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.shows("wallpaperFit")
            text: SettingsStore.wallpaperFit === "contain" ? "Contain keeps the whole picture and fills the extra with black." : "Cover fills the output and crops the extra."
            color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        SettingsRow {
            controlId: "wallpaperPath"
            visible: page.shows("wallpaperPath")
            marked: page.marked("wallpaperPath")
            width: parent.width
            label: "Image"

            Flow {
                objectName:"wallpaperImageChoices"
                width:page.width
                spacing: Theme.settingsSpacing

                TextInput {
                    id: pathField
                    width: 220
                    height: Theme.controlHeight
                    text: SettingsStore.wallpaperPath
                    color: Theme.settingsText
                    font.family: Theme.settingsFontFamily
                    font.pixelSize: Theme.settingsFontSizeSmall
                    selectByMouse: true
                    activeFocusOnTab: true
                    clip: true
                    Accessible.name: "Wallpaper path"
                    onEditingFinished: {
                        var choice = Wallpaper.resolveSource(text)
                        page.pathNote = choice.reason
                        SettingsStore.setWallpaperPath(text)
                    }

                    Connections {
                        target: SettingsStore
                        function onWallpaperPathChanged() {
                            if (!pathField.activeFocus)
                                pathField.text = SettingsStore.wallpaperPath
                        }
                    }
                }

                FlatButton {
                    label: "Choose image"
                    onActivated: {
                        page.pickerOutput=""
                        if(dialogLoader.item) dialogLoader.item.outputName=""
                        page.dialogReason = ""
                        if (dialogLoader.status === Loader.Ready && dialogLoader.item)
                            dialogLoader.item.open()
                        else
                            dialogLoader.active = true
                    }
                }

                FlatButton {
                    label: "Packaged"
                    onActivated: {
                        page.pathNote = ""
                        pathField.text = ""
                        SettingsStore.setWallpaperPath("")
                    }
                }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.dialogReason !== ""
            text: page.dialogReason
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.pathNote !== ""
            text: page.pathNote
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.previewFailed
            text: "That image could not be decoded. The packaged image is used instead."
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        SettingsRow {
            controlId: "wallpaperOutput"
            visible: page.shows("wallpaperOutput")
            marked: page.marked("wallpaperOutput")
            width: parent.width
            label: "Per output"

            Text {
                width: 220
                wrapMode: Text.WordWrap
                text: "A path here replaces the shared image on that output. Clear it to use the shared image."
                color: Theme.settingsMuted
                font.family: Theme.settingsFontFamily
                font.pixelSize: Theme.settingsFontSizeSmall
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.shows("wallpaperOutput") && (!Quickshell.screens || Quickshell.screens.length === 0)
            text: "No outputs are connected."
            color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        Repeater {
            model: Quickshell.screens
            visible: page.shows("wallpaperOutput")

            delegate: Column {
                required property var modelData
                width: column.width
                spacing: Theme.settingsSpacing

                Image {
                    width: 160
                    height: 90
                    asynchronous: true
                    fillMode: SettingsStore.wallpaperFit === "contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                    sourceSize.width: 320
                    source: page.sourceUrl(Wallpaper.sourceForOutput(modelData.name, SettingsStore.wallpaperPath, SettingsStore.wallpaperOutputsJson))
                }

                SettingsRow {
                    width: parent.width
                    label: modelData.name ? modelData.name : "Output"

                    Row {
                        spacing:6
                        FlatButton {
                            label:"Choose image"
                            onActivated: {
                                page.pickerOutput=modelData.name
                                if(dialogLoader.item) {dialogLoader.item.outputName=modelData.name;dialogLoader.item.open()}
                                else dialogLoader.active=true
                            }
                        }
                        FlatButton {label:"Use shared";enabled:page.outputPath(modelData.name)!=="";onActivated:SettingsStore.setOutputWallpaper(modelData.name,"")}
                    }
                }
            }
        }

        SettingsToggle {
            controlId: "slideshow"
            visible: page.shows("slideshow")
            marked: page.marked("slideshow")
            label: "Slideshow"
            checked: SettingsStore.slideshow
            onToggled: function (next) { SettingsStore.setSlideshow(next) }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.shows("slideshow")
            text: "Choose a folder or add images. Shuffle avoids showing the same image twice in a row."
            color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        Row {
            visible: page.shows("slideshow")
            spacing: Theme.settingsSpacing

            FlatButton {
                label: "Choose folder"
                onActivated: {
                    page.folderReason = ""
                    if (folderDialog.status === Loader.Ready && folderDialog.item)
                        folderDialog.item.open()
                    else
                        folderDialog.active = true
                }
            }

            Text {
                width: 360
                elide: Text.ElideMiddle
                text: page.selectedFolder === "" ? "No folder selected" : page.selectedFolder
                color: Theme.settingsMuted
                font.family: Theme.settingsFontFamily
                font.pixelSize: Theme.settingsFontSizeSmall
            }
        }

        Text {
            visible: page.folderReason !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            text: page.folderReason
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        SettingsRow {
            visible: page.shows("slideshow")
            width: parent.width
            label: "Every"

            ChoiceBox {
                choices:[1,5,10,15,30,60,120].map(function(value){return {label:value<60 ? value+" minutes" : value/60+" hours",value:value}})
                customLabel:SettingsStore.intervalMinutes+" minutes"
                selectedValue:SettingsStore.intervalMinutes
                onChosen:function(value){SettingsStore.setIntervalMinutes(value)}
                Accessible.name:"Slideshow interval"
            }
        }

        SettingsRow {
            visible: page.shows("slideshow")
            width: parent.width
            label: "Order"

            Row {
                spacing: Theme.settingsSpacing

                FlatButton {
                    label: "In order"
                    emphasized: SettingsStore.slideshowOrder !== "shuffle"
                    onActivated: SettingsStore.setSlideshowOrder("sequential")
                }

                FlatButton {
                    label: "Shuffle"
                    emphasized: SettingsStore.slideshowOrder === "shuffle"
                    onActivated: SettingsStore.setSlideshowOrder("shuffle")
                }
            }
        }

        SettingsRow {
            visible: page.shows("slideshow")
            width: parent.width
            label: "Fade"

            ChoiceBox {
                choices:[0,150,300,500,1000].map(function(value){return {label:value===0 ? "None" : value+" ms",value:value}})
                customLabel:SettingsStore.transitionMs+" ms"
                selectedValue:SettingsStore.transitionMs
                onChosen:function(value){SettingsStore.setTransitionMs(value)}
                Accessible.name:"Wallpaper transition"
            }
        }

        SettingsRow {
            visible: page.shows("slideshow")
            width: parent.width
            label: "Add image"

            Row {
                spacing: Theme.settingsSpacing

                TextInput {
                    id: slideField
                    width: 220
                    height: Theme.controlHeight
                    color: Theme.settingsText
                    font.family: Theme.settingsFontFamily
                    font.pixelSize: Theme.settingsFontSizeSmall
                    selectByMouse: true
                    activeFocusOnTab: true
                    Accessible.name: "Slideshow image"
                    onEditingFinished: page.addSlide(text)
                }

                FlatButton {
                    label: "Add"
                    onActivated: page.addSlide(slideField.text)
                }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.shows("slideshow")
            text: WallpaperModel.slideError !== "" ? WallpaperModel.slideError : (WallpaperModel.slideCount + " images, " + WallpaperModel.unreadable + " skipped")
            color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        Repeater {
            model: Slideshow.parseList(SettingsStore.slidesJson)
            visible: page.shows("slideshow")

            delegate: SettingsRow {
                required property string modelData
                width: column.width
                label: modelData

                FlatButton {
                    label: "Remove"
                    onActivated: SettingsStore.removeSlide(modelData)
                }
            }
        }

        SettingsToggle {
            controlId: "automaticText"
            visible: page.shows("automaticText")
            marked: page.marked("automaticText")
            label: "Automatic text"
            checked: SettingsStore.automaticText
            onToggled: function (next) { page.edited({ automaticText: next }) }
        }

        SettingsToggle {
            visible: page.shows("automaticText")
            label: "Automatic fade"
            checked: SettingsStore.automaticGradient
            onToggled: function (next) { page.edited({ automaticGradient: next }) }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.shows("automaticText")
            text: Theme.contrastReason !== "" ? Theme.contrastReason : "Adjust bar text for your wallpaper. Manual colors are remembered when automatic mode is off."
            color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.shows("manualText") && Theme.contrastWarning !== ""
            text: Theme.contrastWarning
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        SettingsRow {
            controlId: "manualText"
            visible: page.shows("manualText")
            marked: page.marked("manualText")
            width: parent.width
            label: "Text"

            Row {
                spacing:8
                FlatButton {
                    label:SettingsStore.manualText || "Choose color"
                    onActivated:page.pickColor("manualText",SettingsStore.manualText)
                    Accessible.name:"Choose text color"
                }
                FlatButton { label:"Reset";enabled:SettingsStore.manualText !== "";onActivated:page.edited({manualText:""}) }
            }
        }

        SettingsRow {
            visible: page.shows("manualText")
            width: parent.width
            label: "Panel"

            Row {
                spacing:8
                FlatButton {
                    label:SettingsStore.manualPanel || "Choose color"
                    onActivated:page.pickColor("manualPanel",SettingsStore.manualPanel)
                    Accessible.name:"Choose panel color"
                }
                FlatButton { label:"Reset";enabled:SettingsStore.manualPanel !== "";onActivated:page.edited({manualPanel:""}) }
            }
        }
    }
}
