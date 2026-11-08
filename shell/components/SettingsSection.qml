import QtQuick
import "../logic/settingsNav.js" as Nav
import "../services"
import "../themes"

Column {
    id:section
    property string sectionId:""
    property string title:""
    property string description:""
    property string searchQuery:""
    property string searchKeywords:""
    property var controlIds:[]
    property bool defaultExpanded:true
    property bool adaptiveColumns:false
    readonly property int contentIndent:16
    property bool animationReady:false
    readonly property real disclosureHeight:viewport.height
    readonly property real expandedHeight:body.implicitHeight+18
    readonly property bool searching:searchQuery.trim()!==""
    readonly property bool matchesSearch:!searching || controlIds.some(function(id){return Nav.controlVisible(searchQuery,id)}) || (title+" "+description+" "+searchKeywords).toLowerCase().indexOf(searchQuery.trim().toLowerCase())>=0
    readonly property bool expanded:{
        let values={}
        try {values=JSON.parse(SettingsStore.settingsSectionsJson || "{}")}catch(error){}
        return Object.prototype.hasOwnProperty.call(values,sectionId) ? values[sectionId]===true : defaultExpanded
    }
    readonly property bool effectiveExpanded:searching || expanded
    default property alias content:body.data
    property alias contentItem:body
    width:parent ? parent.width : 560
    spacing:0
    visible:matchesSearch
    Component.onCompleted:animationReady=true
    function setExpanded(next) {
        if(searching)return
        if(!next)header.forceActiveFocus()
        SettingsStore.setSettingsSection(sectionId,next)
    }
    function reveal() {
        // Page highlight signals can run before this child query binding updates.
        // Search expansion must never rewrite the saved disclosure state.
        let node=parent
        while(node) {
            if((typeof node.query === "string" && node.query.trim()!=="") || (typeof node.filter === "string" && node.filter.trim()!==""))return
            node=node.parent
        }
        setExpanded(true)
    }
    Item {
        width:section.width
        height:Math.max(36,heading.implicitHeight+descriptionText.implicitHeight+12)
        MouseArea {
            id:header
            objectName:"section-"+section.sectionId
            anchors.fill:parent
            hoverEnabled:true
            activeFocusOnTab:true
            cursorShape:section.searching ? Qt.ArrowCursor : Qt.PointingHandCursor
            Accessible.role:Accessible.Button
            Accessible.name:section.title+(section.effectiveExpanded ? ", expanded" : ", collapsed")
            onClicked:section.setExpanded(!section.expanded)
            Keys.onPressed:function(event) {
                if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Space) {section.setExpanded(!section.expanded);event.accepted=true}
            }
            Rectangle {anchors.fill:parent;radius:Theme.controlRadius;color:header.containsMouse || header.activeFocus ? Theme.settingsHover : "transparent"}
        }
        Text {
            id:heading
            objectName:"sectionHeading"
            anchors.left:parent.left
            anchors.right:disclosure.left;anchors.rightMargin:10
            y:4
            text:section.title;textFormat:Text.PlainText
            color:Theme.settingsText
            font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+1;font.weight:Font.Bold
            elide:Text.ElideRight
        }
        Text {
            id:descriptionText
            anchors.left:heading.left;anchors.right:heading.right;anchors.top:heading.bottom;anchors.topMargin:3
            text:section.description;textFormat:Text.PlainText
            visible:text!==""
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
            wrapMode:Text.WordWrap
        }
        Text {
            id:disclosure
            anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter
            text:"›"
            rotation:section.effectiveExpanded ? 90 : 0
            Behavior on rotation {NumberAnimation {duration:section.effectiveExpanded ? Theme.motionOpen : Theme.motionClose;easing.type:Easing.OutCubic}}
            color:header.activeFocus ? Theme.controlAccent : Theme.settingsMuted
            font.pixelSize:18
        }
    }
    Item {
        id:viewport
        objectName:"sectionViewport"
        width:section.width
        height:section.effectiveExpanded ? section.expandedHeight : 0
        visible:section.effectiveExpanded || height>0
        enabled:section.effectiveExpanded
        clip:true
        Behavior on height {
            enabled:section.animationReady
            NumberAnimation {duration:section.effectiveExpanded ? Theme.motionOpen : Theme.motionClose;easing.type:Easing.OutCubic}
        }
        Flow {
            id:body
            x:section.contentIndent;y:8
            readonly property real cellWidth:section.adaptiveColumns && width>=900 ? (width-Theme.settingsSpacing)/2 : width
            width:Math.max(0,section.width-section.contentIndent)
            spacing:Theme.settingsSpacing
        }
    }
    Item {width:1;height:3}
}
