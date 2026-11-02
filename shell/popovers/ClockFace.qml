import QtQuick
import "../themes"

Item {
    id: root
    property date date: new Date()
    property bool showSeconds: true
    implicitWidth: 184
    implicitHeight: 184
    Accessible.role: Accessible.StaticText
    Accessible.name: Qt.formatTime(date, "hh:mm:ss")

    Repeater {
        model: 60
        delegate: Item {
            required property int index
            anchors.fill: parent
            rotation: index * 6
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 6
                width: index % 5 === 0 ? 2 : 1
                height: index % 5 === 0 ? 9 : 4
                radius: 1
                color: index % 5 === 0 ? Theme.settingsText : Theme.settingsMuted
                opacity: index % 5 === 0 ? .8 : .45
            }
        }
    }
    Repeater {
        model: [{ label: "12", x: .5, y: .16 }, { label: "3", x: .84, y: .5 },
            { label: "6", x: .5, y: .84 }, { label: "9", x: .16, y: .5 }]
        delegate: Text {
            required property var modelData
            x: root.width * modelData.x - width / 2
            y: root.height * modelData.y - height / 2
            text: modelData.label
            color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }
    }
    Item {
        anchors.fill: parent
        rotation: root.date.getHours() % 12 * 30 + root.date.getMinutes() * .5
        Rectangle { width: 4; height: root.height * .25; radius: 2; color: Theme.settingsText; anchors.horizontalCenter: parent.horizontalCenter; y: root.height / 2 - height }
    }
    Item {
        anchors.fill: parent
        rotation: root.date.getMinutes() * 6 + root.date.getSeconds() * .1
        Rectangle { width: 3; height: root.height * .34; radius: 1.5; color: Theme.settingsText; anchors.horizontalCenter: parent.horizontalCenter; y: root.height / 2 - height }
    }
    Item {
        anchors.fill: parent
        visible: root.showSeconds
        rotation: root.date.getSeconds() * 6
        Rectangle { width: 1; height: root.height * .4; color: Theme.settingsMuted; anchors.horizontalCenter: parent.horizontalCenter; y: root.height / 2 - height }
    }
    Rectangle { anchors.centerIn: parent; width: 7; height: 7; radius: 3.5; color: Theme.settingsText }
}
