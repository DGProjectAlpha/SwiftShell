import QtQuick
import Quickshell
import "../components"
import "../services"
import "../logic/media.js" as Media
import "../themes"
Column {
    id:root
    spacing:Theme.settingsSpacing+2
    width:parent ? parent.width : 340
    readonly property var player:MediaService.player
    readonly property var controls:MediaService.controls
    property var gesturePlayer:null
    property string gestureTrack:""
    readonly property real displayedPosition:seek.dragging ? seek.draft*MediaService.duration : MediaService.position
    function diagnostics(){return {players:MediaService.players.length,playing:controls.playing,seek:controls.seek,position:MediaService.position,duration:MediaService.duration,artReady:art.status===Image.Ready,hasArt:controls.art!=="",manualSource:MediaService.selectedId!=="",dragging:seek.dragging}}
    function beginSeek(){gesturePlayer=player;gestureTrack=MediaService.trackKey}
    function commitSeek(fraction){MediaService.seek(gesturePlayer,gestureTrack,fraction);gesturePlayer=null;gestureTrack=""}
    Timer {
        interval:500;repeat:true
        running:root.visible && !!root.player && root.controls.playing && root.player.positionSupported===true
        onTriggered:MediaService.refreshPosition()
    }
    Row {
        width:parent.width
        Text {width:parent.width-indicator.width;text:"Now playing";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
        Row {
            id:indicator;width:26;height:14;spacing:3;visible:root.controls.playing
            Repeater {
                model:4
                delegate:Rectangle {
                    required property int index
                    width:3;height:5+index*2;radius:1.5;anchors.bottom:parent.bottom;color:Theme.settingsMuted
                    SequentialAnimation on height {
                        running:root.visible && root.controls.playing && !Theme.reducedMotion && Theme.motionHover>0
                        loops:Animation.Infinite
                        NumberAnimation {to:13;duration:420+index*80;easing.type:Easing.InOutSine}
                        NumberAnimation {to:4;duration:360+index*90;easing.type:Easing.InOutSine}
                    }
                }
            }
        }
    }
    ChoiceBox {
        objectName:"mediaSource";width:parent.width
        visible:MediaService.players.length>1 || MediaService.selectedId!==""
        choices:MediaService.sourceChoices;selectedValue:MediaService.selectedId
        Accessible.name:"Media source"
        onChosen:function(value){MediaService.selectSource(value)}
    }
    Text {
        visible:root.player===null;width:parent.width;wrapMode:Text.WordWrap;topPadding:6;bottomPadding:8
        text:"Play something in a media app or browser. Its controls will appear here."
        color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
    }
    Column {
        visible:root.player!==null;width:parent.width;spacing:Theme.settingsSpacing
        Row {
            width:parent.width;spacing:14
            Rectangle {
                width:84;height:84;color:Theme.settingsHover
                Image {
                    id:art;objectName:"mediaArtwork";anchors.fill:parent
                    source:root.controls.art;sourceSize:Qt.size(240,240);asynchronous:true
                    fillMode:Image.PreserveAspectCrop;visible:status===Image.Ready
                }
                Text {
                    anchors.centerIn:parent;visible:art.status!==Image.Ready
                    text:"♫";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:32
                }
            }
            Column {
                width:Math.max(1,parent.width-98);anchors.verticalCenter:parent.verticalCenter;spacing:5
                Text {
                    objectName:"mediaTitle";width:parent.width;text:root.player ? (root.player.trackTitle || "Untitled media") : ""
                    textFormat:Text.PlainText;maximumLineCount:2;wrapMode:Text.WordWrap;elide:Text.ElideRight
                    color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+2;font.weight:Font.Medium
                }
                Text {
                    objectName:"mediaArtist";width:parent.width;text:root.player ? (root.player.trackArtist || root.player.trackAlbum || "") : ""
                    textFormat:Text.PlainText;elide:Text.ElideRight;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
                    visible:text!==""
                }
                Text {
                    width:parent.width;text:root.player ? (root.player.identity || "Media player") : ""
                    textFormat:Text.PlainText;elide:Text.ElideRight;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
                }
            }
        }
        Column {
            width:parent.width;spacing:0
            visible:!!root.player && (root.player.positionSupported===true || MediaService.duration>0)
            MediaSeekBar {
                id:seek;objectName:"mediaSeek";width:parent.width
                enabled:root.controls.seek
                value:MediaService.duration>0 ? MediaService.position/MediaService.duration : 0
                valueDescription:Media.timeLabel(root.displayedPosition)+" of "+Media.timeLabel(MediaService.duration)
                onSeekStarted:root.beginSeek()
                onSeekCommitted:function(fraction){root.commitSeek(fraction)}
                onSeekCancelled:{root.gesturePlayer=null;root.gestureTrack=""}
            }
            Row {
                width:parent.width
                Text {width:parent.width/2;text:Media.timeLabel(root.displayedPosition);color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
                Text {width:parent.width/2;horizontalAlignment:Text.AlignRight;text:MediaService.duration>0 ? Media.timeLabel(MediaService.duration) : "Live";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
            }
        }
        Row {
            anchors.horizontalCenter:parent.horizontalCenter;spacing:18
            MediaTransportButton {objectName:"mediaPrevious";kind:"previous";label:"Previous track";enabled:root.controls.previous;onActivated:MediaService.act("previous")}
            MediaTransportButton {objectName:"mediaPlayPause";kind:root.controls.playing ? "pause" : "play";label:root.controls.playing ? "Pause playback" : "Play";emphasized:true;enabled:root.controls.toggle;onActivated:MediaService.act("toggle")}
            MediaTransportButton {objectName:"mediaNext";kind:"next";label:"Next track";enabled:root.controls.next;onActivated:MediaService.act("next")}
        }
        Text {visible:MediaService.error!=="";width:parent.width;wrapMode:Text.WordWrap;text:MediaService.error;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
    }
}
