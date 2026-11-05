#!/usr/bin/env python3
"""Actual Settings module-handle drag, atomic persistence and scoped restore."""
import argparse,json,os,shutil,subprocess,sys,tempfile,time
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2];sys.path.insert(0,str(root/'shell/helpers'))
from displayctl import ipc,logical_size,atomic
command=['qs','ipc','-p',str(root/'shell'),'call','swiftshell']
config=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'swiftshell/settings.json'
def call(*args):return subprocess.check_output(command+list(args),text=True)
def state():return json.loads(call('diagnostics'))
def page():return state()['window']['pageGeometry']
def window():return next(w for w in json.loads(ipc('j/clients')) if w.get('title')=='SwiftShell Settings' and w.get('class')=='org.quickshell')
def wait(predicate):
 for _ in range(120):
  if predicate():return
  time.sleep(.05)
 raise AssertionError('Native module order did not settle')
def overrides():return json.loads(json.loads(config.read_text())['bar'].get('layoutOutputsJson','{}'))
def dispatch(expression):assert ipc('eval hl.dispatch('+expression+')').strip()=='ok'
original=state();monitors=json.loads(ipc('j/monitors'))
focus=next(m['name'] for m in monitors if m['focused']);cursor=json.loads(ipc('j/cursorpos'));active=json.loads(ipc('j/activewindow')).get('address')
backup=Path('/tmp/swiftshell-bar-order-settings-backup.json');shutil.copy2(config,backup);backup.chmod(0o600)
prior=overrides();order=None;changed=False;selected_output=None
try:
    with tempfile.TemporaryDirectory(prefix='swiftshell-bar-order-') as directory:
        directory = Path(directory)
        protocol = root / 'tests/protocols/wlr-virtual-pointer-unstable-v1.xml'
        subprocess.run(['wayland-scanner', 'client-header', str(protocol), str(directory / 'pointer-client.h')], check=True)
        subprocess.run(['wayland-scanner', 'private-code', str(protocol), str(directory / 'pointer-protocol.c')], check=True)
        subprocess.run(['cc', '-Wall', '-Wextra', '-Werror', '-I' + str(directory),
                        str(root / 'tests/helpers/settings-pointer.c'), str(directory / 'pointer-protocol.c'),
                        '-o', str(directory / 'pointer'), '-lwayland-client'], check=True)
        protocol=root/'tests/protocols/virtual-keyboard-unstable-v1.xml'
        subprocess.run(['wayland-scanner','client-header',str(protocol),str(directory/'keyboard-client.h')],check=True)
        subprocess.run(['wayland-scanner','private-code',str(protocol),str(directory/'keyboard-protocol.c')],check=True)
        subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(directory),str(root/'tests/helpers/spotlight-keyboard.c'),str(directory/'keyboard-protocol.c'),'-lwayland-client','-lxkbcommon','-o',str(directory/'keyboard')],check=True)
        call('launcher','open');call('launcherQuery','module order')
        wait(lambda:any(row['kind']=='setting-result' for row in state()['spotlight']['card']['providers']))
        subprocess.run([str(directory/'keyboard'),'enter'],check=True)
        wait(lambda:state()['category']=='bar' and state()['window'] and state()['window']['pageGeometry'] and not state()['windowBusy'])
        time.sleep(.3)
        selected_output=page()['output']
        assert selected_output in {monitor['name'] for monitor in monitors},'Editor must default to a connected display'
        geometry=window();order=[row['id'] for row in page()['rows']]
        candidates=[row for row in page()['rows'] if 180<row['y']<geometry['size'][1]-60]
        assert len(candidates)>=2,'At least two handles must be visible in the real Settings viewport'
        first,last=candidates[-2:]
        index=order.index(first['id']);destination=order.index(last['id'])
        expected=order[:];expected.insert(destination,expected.pop(index))
        x=round(geometry['at'][0]+first['x']);y=round(geometry['at'][1]+first['y'])
        target_x=round(geometry['at'][0]+last['x']);target_y=round(geometry['at'][1]+last['y'])
        changed=True
        monitor = next(monitor for monitor in monitors
                       if monitor['x'] <= x < monitor['x'] + logical_size(monitor)[0]
                       and monitor['y'] <= y < monitor['y'] + logical_size(monitor)[1])
        width, height = map(round, logical_size(monitor))
        assert monitor['x'] <= target_x < monitor['x'] + width
        assert monitor['y'] <= target_y < monitor['y'] + height
        assert window()['address'] == geometry['address'] and window()['pid'] == geometry['pid']
        arguments = [str(directory / 'pointer'), str(x - monitor['x']), str(y - monitor['y']),
                     str(width), str(height), str(target_x - x), str(target_y - y), monitor['name'], str(x), str(y)]
        for _ in range(3):
            result = subprocess.run(arguments)
            if result.returncode == 0:
                break
            # Code 6 is a cursor mismatch before any press was sent. Retrying an
            # already-pressed gesture is deliberately forbidden.
            if result.returncode != 6:
                result.check_returncode()
            time.sleep(.2)
        result.check_returncode()
        wait(lambda:[row['id'] for row in page()['rows']]==expected)
        wait(lambda:state()['settingsPersistence']=='ready' and overrides().get(selected_output,{}).get('order')==expected)
        assert {k:v for k,v in overrides().items() if k!=selected_output}=={k:v for k,v in prior.items() if k!=selected_output}
        after=window();assert after['at']==geometry['at'] and after['size']==geometry['size']
        print('PASS native top-bar module drag: real handle drop, atomic disk readback, other-output overrides preserved and unchanged Settings geometry',flush=True)
finally:
    if changed:
        document=json.loads(config.read_text());current=json.loads(document['bar'].get('layoutOutputsJson','{}'))
        if selected_output in prior:current[selected_output]=prior[selected_output]
        else:current.pop(selected_output,None)
        document['bar']['layoutOutputsJson']=json.dumps(current,separators=(',',':'))
        atomic(config,document)
        wait(lambda:state()['settingsPersistence']=='ready' and overrides().get(selected_output)==prior.get(selected_output) and [row['id'] for row in page()['rows']]==order)
    call('launcher','close');call('settings',original['category']);wait(lambda:not state()['windowBusy'])
    if not original['settingsOpen']:call('window','close');wait(lambda:not state()['settingsOpen'])
    if active and any(w['address']==active for w in json.loads(ipc('j/clients'))):dispatch('hl.dsp.focus({window='+json.dumps('address:'+active)+'})')
    dispatch('hl.dsp.cursor.move({x='+str(cursor['x'])+',y='+str(cursor['y'])+'})')
    dispatch('hl.dsp.focus({monitor='+json.dumps(focus)+'})')
