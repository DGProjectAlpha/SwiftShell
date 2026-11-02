#!/usr/bin/env python3
"""Atomic SwiftShell preferences writer; receives private preferences via stdin."""
import fcntl
import json
import os
from pathlib import Path
import tempfile


def save(document):
    if not isinstance(document, dict) or type(document.get('version')) is not int or document['version'] != 3:
        raise ValueError('Settings are not a supported document.')
    folder=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'swiftshell'
    folder.mkdir(parents=True,exist_ok=True,mode=0o700)
    path=folder/'settings.json'
    with (folder/'settings.lock').open('a+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        if path.exists():
            try:
                previous=json.loads(path.read_text())
                if not isinstance(previous,dict) or type(previous.get('version',1)) is not int or previous.get('version',1)>3:
                    raise ValueError()
            except (OSError,ValueError,TypeError):
                return {'ok':False,'protected':True,'message':'Settings changed to an invalid or unsupported file and were left unchanged.'}
        descriptor,temporary=tempfile.mkstemp(prefix='.settings-',suffix='.tmp',dir=folder)
        try:
            with os.fdopen(descriptor,'w') as stream:
                os.fchmod(stream.fileno(),0o600)
                json.dump(document,stream,indent=2,ensure_ascii=False)
                stream.write('\n');stream.flush();os.fsync(stream.fileno())
            os.replace(temporary,path)
            directory=os.open(folder,os.O_DIRECTORY)
            try:os.fsync(directory)
            finally:os.close(directory)
        finally:
            Path(temporary).unlink(missing_ok=True)
    return {'ok':True}

if __name__=='__main__':
    import sys
    try:
        raw=sys.stdin.buffer.readline(4*1024*1024+1)
        if len(raw)>4*1024*1024:raise ValueError('Settings are too large to save safely.')
        result=save(json.loads(raw))
    except Exception as error:
        result={'ok':False,'message':str(error) if isinstance(error,ValueError) else 'Settings could not be saved.'}
    print(json.dumps(result,separators=(',',':')))
