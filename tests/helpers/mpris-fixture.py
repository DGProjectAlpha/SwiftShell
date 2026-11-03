#!/usr/bin/env python3
"""Synthetic private-bus MPRIS test player. No audio or user media is accessed."""
import argparse,json
import dbus,dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
ROOT='org.mpris.MediaPlayer2';PLAYER=ROOT+'.Player';PROPS='org.freedesktop.DBus.Properties';AUDIT='org.swiftshell.MediaFixture'
class Player(dbus.service.Object):
    def __init__(self,bus,suffix,art):
        self.name=dbus.service.BusName(ROOT+'.'+suffix,bus)
        super().__init__(bus,'/org/mpris/MediaPlayer2')
        self.identity='Fixture '+suffix;self.art=art;self.provided_art=art;self.playing=suffix=='Primary';self.position=30_000_000
        self.seekable=True;self.track=1;self.calls=[]
    def metadata(self):
        return dbus.Dictionary({'mpris:trackid':dbus.ObjectPath('/org/swiftshell/track/'+str(self.track)),'mpris:length':dbus.Int64(240_000_000),'mpris:artUrl':self.art,'xesam:title':'Owned fixture track','xesam:artist':dbus.Array(['SwiftShell Fixture'],signature='s'),'xesam:album':'Synthetic Album'},signature='sv')
    def props(self,interface):
        if interface==ROOT:return {'CanQuit':False,'CanRaise':False,'HasTrackList':False,'Identity':self.identity,'DesktopEntry':'swiftshell-fixture','SupportedUriSchemes':dbus.Array([],signature='s'),'SupportedMimeTypes':dbus.Array([],signature='s')}
        if interface==PLAYER:return {'PlaybackStatus':'Playing' if self.playing else 'Paused','LoopStatus':'None','Rate':dbus.Double(1),'Shuffle':False,'Metadata':self.metadata(),'Volume':dbus.Double(.5),'Position':dbus.Int64(self.position),'MinimumRate':dbus.Double(1),'MaximumRate':dbus.Double(1),'CanGoNext':True,'CanGoPrevious':True,'CanPlay':True,'CanPause':True,'CanSeek':self.seekable,'CanControl':True}
        return {}
    @dbus.service.method(PROPS,in_signature='s',out_signature='a{sv}')
    def GetAll(self,interface):return self.props(interface)
    @dbus.service.method(PROPS,in_signature='ss',out_signature='v')
    def Get(self,interface,name):return self.props(interface)[name]
    @dbus.service.method(PROPS,in_signature='ssv',out_signature='')
    def Set(self,interface,name,value):
        if interface==PLAYER and name=='Volume':self.calls.append(['volume',float(value)])
    @dbus.service.signal(PROPS,signature='sa{sv}as')
    def PropertiesChanged(self,interface,changed,invalidated):pass
    @dbus.service.signal(PLAYER,signature='x')
    def Seeked(self,position):pass
    @dbus.service.method(PLAYER,in_signature='',out_signature='')
    def PlayPause(self):
        self.calls.append(['toggle']);self.playing=not self.playing;self.PropertiesChanged(PLAYER,{'PlaybackStatus':'Playing' if self.playing else 'Paused'},[])
    @dbus.service.method(PLAYER,in_signature='',out_signature='')
    def Play(self):self.calls.append(['play']);self.playing=True;self.PropertiesChanged(PLAYER,{'PlaybackStatus':'Playing'},[])
    @dbus.service.method(PLAYER,in_signature='',out_signature='')
    def Pause(self):self.calls.append(['pause']);self.playing=False;self.PropertiesChanged(PLAYER,{'PlaybackStatus':'Paused'},[])
    @dbus.service.method(PLAYER,in_signature='',out_signature='')
    def Next(self):self.calls.append(['next'])
    @dbus.service.method(PLAYER,in_signature='',out_signature='')
    def Previous(self):self.calls.append(['previous'])
    @dbus.service.method(PLAYER,in_signature='x',out_signature='')
    def Seek(self,offset):self.calls.append(['relative',int(offset)]);self.position+=int(offset);self.Seeked(dbus.Int64(self.position))
    @dbus.service.method(PLAYER,in_signature='ox',out_signature='')
    def SetPosition(self,track,position):
        self.calls.append(['seek',str(track),int(position)])
        if str(track)=='/org/swiftshell/track/'+str(self.track) and self.seekable:self.position=int(position);self.Seeked(dbus.Int64(self.position))
    @dbus.service.method(AUDIT,in_signature='',out_signature='s')
    def State(self):return json.dumps({'calls':self.calls,'position':self.position,'playing':self.playing,'seekable':self.seekable,'track':self.track})
    @dbus.service.method(AUDIT,in_signature='s',out_signature='')
    def Change(self,mode):
        if mode=='no-seek':self.seekable=False;self.PropertiesChanged(PLAYER,{'CanSeek':False},[])
        elif mode=='seek':self.seekable=True;self.PropertiesChanged(PLAYER,{'CanSeek':True},[])
        elif mode=='track':self.track+=1;self.position=0;self.PropertiesChanged(PLAYER,{'Metadata':self.metadata()},[]);self.Seeked(dbus.Int64(0))
        elif mode=='no-art':self.art='';self.PropertiesChanged(PLAYER,{'Metadata':self.metadata()},[])
        elif mode=='art':self.art=self.provided_art;self.PropertiesChanged(PLAYER,{'Metadata':self.metadata()},[])
        elif mode=='playing':self.playing=True;self.PropertiesChanged(PLAYER,{'PlaybackStatus':'Playing'},[])
        elif mode=='paused':self.playing=False;self.PropertiesChanged(PLAYER,{'PlaybackStatus':'Paused'},[])
        elif mode=='clear':self.calls=[]
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--art',required=True);args=parser.parse_args()
    DBusGMainLoop(set_as_default=True);players=[Player(dbus.SessionBus(private=True),'Primary',args.art),Player(dbus.SessionBus(private=True),'Secondary',args.art)];GLib.MainLoop().run()
