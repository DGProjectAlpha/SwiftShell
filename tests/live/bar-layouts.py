#!/usr/bin/env python3
"""Opt-in real per-display edge/scale/placement checks; restore only tested fields."""
import argparse,json,os,subprocess,time
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2]
command=['qs','ipc','-p',str(root/'shell'),'call','swiftshell']
def call(*args):return subprocess.check_output(command+list(args),text=True)
def state():return json.loads(call('diagnostics'))
def wait(predicate):
    for _ in range(150):
        if predicate():return
        time.sleep(.05)
    raise AssertionError('Bar layout did not settle')
def bar(output):return next(b for b in state()['barSurfaces'] if b['output']==output)
config=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'swiftshell/settings.json'
initial=state();settings=json.loads(config.read_text())['bar'];saved=json.loads(settings.get('layoutOutputsJson','{}'))
names=[b['output'] for b in initial['barSurfaces']]
base_height=settings['height']
try:
    call('launcher','close');call('overview','close')
    for output in names:
        for edge in ['bottom','left','right','top']:
            for other in names:call('barPanel',other,'close')
            scale=1.25 if edge in ['left','bottom'] else .9
            assert call('barLayout',output,edge,str(scale)).strip()=='true'
            wait(lambda:bar(output)['edge']==edge and abs(bar(output)['contentScale']-scale)<.001 and state()['settingsPersistence']=='ready')
            b=bar(output)
            if edge in ['top','bottom']:assert abs(b['height']-round(base_height*scale))<=1,b
            else:assert abs(b['width']-round(168*scale))<=1,b
            for other in names:
                if other!=output:
                    expected=next(item for item in initial['barSurfaces'] if item['output']==other)
                    assert bar(other)['edge']==expected['edge'] and bar(other)['contentScale']==expected['contentScale']
            call('barPanel',output,'notifications')
            wait(lambda:bar(output)['menu']['visible'])
            menu=bar(output)['menu'];assert menu['id']=='notifications'
            assert menu['width']>100 and menu['height']>50
            call('barPanel',output,'close')
            print('PASS native per-output',output,edge,'scale',scale,'and notification drawer',flush=True)
        # Restore before testing the next output, so independence comparisons stay exact.
        if output in saved:
            item=saved[output];call('barLayout',output,item['edge'],str(item['scale']))
        else:call('barLayoutInherit',output)
        wait(lambda:state()['settingsPersistence']=='ready')
finally:
    for output in names:
        call('barPanel',output,'close')
        if output in saved:
            item=saved[output];call('barLayout',output,item['edge'],str(item['scale']))
        else:call('barLayoutInherit',output)
    wait(lambda:state()['settingsPersistence']=='ready')
    current=json.loads(json.loads(config.read_text())['bar'].get('layoutOutputsJson','{}'))
    assert current==saved,'Original per-output layouts were not restored'
