import QtQuick

// Update roles in place; a fresh IPC array must not destroy live controls.
ListModel {
    id: root
    // Older Qt otherwise infers object roles as nested lists on insertion.
    dynamicRoles: true
    property var entries: []
    property string keyRole: "key"
    property string fallbackKeyRole: "id"
    property var snapshots: ({})

    function reconcile() {
        const rows=entries || []
        const next=Object.create(null)
        const keys=[]
        for (let i=0;i<rows.length;i++) {
            const row=rows[i]
            const value=row !== null && typeof row === "object"
                ? (row[keyRole] !== undefined ? row[keyRole] : row[fallbackKeyRole]) : row
            if(value === undefined || value === null || keys.indexOf(String(value))>=0) continue
            const key=String(value)
            const target=keys.length
            keys.push(key)
            let found=target
            while(found<count && get(found).identity !== key) found++
            if(found===count) insert(target,{identity:key,entry:row})
            else if(found!==target) move(found,target,1)
            const serialized=JSON.stringify(row)
            if(snapshots[key] !== serialized) setProperty(target,"entry",row)
            next[key]=serialized
        }
        if(count>keys.length) remove(keys.length,count-keys.length)
        snapshots=next
    }
    onEntriesChanged: reconcile()
    Component.onCompleted: reconcile()
}
