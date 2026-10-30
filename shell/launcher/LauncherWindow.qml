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
    property bool dismissing: false

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
        queryMiss = typed && apps === 0;
        noApplications = !typed && apps === 0;
    }

    function move(delta) {
        LauncherModel.selected = Launcher.moveSelection(LauncherModel.selected, rows.length, delta);
        LauncherModel.confirmId = "";
    }

    function dismiss() {
        if (dismissing || !LauncherModel.open)
            return;
        dismissing = true;
        field.focus = false;
        focusGrab.active = false;
        LauncherModel.closeLauncher();
        dismissing = false;
    }

    function activateSelection() {
        if (rows.length === 0)
            return;
        const index = LauncherModel.selected >= 0 && LauncherModel.selected < rows.length ? LauncherModel.selected : 0;
        LauncherModel.activate(rows[index]);
    }

    function engage() {
        focusGrab.active = true;
        Qt.callLater(function () {
            if (!window.visible || !LauncherModel.open)
                return;
            field.forceActiveFocus();
        });
    }

    onVisibleChanged: {
        if (visible)
            engage();
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
    }

    Connections {
        target: SettingsStore
        function onPinnedIdsChanged() { window.rebuild(); }
    }

    Component.onCompleted: rebuild()
    Component.onDestruction: {
        field.focus = false;
        focusGrab.active = false;
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
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(Theme.barHeight + 24, parent.height * 0.18)
        width: Math.min(440, parent.width - 48)
        height: Math.min(column.implicitHeight + Theme.panelPadding * 2, Math.max(120, parent.height - anchors.topMargin - 24))
        radius: Theme.radius
        color: Theme.panelColor

        MouseArea {
            anchors.fill: parent
            onClicked: function () {}
        }

        Flickable {
            id: scroller
            anchors.fill: parent
            anchors.margins: Theme.panelPadding
            contentWidth: width
            contentHeight: column.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: column
                width: scroller.width
                spacing: 2

                TextInput {
                    id: field
                    width: parent.width
                    height: Theme.controlHeight
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
                    visible: window.queryMiss
                    text: "No matching applications"
                    color: Theme.panelMuted
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: window.noApplications
                    text: "No applications to show"
                    color: Theme.panelMuted
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }

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
                                source: Launcher.iconPath(modelData.icon)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: false
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: icon.status !== Image.Ready
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
