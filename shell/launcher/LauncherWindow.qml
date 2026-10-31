import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../logic/launcher.js" as Launcher
import "../services"
import "../themes"

PanelWindow {
    id: window

    color: Theme.transparent
    screen: LauncherModel.screen
    visible: LauncherModel.open && LauncherModel.screen !== null
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: screen ? screen.width : 1
    implicitHeight: screen ? screen.height : 1

    WlrLayershell.namespace: "swiftshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property var rows: []
    property bool queryMiss: false
    property bool noApplications: false
    property bool waitingForEntries: false
    property bool dismissing: false
    property real reveal: 0
    readonly property int statusCount: (queryMiss ? 1 : 0) + (noApplications ? 1 : 0) + (waitingForEntries ? 1 : 0) + (LauncherModel.notice !== "" ? 1 : 0)
    readonly property int contentPx: Launcher.spotlightContentHeight(rows.length, statusCount, {
        field: Theme.controlHeight,
        row: Theme.controlHeight,
        status: Theme.fontSizeSmall + 4,
        pad: Theme.panelPadding,
        gap: 2
    })
    readonly property var frame: Launcher.spotlightFrame(screen ? screen.width : 0, screen ? screen.height : 0, contentPx)

    function iconSourceFor(icon) {
        return Launcher.cachedIconSource(icon, function (name) {
            if (typeof Quickshell.iconPath !== "function")
                return "";
            return Quickshell.iconPath(name, true);
        });
    }

    function rebuild() {
        const next = Launcher.viewRows(
            LauncherModel.applications,
            LauncherModel.query,
            SettingsStore.pinnedIds,
            LauncherModel.recentIds
        );
        rows = next;
        if (LauncherModel.selected >= next.length)
            LauncherModel.selected = 0;
        let apps = 0;
        for (let i = 0; i < next.length; i++) {
            if (next[i].kind === "application")
                apps++;
        }
        const typed = LauncherModel.query.trim() !== "";
        const catalog = LauncherModel.applications ? LauncherModel.applications.length : 0;
        queryMiss = typed && apps === 0 && catalog > 0;
        waitingForEntries = catalog === 0 && LauncherModel.indexPending;
        noApplications = apps === 0 && catalog === 0 && !LauncherModel.indexPending;
        if (queryMiss)
            console.info("SwiftShell: launcher query matched 0 of", catalog);
    }

    function move(delta) {
        LauncherModel.selected = Launcher.moveSelection(LauncherModel.selected, rows.length, delta);
        LauncherModel.confirmId = "";
        LauncherModel.notice = "";
    }

    function revealRow(item) {
        if (!item)
            return;
        scroller.contentY = Launcher.revealOffset(scroller.contentY, scroller.height, item.y, item.height);
    }

    function releaseInput() {
        if (field)
            field.focus = false;
        if (focusGrab)
            focusGrab.active = false;
    }

    function focusField() {
        const plan = Launcher.inputPlan(LauncherModel.open, LauncherModel.screen !== null);
        focusGrab.active = plan.grab;
        if (!plan.focusField)
            return;
        Qt.callLater(function () {
            if (!window.visible || !LauncherModel.open)
                return;
            field.forceActiveFocus();
            if (!field.activeFocus) {
                Qt.callLater(function () {
                    if (window.visible && LauncherModel.open)
                        field.forceActiveFocus();
                });
            }
        });
    }

    function dismiss() {
        if (dismissing || !LauncherModel.open)
            return;
        dismissing = true;
        window.releaseInput();
        LauncherModel.closeLauncher();
        dismissing = false;
    }

    function activateSelection() {
        if (rows.length === 0)
            return;
        const index = LauncherModel.selected >= 0 && LauncherModel.selected < rows.length ? LauncherModel.selected : 0;
        LauncherModel.activate(rows[index]);
    }

    onVisibleChanged: {
        if (visible) {
            if (Theme.reducedMotion) {
                window.reveal = 1;
            } else {
                window.reveal = 0;
                Qt.callLater(function () {
                    if (window.visible)
                        window.reveal = 1;
                });
            }
            window.focusField();
            return;
        }
        window.reveal = 0;
        window.releaseInput();
        if (LauncherModel.open && LauncherModel.screen === null && !dismissing)
            window.dismiss();
    }

    Connections {
        target: LauncherModel
        function onQueryChanged() { window.rebuild(); }
        function onApplicationsChanged() { window.rebuild(); }
        function onRecentIdsChanged() { window.rebuild(); }
        function onOpenChanged() {
            if (LauncherModel.open)
                window.rebuild();
        }
        function onInputRequested() { window.focusField(); }
        function onIndexPendingChanged() { window.rebuild(); }
    }

    Connections {
        target: SettingsStore
        function onPinnedIdsChanged() { window.rebuild(); }
    }

    Component.onCompleted: rebuild()
    Component.onDestruction: window.releaseInput()

    Keys.onEscapePressed: function (event) {
        window.dismiss();
        event.accepted = true;
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [window]
        onCleared: window.dismiss()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: window.dismiss()
    }

    Rectangle {
        id: card
        z: 1
        x: window.frame.x
        y: window.frame.y
        width: window.frame.width
        height: window.frame.height
        radius: Theme.radius
        color: Theme.panelColor
        clip: true
        opacity: Theme.reducedMotion ? 1 : window.reveal

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motionOpen
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: function () {}
        }

        Column {
            id: chrome
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Theme.panelPadding
            anchors.rightMargin: Theme.panelPadding
            anchors.topMargin: Theme.panelPadding
            spacing: 2

            TextInput {
                id: field
                width: parent.width
                height: Theme.controlHeight
                focus: true
                activeFocusOnTab: false
                color: Theme.panelText
                selectionColor: Theme.panelHover
                selectedTextColor: Theme.panelText
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
                clip: true
                text: LauncherModel.query
                onTextChanged: {
                    if (text !== LauncherModel.query)
                        LauncherModel.setQuery(text);
                }

                Keys.onPressed: function (event) {
                    const alt = (event.modifiers & Qt.AltModifier) !== 0;
                    const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
                    if (event.key === Qt.Key_Escape) {
                        window.dismiss();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        window.activateSelection();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && shift)) {
                        window.move(-1);
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Tab) {
                        window.move(1);
                        event.accepted = true;
                        return;
                    }
                    if (alt && (event.key === Qt.Key_J || event.key === Qt.Key_K)) {
                        window.move(event.key === Qt.Key_J ? 1 : -1);
                        event.accepted = true;
                    }
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 2
                    visible: field.text === ""
                    text: "Search applications"
                    color: Theme.panelMuted
                    font.pixelSize: Theme.fontSize
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                width: parent.width
                height: Theme.fontSizeSmall + 4
                visible: window.queryMiss
                text: "No matching applications"
                color: Theme.panelMuted
                font.pixelSize: Theme.fontSizeSmall
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                height: Theme.fontSizeSmall + 4
                visible: window.noApplications
                text: "No applications to show"
                color: Theme.panelMuted
                font.pixelSize: Theme.fontSizeSmall
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                height: Theme.fontSizeSmall + 4
                visible: window.waitingForEntries
                text: "Reading installed applications"
                color: Theme.panelMuted
                font.pixelSize: Theme.fontSizeSmall
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                height: Theme.fontSizeSmall + 4
                visible: LauncherModel.notice !== ""
                text: LauncherModel.notice
                color: Theme.panelMuted
                font.pixelSize: Theme.fontSizeSmall
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }

        Flickable {
            id: scroller
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.top: chrome.bottom
            anchors.leftMargin: Theme.panelPadding
            anchors.rightMargin: Theme.panelPadding
            anchors.bottomMargin: Theme.panelPadding
            anchors.topMargin: window.rows.length > 0 ? 2 : 0
            contentWidth: width
            contentHeight: column.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: column
                width: scroller.width
                spacing: 2

                Repeater {
                    model: window.rows

                    delegate: MouseArea {
                        id: row
                        required property int index
                        required property var modelData
                        width: column.width
                        height: Theme.controlHeight
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.name

                        readonly property bool current: index === LauncherModel.selected
                        onCurrentChanged: {
                            if (current)
                                window.revealRow(row);
                        }
                        Component.onCompleted: {
                            if (current)
                                window.revealRow(row);
                        }
                        readonly property string label: {
                            if (modelData.kind === "power" && LauncherModel.confirmId === modelData.id)
                                return "Confirm " + modelData.name.toLowerCase();
                            return modelData.name;
                        }

                        onClicked: {
                            LauncherModel.selected = index;
                            window.activateSelection();
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.controlRadius
                            color: row.current || row.containsMouse ? Theme.panelHover : Theme.transparent
                        }

                        Rectangle {
                            visible: modelData.kind === "application"
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            radius: 2
                            color: Theme.transparent

                            Image {
                                id: icon
                                anchors.fill: parent
                                source: window.iconSourceFor(modelData.icon)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: true
                                mipmap: true
                                smooth: true
                                sourceSize.width: Math.round(16 * Math.max(1, Screen.devicePixelRatio))
                                sourceSize.height: Math.round(16 * Math.max(1, Screen.devicePixelRatio))
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: icon.source === "" || icon.status === Image.Error
                                text: Launcher.monogram(modelData.name)
                                color: Theme.panelText
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: modelData.kind === "application" ? 26 : 6
                            anchors.right: detail.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.label
                            color: Theme.panelText
                            font.pixelSize: Theme.fontSize
                            font.weight: row.current ? Font.Medium : Font.Normal
                            elide: Text.ElideRight
                        }

                        Text {
                            id: detail
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 88
                            horizontalAlignment: Text.AlignRight
                            text: modelData.section
                            color: Theme.panelMuted
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
