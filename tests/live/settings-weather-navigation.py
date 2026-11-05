#!/usr/bin/env python3
"""Native weather Settings search/focus using private disabled-weather preferences."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--live',action='store_true',required=True)
    parser.parse_args()
    root=Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix='swiftshell-weather-navigation-') as temporary:
        folder=Path(temporary)
        shutil.copytree(root/'shell',folder/'shell')
        qml=(root/'tests/live/settings-ux.qml').read_text()
        qml=qml.replace('target:"audit"','''target:"audit"
        function focusWeather(id:string):void {const page=settings.item.activePage();page.highlightId=id;page.focusHighlight()}
        function weatherState():string {
            const page=settings.item ? settings.item.activePage() : null
            const names=["weatherEnabled","weatherLocationSearch","weatherUnits","weatherInterval"]
            const controls={}
            if(page)for(const name of names){const item=finder.findChild(page,name);if(item)controls[name]={focus:item.activeFocus,visible:item.visible}}
            return JSON.stringify({target:page ? page.highlightId : "",controls:controls,action:Services.WeatherService.action,enabled:Services.SettingsStore.weatherEnabled})
        }''')
        audit=folder/'shell/Audit.qml';audit.write_text(qml)
        config=folder/'config/swiftshell';config.mkdir(parents=True)
        shutil.copy2(root/'shell/config/defaults.json',config/'settings.json')
        env=dict(os.environ,XDG_CONFIG_HOME=str(config.parent),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'))
        command=['qs','ipc','-p',str(audit),'call','audit']
        def call(*values):return subprocess.check_output(command+list(values),env=env,text=True,stderr=subprocess.DEVNULL).strip()
        def state():return json.loads(call('status'))
        def weather():return json.loads(call('weatherState'))
        def wait(predicate):
            for _ in range(140):
                try:
                    if predicate():return
                except (subprocess.CalledProcessError,ValueError,KeyError):pass
                time.sleep(.05)
            raise AssertionError('Native weather navigation did not reach the expected state.')
        with (folder/'runtime.log').open('w') as log:
            process=subprocess.Popen(['qs','-p',str(audit)],env=env,stdout=log,stderr=log)
            try:
                wait(lambda:state()['persistence']=='ready')
                for output in ['HDMI-A-1','DP-1']:
                    call('open',output,'weather')
                    wait(lambda:state()['open'] and not state()['busy'] and state()['category']=='weather')
                    for query,target,name in [('fahrenheit','weatherUnits','weatherUnits'),('refresh','weatherRefresh','weatherInterval'),('postal','weatherLocation','weatherLocationSearch'),('enable weather','weatherEnabled','weatherEnabled')]:
                        call('search',query)
                        wait(lambda:weather()['target']==target)
                        call('focusWeather',target)
                        wait(lambda:weather()['controls'][name]['focus'])
                        assert weather()['action']=='' and not weather()['enabled'],'Navigation must not request weather or location.'
                    print('PASS native weather search and exact keyboard focus on',output,flush=True)
                    call('close');wait(lambda:not state()['open'])
                wait(lambda:state()['persistence']=='ready')
                saved=json.loads((config/'settings.json').read_text())
                assert saved['weather']['enabled'] is False
                call('quit');process.wait(timeout=4)
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:process.wait(timeout=3)
                    except subprocess.TimeoutExpired:process.kill();process.wait()
        text=(folder/'runtime.log').read_text()
        assert not any(error in text for error in ['ReferenceError','TypeError','Binding loop','Failed to load configuration']),text
        print('PASS disabled weather remains private; native runtime has no structural QML errors',flush=True)


if __name__=='__main__':
    main()
