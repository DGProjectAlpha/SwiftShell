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

    Loader {
        id: dialogLoader
        active: false
        source: "ImageDialog.qml"
        onStatusChanged: {
            if (status === Loader.Error) {
                page.dialogReason = "The native file dialog is not available in this Qt build. Enter a path instead."
                active = false
            }
            if (status === Loader.Ready && item)
                item.open()
        }
    }

    Column {
        id: column
        width: page.width
        spacing: Theme.panelSpacing

        Text {
            width: parent.width
            text: "Wallpaper"
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 4
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "One background is drawn on each output. An empty path uses the packaged crimson image. Turning this off leaves the background to another program. SwiftShell does not stop that program. Pictures are requested at most " + Wallpaper.MAX_EDGE + " pixels wide."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
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
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
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
                spacing: Theme.panelSpacing

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
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        SettingsRow {
            controlId: "wallpaperPath"
            visible: page.shows("wallpaperPath")
            marked: page.marked("wallpaperPath")
            width: parent.width
            label: "Image"

            Row {
                spacing: Theme.panelSpacing

                TextInput {
                    id: pathField
                    width: 220
                    height: Theme.controlHeight
                    text: SettingsStore.wallpaperPath
                    color: Theme.panelText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
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
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.pathNote !== ""
            text: page.pathNote
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.previewFailed
            text: "That image could not be decoded. The packaged image is used instead."
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
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
                color: Theme.panelMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.shows("wallpaperOutput") && (!Quickshell.screens || Quickshell.screens.length === 0)
            text: "No outputs are connected to this process. Each connected screen gets its own background when the shell is running."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Repeater {
            model: Quickshell.screens
            visible: page.shows("wallpaperOutput")

            delegate: Column {
                required property var modelData
                width: column.width
                spacing: Theme.panelSpacing

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

                    TextInput {
                        id: outputField
                        property string outputName: modelData && modelData.name ? modelData.name : ""
                        width: 220
                        height: Theme.controlHeight
                        color: Theme.panelText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        selectByMouse: true
                        activeFocusOnTab: true
                        clip: true
                        Accessible.name: "Wallpaper for " + (outputName !== "" ? outputName : "output")
                        Component.onCompleted: text = page.outputPath(outputName)
                        onEditingFinished: {
                            var choice = Wallpaper.resolveSource(text)
                            if (text !== "" && choice.reason !== "")
                                page.pathNote = choice.reason
                            SettingsStore.setOutputWallpaper(outputName, text)
                            if (!activeFocus)
                                text = page.outputPath(outputName)
                        }

                        Connections {
                            target: SettingsStore
                            function onWallpaperOutputsJsonChanged() {
                                if (!outputField.activeFocus)
                                    outputField.text = page.outputPath(outputField.outputName)
                            }
                        }
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
            text: "This Qt build cannot list a folder. Add png, jpeg, or webp files. Shuffle does not repeat the current image when another file is listed. The fade is at most one second, and it is instant while reduced motion is on."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        SettingsRow {
            visible: page.shows("slideshow")
            width: parent.width
            label: "Every"

            TextInput {
                width: 80
                height: Theme.controlHeight
                text: String(SettingsStore.intervalMinutes)
                color: Theme.panelText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                selectByMouse: true
                activeFocusOnTab: true
                Accessible.name: "Slideshow minutes"
                onEditingFinished: SettingsStore.setIntervalMinutes(parseInt(text, 10))
            }
        }

        SettingsRow {
            visible: page.shows("slideshow")
            width: parent.width
            label: "Order"

            Row {
                spacing: Theme.panelSpacing

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

            TextInput {
                width: 80
                height: Theme.controlHeight
                text: String(SettingsStore.transitionMs)
                color: Theme.panelText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                selectByMouse: true
                activeFocusOnTab: true
                Accessible.name: "Fade milliseconds"
                onEditingFinished: SettingsStore.setTransitionMs(parseInt(text, 10))
            }
        }

        SettingsRow {
            visible: page.shows("slideshow")
            width: parent.width
            label: "Add image"

            Row {
                spacing: Theme.panelSpacing

                TextInput {
                    id: slideField
                    width: 220
                    height: Theme.controlHeight
                    color: Theme.panelText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
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
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
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
            text: Theme.contrastReason !== "" ? Theme.contrastReason : "Automatic text reads the top of a png. Jpeg and webp still display. Manual colors stay stored when automatic is off."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.shows("manualText") && Theme.contrastWarning !== ""
            text: Theme.contrastWarning
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        SettingsRow {
            controlId: "manualText"
            visible: page.shows("manualText")
            marked: page.marked("manualText")
            width: parent.width
            label: "Text"

            TextInput {
                width: 120
                height: Theme.controlHeight
                text: SettingsStore.manualText
                color: Theme.panelText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                selectByMouse: true
                activeFocusOnTab: true
                Accessible.name: "Manual text color"
                onEditingFinished: page.edited({ manualText: text })
            }
        }

        SettingsRow {
            visible: page.shows("manualText")
            width: parent.width
            label: "Panel"

            TextInput {
                width: 120
                height: Theme.controlHeight
                text: SettingsStore.manualPanel
                color: Theme.panelText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                selectByMouse: true
                activeFocusOnTab: true
                Accessible.name: "Manual panel color"
                onEditingFinished: page.edited({ manualPanel: text })
            }
        }
    }
}
