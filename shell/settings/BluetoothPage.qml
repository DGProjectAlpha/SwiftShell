import QtQuick
import "../logic/settingsNav.js" as Nav
import "../themes"
Item {
    id:page
    property string query:""
    property string highlightId:"bluetoothDevices"
    signal revealRequested(real y,real itemHeight)
    implicitWidth:560
    implicitHeight:loader.item ? loader.item.implicitHeight : statusText.implicitHeight
    height:implicitHeight
    function shows(id){return Nav.controlVisible(query,id)}
    function focusHighlight(){if(loader.item)loader.item.forceActiveFocus()}
    function moveHighlight(delta){revealRequested(0,height)}
    Loader {
        id:loader
        width:page.width
        source:"../popovers/BluetoothSection.qml"
        visible:status===Loader.Ready
    }
    Text {
        id:statusText
        width:page.width
        visible:loader.status===Loader.Error
        wrapMode:Text.WordWrap
        text:"Bluetooth is unavailable on this system."
        color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
    }
}
