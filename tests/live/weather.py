#!/usr/bin/env python3
"""Native weather transport/persistence/UI using synthetic locations and owned pixels."""
import argparse,copy,importlib.util,json,os,shutil,subprocess,tempfile,time
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.add_argument('--offscreen',action='store_true');parser.add_argument('--api',action='store_true');args=parser.parse_args()
ROOT=Path(__file__).parents[2]
spec=importlib.util.spec_from_file_location('weatherfixtures',ROOT/'tests/test_weatherctl.py');fixtures=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixtures)
if args.api:
 with tempfile.TemporaryDirectory(prefix='swiftshell-weather-public-api-') as cache:
  previous=os.environ.get('XDG_CACHE_HOME');os.environ['XDG_CACHE_HOME']=cache
  try:
   results=fixtures.weather.geocode('Berlin, Germany');assert results['locations']
   public=fixtures.weather.forecast({'location':fixtures.PLACE,'units':'metric','force':True})
   assert public['ok'] and len(public['data']['days'])==7 and len(public['data']['hours'])==24
   assert fixtures.weather.forecast({'location':fixtures.PLACE,'units':'metric'})['cached']
   print('PASS public Berlin geocoding/forecast API and temporary-cache readback; no user-location lookup',flush=True)
  finally:
   if previous is None:os.environ.pop('XDG_CACHE_HOME',None)
   else:os.environ['XDG_CACHE_HOME']=previous
def wait(predicate):
 for _ in range(180):
  try:
   value=predicate()
   if value:return value
  except (subprocess.CalledProcessError,ValueError,KeyError):pass
  time.sleep(.05)
 raise AssertionError('Owned weather fixture did not settle: '+json.dumps(state()))
with tempfile.TemporaryDirectory(prefix='swiftshell-weather-native-') as temporary:
 folder=Path(temporary);shell=folder/'shell';shutil.copytree(ROOT/'shell',shell)
 registry=shell/'services/qmldir'
 if 'singleton WeatherService ' not in registry.read_text():registry.write_text(registry.read_text()+'\nsingleton WeatherService 1.0 WeatherService.qml\n')
 config=folder/'config/swiftshell';config.mkdir(parents=True);shutil.copy2(ROOT/'shell/config/defaults.json',config/'settings.json')
 payload=fixtures.weather.normalize(fixtures.fixture(),fixtures.AIR,fixtures.PLACE,'metric',fixtures.NOW);payload['fetchedAt']=int(time.time()*1000)
 (folder/'forecast.json').write_text(json.dumps(payload))
 # An isolated fixed transport verifies Process/stdin handling and persistence;
 # it never invokes an HTTP client, IP lookup, real location, or geocoder.
 (shell/'helpers/weatherctl.py').write_text('''import copy,json,os,sys,time
from pathlib import Path
folder=Path(os.environ["SWIFTSHELL_WEATHER_FIXTURE"])
request=json.loads(sys.stdin.readline(8193));action=request.get("action")
with (folder/"operations.log").open("a") as stream:stream.write(str(action)+"\\n")
place={"name":"Berlin, Germany","latitude":52.52,"longitude":13.405,"timezone":"Europe/Berlin"}
if action=="search":result={"ok":True,"locations":[place],"attribution":"Synthetic fixture search"}
elif action=="locate":result={"ok":True,"location":place}
elif action=="forecast":
 data=json.loads((folder/"forecast.json").read_text());data["fetchedAt"]=int(time.time()*1000)
 if request.get("units")=="imperial":
  data["units"]={"temperature":"°F","wind":"mph","precipitation":"in"}
  for key in ["temperature","feelsLike"]:data["current"][key]=data["current"][key]*9/5+32
  for day in data["days"]:
   day["low"]=day["low"]*9/5+32;day["high"]=day["high"]*9/5+32
 if (folder/"offline").exists():data["stale"]=True;data["fetchedAt"]-=7200000
 if (folder/"slow").exists():time.sleep(.4)
 result={"ok":True,"data":data,"message":"Offline · showing the saved forecast." if data["stale"] else ""}
else:result={"ok":False,"message":"Unsupported fixture request"}
print(json.dumps(result,separators=(",",":")))
''')
 qml=shell/'WeatherAudit.qml';qml.write_text('''//@ pragma UseQApplication
//@ pragma ShellId swiftshell-weather-native-audit
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "components"
import "popovers"
ShellRoot {
 id:root
 property var output:Quickshell.screens.find(function(s){return s.name==="HDMI-A-1"})
 Component.onCompleted:Quickshell.watchFiles=false
 PanelWindow {
  id:window;screen:root.output;visible:!Quickshell.env("SWIFTSHELL_WEATHER_OFFSCREEN") && !!root.output
  anchors {top:true;left:true} margins {top:50;left:100}
  implicitWidth:surface.implicitWidth;implicitHeight:surface.implicitHeight
  color:"transparent";surfaceFormat.opaque:false;exclusionMode:ExclusionMode.Ignore
  WlrLayershell.namespace:"swiftshell-weather-owned-audit"
  WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
  Item {
   id:captureRoot;anchors.fill:parent
   Canvas {anchors.fill:parent;onPaint:{const c=getContext("2d");for(let y=0;y<height;y+=12)for(let x=0;x<width;x+=12){c.fillStyle=(x+y)%24===0 ? "#777777" : "#303030";c.fillRect(x,y,12,12)}}}
   BackdropEffect {id:blur;targetWindow:window;surface:surface.blurSurface;cornerRadius:SettingsStore.radius;enabled:SettingsStore.panelBlur>0}
   PopoverSurface {id:surface;maximumHeight:680;WeatherPanel {id:panel;width:400}}
  }
 }
 IpcHandler {
  target:"audit"
  function state():string {return JSON.stringify({ready:SettingsStore.persistenceState==="ready",persistence:SettingsStore.persistenceState,persistenceMessage:SettingsStore.persistenceMessage,enabled:WeatherService.weatherEnabled,configured:WeatherService.configured,available:WeatherService.available,busy:WeatherService.busy,searchCount:WeatherService.searchResults.length,error:!!WeatherService.error,days:WeatherService.forecast ? WeatherService.forecast.days.length : 0,hours:WeatherService.forecast ? WeatherService.forecast.hours.length : 0,units:SettingsStore.weatherUnits,mode:SettingsStore.weatherLocationMode,stale:WeatherService.forecast ? WeatherService.forecast.stale : false,expanded:panel.expandedDay!=="",blur:blur.applied})}
  function search():bool{return WeatherService.search("Berlin, Germany")}
  function choose():bool{return WeatherService.choose(WeatherService.searchResults[0])}
  function refresh():bool{return WeatherService.refresh(true)}
  function disable():bool{return SettingsStore.setWeatherPreferences({enabled:false})}
  function units(value:string):bool{return SettingsStore.setWeatherPreferences({units:value})}
  function expand():void{panel.expandedDay=WeatherService.forecast.days[0].key;surface.scrollBy(400)}
  function theme(mode:string):void{SettingsStore.setAppearance(Object.assign({},SettingsStore.snapshot().appearance,{mode:mode}))}
  function capture(path:string):bool{return captureRoot.grabToImage(function(result){result.saveToFile(path)})}
 }
}
''')
 if args.offscreen:
  source=qml.read_text().replace('PanelWindow {','FloatingWindow {').replace('screen:root.output;','').replace('  anchors {top:true;left:true} margins {top:50;left:100}\n','').replace(';exclusionMode:ExclusionMode.Ignore','')
  source='\n'.join(line for line in source.splitlines() if 'WlrLayershell.' not in line)
  qml.write_text(source)
 env=dict(os.environ,QT_QPA_PLATFORMTHEME='generic',QT_NO_XDG_DESKTOP_PORTAL='1',NO_AT_BRIDGE='1',XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'),SWIFTSHELL_WEATHER_FIXTURE=str(folder))
 if args.offscreen:env.update(QT_QPA_PLATFORM='offscreen',SWIFTSHELL_WEATHER_OFFSCREEN='1')
 command=['qs','ipc','-p',str(qml),'call','audit']
 def call(*values):return subprocess.check_output(command+list(map(str,values)),env=env,text=True,stderr=subprocess.DEVNULL).strip()
 def state():return json.loads(call('state'))
 def operations():return (folder/'operations.log').read_text().splitlines() if (folder/'operations.log').exists() else []
 def capture(kind):
  if args.offscreen:return
  path=Path('/tmp')/('swiftshell-weather-'+kind+'.png');path.unlink(missing_ok=True)
  assert call('capture',str(path))=='true';wait(lambda:path.exists() and path.stat().st_size>0)
 for phase in ['configure','restart']:
  runtime=folder/(phase+'.log')
  with runtime.open('w') as log:
   process=subprocess.Popen(['qs','-p',str(qml)],env=env,stdout=log,stderr=subprocess.STDOUT)
   try:
    wait(lambda:state()['ready'])
    if phase=='configure':
     time.sleep(.15);assert operations()==[],'Disabled defaults must not start weather or IP requests'
     assert call('search')=='true';wait(lambda:state()['searchCount']==1 and not state()['busy']);assert operations()==['search']
     assert call('choose')=='true';wait(lambda:state()['ready'] and state()['available'] and not state()['busy']);assert state()['days']==7 and state()['hours']==24
     capture('current-dark');call('expand');wait(lambda:state()['expanded']);capture('expanded-dark');call('theme','light');time.sleep(.1);capture('expanded-light')
     assert call('units','imperial')=='true';wait(lambda:state()['ready'] and state()['available'] and state()['units']=='imperial' and not state()['busy'])
     saved=json.loads((config/'settings.json').read_text());assert saved['weather']['units']=='imperial' and saved['weather']['enabled']
    else:
     wait(lambda:state()['available'] and not state()['busy']);assert state()['units']=='imperial' and state()['days']==7
     (folder/'offline').touch();assert call('refresh')=='true';wait(lambda:state()['stale'] and not state()['busy']);capture('offline')
     (folder/'slow').touch();assert call('refresh')=='true';wait(lambda:state()['busy']);assert call('disable')=='true'
     wait(lambda:not state()['enabled'] and not state()['available'] and not state()['busy'] and state()['ready'])
     before=len(operations());time.sleep(.2);assert len(operations())==before
    assert 'locate' not in operations(),'This test never asks for actual or approximate user location'
   finally:
    process.terminate()
    try:process.wait(timeout=3)
    except subprocess.TimeoutExpired:process.kill();process.wait()
    shutil.copy2(runtime,Path('/tmp')/('swiftshell-weather-'+phase+'.log'))
    if (folder/'operations.log').exists():shutil.copy2(folder/'operations.log','/tmp/swiftshell-weather-operations.log')
   text=runtime.read_text();assert not any(token in text for token in ['TypeError','ReferenceError','Binding loop','Failed to load configuration']),'Native weather fixture had runtime errors'
 print('PASS native weather stdin transport, disabled/no-IP defaults, explicit synthetic city choice, full forecast, units save/restart, offline age and stale-result rejection'+('; headless validation' if args.offscreen else '; owned QML captures only'),flush=True)
