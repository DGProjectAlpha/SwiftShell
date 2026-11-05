import QtQuick
import QtTest
import Quickshell.Services.Mpris
import "../../shell/services" as Services
import "../../shell/popovers" as Popovers
TestCase {
    id:test
    name:"NativeMediaControls"
    when:windowShown
    visible:true;width:600;height:600
    property var oldPlayers:null
    property var section:null
    property var primary:null
    property var secondary:null
    property var saved:null
    Component {
        id:playerComponent
        QtObject {
            property string dbusName:"fixture.primary"
            property string identity:"Fixture player"
            property int uniqueId:1
            property string trackTitle:"<b>Literal title</b>"
            property string trackArtist:"Owned artist"
            property string trackAlbum:"Owned album"
            property string trackArtUrl:""
            property bool isPlaying:true
            property bool canTogglePlaying:true
            property bool canGoNext:true
            property bool canGoPrevious:true
            property bool canSeek:true
            property bool positionSupported:true
            property bool lengthSupported:true
            property real length:240
            property real position:30
            property int toggles:0
            property int skips:0
            property int backs:0
            property int seeks:0
            onPositionChanged:seeks++
            function togglePlaying(){toggles++;isPlaying=!isPlaying}
            function next(){skips++}
            function previous(){backs++}
        }
    }
    Component {id:sectionComponent;Popovers.MediaSection {width:360}}
    function init() {
        failOnWarning(/Binding loop|TypeError|ReferenceError/)
        saved=Services.SettingsStore.snapshot()
        oldPlayers=Mpris.players.values
        primary=playerComponent.createObject(test)
        secondary=playerComponent.createObject(test,{dbusName:"fixture.secondary",identity:"Second player",isPlaying:false})
        Mpris.players.values=[primary,secondary]
        Services.MediaService.selectedId=""
        section=sectionComponent.createObject(test)
        verify(section!==null)
        waitForRendering(section)
    }
    function cleanup() {
        section.destroy();section=null
        Mpris.players.values=oldPlayers
        Services.MediaService.selectedId=""
        primary.destroy();secondary.destroy()
        Services.SettingsStore.applyDocument(saved)
    }
    function test_auto_manual_selection_and_disappearing_player() {
        compare(Services.MediaService.player,primary)
        primary.isPlaying=false;secondary.isPlaying=true
        compare(Services.MediaService.player,secondary)
        verify(Services.MediaService.selectSource(primary.dbusName))
        compare(Services.MediaService.player,primary)
        Mpris.players.values=[secondary]
        compare(Services.MediaService.selectedId,"")
        compare(Services.MediaService.player,secondary)
    }
    function test_pointer_controls_and_plain_text_title() {
        compare(findChild(section,"mediaTitle").textFormat,Text.PlainText)
        verify(findChild(section,"mediaPlayPause").height>=44)
        verify(findChild(section,"mediaPrevious").height>=44)
        mouseClick(findChild(section,"mediaPlayPause"));compare(primary.toggles,1)
        mouseClick(findChild(section,"mediaNext"));compare(primary.skips,1)
        mouseClick(findChild(section,"mediaPrevious"));compare(primary.backs,1)
        primary.canGoNext=false
        verify(!findChild(section,"mediaNext").enabled)
    }
    function test_seek_drag_commits_once_on_release_in_seconds() {
        primary.isPlaying=false
        const seek=findChild(section,"mediaSeek")
        const initial=primary.seeks
        mousePress(seek,seek.width*.2,seek.height/2)
        mouseMove(seek,seek.width*.5,seek.height/2)
        compare(primary.seeks,initial)
        mouseRelease(seek,seek.width*.75,seek.height/2)
        compare(primary.seeks,initial+1)
        compare(primary.position,180)
    }
    function test_track_or_source_change_during_drag_never_seeks_new_track() {
        primary.isPlaying=false
        const seek=findChild(section,"mediaSeek"),initial=primary.seeks
        mousePress(seek,seek.width*.2,seek.height/2)
        primary.uniqueId++
        mouseRelease(seek,seek.width*.8,seek.height/2)
        compare(primary.seeks,initial)
        mousePress(seek,seek.width*.2,seek.height/2)
        Services.MediaService.selectSource(secondary.dbusName)
        mouseRelease(seek,seek.width*.8,seek.height/2)
        compare(secondary.seeks,0)
    }
    function test_cancel_keyboard_and_unsupported_seek() {
        primary.isPlaying=false
        const seek=findChild(section,"mediaSeek"),initial=primary.seeks
        mousePress(seek,seek.width*.2,seek.height/2)
        keyClick(Qt.Key_Escape)
        mouseRelease(seek,seek.width*.8,seek.height/2)
        compare(primary.seeks,initial)
        seek.forceActiveFocus();keyClick(Qt.Key_Right)
        compare(primary.position,36)
        primary.canSeek=false;verify(!seek.enabled)
        primary.canSeek=true;primary.lengthSupported=false;verify(!seek.enabled)
    }
    function test_owned_artwork_loads_and_missing_art_keeps_placeholder() {
        const art=findChild(section,"mediaArtwork")
        primary.trackArtUrl=Qt.resolvedUrl("../../assets/wallpapers/swiftshell-default-crimson.png").toString()
        tryCompare(art,"status",Image.Ready)
        primary.trackArtUrl=""
        tryCompare(art,"status",Image.Null)
        verify(!art.visible)
        Services.SettingsStore.setAppearance(Object.assign({},saved.appearance,{reducedMotion:true}))
        compare(section.controls.playing,true)
    }
}
