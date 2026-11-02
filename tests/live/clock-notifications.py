#!/usr/bin/env python3
"""Actual Clock deadlines, bar activity and notification actions; restore tool state."""
import argparse,json,subprocess,time
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2];cmd=['qs','ipc','-p',str(root/'shell'),'call','swiftshell']
def call(*args):return subprocess.check_output(cmd+list(args),text=True).strip()
def state():return json.loads(call('diagnostics'))
def wait(predicate):
 for _ in range(140):
  if predicate():return
  time.sleep(.05)
 raise AssertionError('Clock notifications did not settle')
original=call('clockTool','snapshot','');before={e['id'] for e in state()['notifications']['entries']}
initial=state();output=initial['barSurfaces'][0]['output'];own=[]
def bar():return next(b for b in state()['barSurfaces'] if b['output']==output)
try:
 document=json.loads(original);now=time.time()*1000
 document['timer']={'status':'running','duration':2000,'remaining':2000,'deadline':now+2000}
 document['stopwatch']={'status':'ready','elapsed':0,'startedAt':0,'laps':[]}
 assert call('clockTool','restore',' '+json.dumps(document))=='ok'
 wait(lambda:bar()['clockTargets']['activity']['visible'])
 assert 'Timer ' in bar()['clockTargets']['activity']['text']
 wait(lambda:any(e['local'] and e['id'] not in before for e in state()['notifications']['entries']))
 entry=next(e for e in state()['notifications']['entries'] if e['local'] and e['id'] not in before);own.append(entry['id'])
 assert entry['actions']>0
 call('notification','snooze',str(entry['id']));wait(lambda:any(e['id']==entry['id'] and e['snoozed'] for e in state()['notifications']['entries']))
 call('notification','wake',str(entry['id']))
 call('notification','open',str(entry['id']))
 wait(lambda:any(b['menu']['visible'] and b['menu']['geometry']['details'] and b['menu']['geometry']['details'].get('tab')=='timer' for b in state()['barSurfaces']))
 print('PASS actual timer deadline, live bar count, notification snooze/wake and Open Clock action',flush=True)
 # Stopwatch pause is a real Clock service action, not a synthetic notification.
 document['timer']={'status':'ready','duration':60000,'remaining':60000,'deadline':0}
 document['stopwatch']={'status':'running','elapsed':0,'startedAt':time.time()*1000-2500,'laps':[]}
 assert call('clockTool','restore',' '+json.dumps(document))=='ok'
 assert call('clockTool','stopwatch','pause')=='ok'
 wait(lambda:any(e['local'] and e['id'] not in before and e['id'] not in own for e in state()['notifications']['entries']))
 entry=next(e for e in state()['notifications']['entries'] if e['local'] and e['id'] not in before and e['id'] not in own);own.append(entry['id'])
 call('notification','open',str(entry['id']))
 wait(lambda:any(b['menu']['visible'] and b['menu']['geometry']['details'] and b['menu']['geometry']['details'].get('tab')=='stopwatch' for b in state()['barSurfaces']))
 print('PASS actual stopwatch pause notification and action opens Stopwatch',flush=True)
finally:
 assert call('clockTool','restore',original)=='ok'
 for notification in own:call('notification','dismiss',str(notification))
 for b in state()['barSurfaces']:call('barPanel',b['output'],'close')
