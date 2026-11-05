#!/usr/bin/env python3
"""Actual PipeWire writes to one owned silent node only; no desktop input/focus."""
import argparse,json,os,re,shutil,subprocess,tempfile,time,uuid
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
ROOT=Path(__file__).parents[2]
def dump():return json.loads(subprocess.check_output(['pw-dump'],text=True))
def wait(predicate):
 for _ in range(100):
  try:
   result=predicate()
   if result:return result
  except (subprocess.CalledProcessError,ValueError,KeyError):pass
  time.sleep(.05)
 raise AssertionError('Owned audio node state did not settle')
def default_volumes():return [subprocess.check_output(['wpctl','get-volume',role],text=True).strip() for role in ['@DEFAULT_AUDIO_SINK@','@DEFAULT_AUDIO_SOURCE@']]
with tempfile.TemporaryDirectory(prefix='swiftshell-audio-controls-') as temporary:
 folder=Path(temporary);shell=folder/'shell';shutil.copytree(ROOT/'shell',shell)
 registry=shell/'services/qmldir'
 if 'singleton AudioService ' not in registry.read_text():registry.write_text(registry.read_text()+'\nsingleton AudioService 1.0 AudioService.qml\n')
 qml=shell/'AudioAudit.qml';qml.write_text('''//@ pragma ShellId swiftshell-audio-owned-node-audit
import QtQuick
import Quickshell
import Quickshell.Io
import "services"
Scope {
 Component.onCompleted:Quickshell.watchFiles=false
 IpcHandler {
  target:"audit"
  function ready(id:string):bool{return AudioService.nodeReady(AudioService.nodeById(id))}
  function defaults():string{return JSON.stringify({output:AudioService.idFor("sink"),input:AudioService.idFor("source")})}
  function state(id:string):string{const node=AudioService.nodeById(id);return JSON.stringify(node && AudioService.nodeReady(node) ? {volume:node.audio.volume,muted:node.audio.muted,channels:node.audio.volumes} : {})}
  function volume(id:string,value:real):bool{return AudioService.setVolume(id,value)}
  function mute(id:string,value:bool):bool{return AudioService.setMuted(id,value)}
  function restore(id:string,value:string):bool {const node=AudioService.nodeById(id);if(!AudioService.nodeReady(node))return false;const saved=JSON.parse(value);node.audio.volumes=saved.channels;node.audio.muted=saved.muted;return true}
 }
}''')
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QPA_PLATFORMTHEME='generic',QT_NO_XDG_DESKTOP_PORTAL='1',XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'))
 log=(folder/'runtime.log').open('w');process=subprocess.Popen(['qs','-p',str(qml)],env=env,stdout=log,stderr=subprocess.STDOUT)
 creator=None;nodeid=None;original=None;original_defaults=None;volumes_before=default_volumes()
 command=['qs','ipc','-p',str(qml),'call','audit']
 def call(*args):return subprocess.check_output(command+list(map(str,args)),env=env,text=True,stderr=subprocess.DEVNULL).strip()
 def state():return json.loads(call('state',nodeid))
 try:
  wait(lambda:call('defaults'));original_defaults=json.loads(call('defaults'))
  name='swiftshell-owned-audio-test-'+uuid.uuid4().hex
  props={'factory.name':'support.null-audio-sink','node.name':name,'node.description':'SwiftShell owned test sink','media.class':'Audio/Sink','node.virtual':True,'object.linger':False,'priority.session':-10000,'audio.position':['FL','FR']}
  creator=subprocess.Popen(['pw-cli','-m','create-node','adapter',json.dumps(props)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  node=wait(lambda:next((row for row in dump() if row.get('info',{}).get('props',{}).get('node.name')==name),None));nodeid=str(node['id'])
  wait(lambda:call('ready',nodeid)=='true');original=state()
  assert original['channels'],'Native channel state was unavailable'
  assert call('volume',nodeid,.43)=='true'
  wait(lambda:abs(state()['volume']-.43)<.001)
  readback=subprocess.check_output(['wpctl','get-volume',nodeid],text=True);assert abs(float(re.search(r'Volume: ([0-9.]+)',readback).group(1))-.43)<.015
  assert call('mute',nodeid,'true')=='true';wait(lambda:state()['muted'])
  assert '[MUTED]' in subprocess.check_output(['wpctl','get-volume',nodeid],text=True)
  assert call('restore',nodeid,json.dumps(original))=='true';wait(lambda:state()==original)
  assert json.loads(call('defaults'))==original_defaults
  assert default_volumes()==volumes_before
  print('PASS native PipeWire bound-node volume/mute writes, independent wpctl readback and exact channel/mute restoration on an owned silent sink; actual defaults and volumes unchanged',flush=True)
 finally:
  if nodeid and original:
   try:call('restore',nodeid,json.dumps(original));wait(lambda:state()==original)
   except (subprocess.CalledProcessError,AssertionError):pass
  if creator:
   creator.terminate()
   try:creator.wait(timeout=3)
   except subprocess.TimeoutExpired:creator.kill();creator.wait()
   if nodeid:wait(lambda:all(str(row.get('id'))!=nodeid for row in dump()))
  process.terminate()
  try:process.wait(timeout=3)
  except subprocess.TimeoutExpired:process.kill();process.wait()
  log.close();shutil.copy2(folder/'runtime.log','/tmp/swiftshell-audio-controls.log')
 text=(folder/'runtime.log').read_text();assert not any(token in text for token in ['TypeError','ReferenceError','Binding loop','Failed to load configuration']),'Native audio fixture had runtime errors'
