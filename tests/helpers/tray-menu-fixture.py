#!/usr/bin/env python3
"""Owned StatusNotifier/DBusMenu fixture; use only on a private test bus."""
import json
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
SNI='org.kde.StatusNotifierItem';MENU='com.canonical.dbusmenu';PROPS='org.freedesktop.DBus.Properties';AUDIT='org.swiftshell.TrayFixture'

class PortalSettings(dbus.service.Object):
    # Prevent unrelated portal services from auto-starting on this private bus.
    def __init__(self,bus):
        self.name=dbus.service.BusName('org.freedesktop.portal.Desktop',bus)
        super().__init__(bus,'/org/freedesktop/portal/desktop')
    @dbus.service.method('org.freedesktop.portal.Settings',in_signature='as',out_signature='a{sa{sv}}')
    def ReadAll(self,namespaces):return {'org.freedesktop.appearance':{'color-scheme':dbus.UInt32(1)}}
    @dbus.service.method('org.freedesktop.portal.Settings',in_signature='ss',out_signature='v')
    def Read(self,namespace,key):return dbus.UInt32(1)

class Watcher(dbus.service.Object):
    def __init__(self,bus):
        self.name=dbus.service.BusName('org.kde.StatusNotifierWatcher',bus)
        super().__init__(bus,'/StatusNotifierWatcher')
    @dbus.service.method(PROPS,in_signature='s',out_signature='a{sv}')
    def GetAll(self,interface):return {'RegisteredStatusNotifierItems':dbus.Array(['org.swiftshell.TrayFixture/StatusNotifierItem'],signature='s'),'IsStatusNotifierHostRegistered':True,'ProtocolVersion':dbus.Int32(0)}
    @dbus.service.method(PROPS,in_signature='ss',out_signature='v')
    def Get(self,interface,name):return self.GetAll(interface)[name]
    @dbus.service.method('org.kde.StatusNotifierWatcher',in_signature='s',out_signature='')
    def RegisterStatusNotifierHost(self,name):self.StatusNotifierHostRegistered()
    @dbus.service.method('org.kde.StatusNotifierWatcher',in_signature='s',out_signature='')
    def RegisterStatusNotifierItem(self,name):self.StatusNotifierItemRegistered(name)
    @dbus.service.signal('org.kde.StatusNotifierWatcher',signature='')
    def StatusNotifierHostRegistered(self):pass
    @dbus.service.signal('org.kde.StatusNotifierWatcher',signature='s')
    def StatusNotifierItemRegistered(self,name):pass

class Item(dbus.service.Object):
    def __init__(self,bus):
        self.name=dbus.service.BusName('org.swiftshell.TrayFixture',bus)
        super().__init__(bus,'/StatusNotifierItem')
    @dbus.service.method(PROPS,in_signature='s',out_signature='a{sv}')
    def GetAll(self,interface):
        pixels=dbus.Array([],signature='(iiay)')
        return {'Category':'ApplicationStatus','Id':'swiftshell-owned-tray','Title':'Owned tray fixture','Status':'Active','WindowId':dbus.Int32(0),
            'IconName':'application-x-executable','IconPixmap':pixels,'OverlayIconName':'','OverlayIconPixmap':pixels,'AttentionIconName':'','AttentionIconPixmap':pixels,'AttentionMovieName':'',
            'ToolTip':dbus.Struct(('',pixels,'Owned tray fixture','Synthetic actions only'),signature='sa(iiay)ss'),'ItemIsMenu':False,'Menu':dbus.ObjectPath('/Menu')}
    @dbus.service.method(PROPS,in_signature='ss',out_signature='v')
    def Get(self,interface,name):return self.GetAll(interface)[name]
    @dbus.service.method(SNI,in_signature='ii',out_signature='')
    def Activate(self,x,y):pass
    @dbus.service.method(SNI,in_signature='ii',out_signature='')
    def SecondaryActivate(self,x,y):pass
    @dbus.service.method(SNI,in_signature='ii',out_signature='')
    def ContextMenu(self,x,y):pass
    @dbus.service.method(SNI,in_signature='is',out_signature='')
    def Scroll(self,delta,orientation):pass

class Menu(dbus.service.Object):
    def __init__(self,bus):
        super().__init__(bus,'/Menu')
        self.events=[];self.opens=[];self.checked=True
    def properties(self,key):
        base={'enabled':True,'visible':True}
        data={0:{'label':'','children-display':'submenu'},1:{'label':'Open fixture'},2:{'label':'Disabled action','enabled':False},3:{'type':'separator'},
            4:{'label':'Checked option','toggle-type':'checkmark','toggle-state':dbus.Int32(1 if self.checked else 0)},
            5:{'label':'Selected radio','toggle-type':'radio','toggle-state':dbus.Int32(1)},6:{'label':'Submenu','children-display':'submenu'},
            7:{'label':'Nested fixture action'},8:{'label':'Another nested option','toggle-type':'checkmark','toggle-state':dbus.Int32(0)}}
        return dbus.Dictionary(dict(base,**data[key]),signature='sv')
    def children(self,key):return {0:[1,2,3,4,5,6],6:[7,8]}.get(key,[])
    def layout(self,key,depth):
        children=[self.layout(child,depth-1 if depth>0 else -1) for child in self.children(key)] if depth!=0 else []
        return dbus.Struct((dbus.Int32(key),self.properties(key),dbus.Array([dbus.Struct(child,signature='ia{sv}av',variant_level=1) for child in children],signature='v')),signature='ia{sv}av')
    @dbus.service.method(PROPS,in_signature='s',out_signature='a{sv}')
    def GetAll(self,interface):return {'Version':dbus.UInt32(4),'TextDirection':'ltr','Status':'normal','IconThemePath':dbus.Array([],signature='s')}
    @dbus.service.method(PROPS,in_signature='ss',out_signature='v')
    def Get(self,interface,name):return self.GetAll(interface)[name]
    @dbus.service.method(MENU,in_signature='iias',out_signature='u(ia{sv}av)')
    def GetLayout(self,parent,depth,names):return dbus.UInt32(1),self.layout(int(parent),int(depth))
    @dbus.service.method(MENU,in_signature='aias',out_signature='a(ia{sv})')
    def GetGroupProperties(self,ids,names):return [(key,self.properties(int(key))) for key in ids]
    @dbus.service.method(MENU,in_signature='is',out_signature='v')
    def GetProperty(self,key,name):return self.properties(int(key)).get(name,'')
    @dbus.service.method(MENU,in_signature='isvu',out_signature='')
    def Event(self,key,event,data,timestamp):
        self.events.append([int(key),str(event)])
        if int(key)==4 and str(event)=='clicked':
            self.checked=not self.checked;self.ItemsPropertiesUpdated([(dbus.Int32(4),{'toggle-state':dbus.Int32(1 if self.checked else 0)})],[])
    @dbus.service.method(MENU,in_signature='a(isvu)',out_signature='ai')
    def EventGroup(self,events):
        for event in events:self.Event(*event)
        return []
    @dbus.service.method(MENU,in_signature='i',out_signature='b')
    def AboutToShow(self,key):self.opens.append(int(key));return False
    @dbus.service.method(MENU,in_signature='ai',out_signature='aiai')
    def AboutToShowGroup(self,ids):self.opens.extend(map(int,ids));return [],[]
    @dbus.service.signal(MENU,signature='a(ia{sv})a(ias)')
    def ItemsPropertiesUpdated(self,updated,removed):pass
    @dbus.service.signal(MENU,signature='ui')
    def LayoutUpdated(self,revision,parent):pass
    @dbus.service.method(AUDIT,in_signature='',out_signature='s')
    def State(self):return json.dumps({'events':self.events,'opens':self.opens,'checked':self.checked})

DBusGMainLoop(set_as_default=True)
bus=dbus.SessionBus();portal=PortalSettings(bus);watcher=Watcher(bus);item=Item(bus);menu=Menu(bus)
GLib.MainLoop().run()
