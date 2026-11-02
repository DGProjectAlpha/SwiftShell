#!/usr/bin/env python3
"""Real hidden bar and asynchronous Qt image decoder; temporary preferences only."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from PySide6.QtGui import QImage,QColor
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2]
with tempfile.TemporaryDirectory(prefix='swiftshell-contrast-') as directory:
    folder=Path(directory);shutil.copytree(root/'shell',folder/'shell',symlinks=False)
    shutil.copy2(root/'tests/live/contrast.qml',folder/'shell/ContrastAudit.qml')
    config=folder/'config/swiftshell';config.mkdir(parents=True)
    shutil.copy2(root/'shell/config/defaults.json',config/'settings.json')
    image=QImage(600,400,QImage.Format_RGB32)
    env=dict(os.environ,XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'))
    for name,color,suffix in [('WHITE','white','jpg'),('BLACK','black','webp'),('MIXED','white','png')]:
        image.fill(QColor(color))
        if name=='MIXED':
            for x in range(300):
                for y in range(400):image.setPixelColor(x,y,QColor('black'))
        path=folder/(name+'.'+suffix);assert image.save(str(path));env['SWIFTSHELL_'+name]=str(path)
    result=subprocess.run(['qs','-p',str(folder/'shell/ContrastAudit.qml')],env=env,capture_output=True,text=True,timeout=15)
    output=result.stdout+result.stderr
    assert result.returncode==0 and 'Contrast audit: JPEG/WebP and composed bar surfaces passed' in output,output
print('PASS native hidden bar: JPEG/WebP, crop-aware asynchronous sampling, effective material contrast, and mixed-band readability fade')
