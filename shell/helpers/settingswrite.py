#!/usr/bin/env python3
"""Atomic SwiftShell preferences writer; receives private preferences via stdin."""
import fcntl
import copy
import json
import os
from pathlib import Path
import tempfile


def merge_changes(base, desired, current):
    """Apply only this writer's changed leaves, retaining other writers' work."""
    if not all(isinstance(value, dict) for value in (base, desired, current)):
        return copy.deepcopy(desired)
    result=copy.deepcopy(current)
    for key in base.keys() | desired.keys():
        if key in base and key in desired and base[key]==desired[key]:
            continue
        if key not in desired:
            result.pop(key,None)
        elif isinstance(base.get(key),dict) and isinstance(desired[key],dict):
            result[key]=merge_changes(base[key],desired[key],result.get(key,{}))
        else:
            result[key]=copy.deepcopy(desired[key])
    return result


def save(document, base=None):
    if not isinstance(document, dict) or type(document.get('version')) is not int or document['version'] != 3:
        raise ValueError('Settings are not a supported document.')
    folder=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'swiftshell'
    folder.mkdir(parents=True,exist_ok=True,mode=0o700)
    path=folder/'settings.json'
    with (folder/'settings.lock').open('a+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        previous=None
        if path.exists():
            try:
                previous=json.loads(path.read_text())
                if not isinstance(previous,dict) or type(previous.get('version',1)) is not int or previous.get('version',1)>3:
                    raise ValueError()
            except (OSError,ValueError,TypeError):
                return {'ok':False,'protected':True,'message':'Settings changed to an invalid or unsupported file and were left unchanged.'}
        committed=merge_changes(base,document,previous) if isinstance(base,dict) and isinstance(previous,dict) else document
        committed['version']=3
        descriptor,temporary=tempfile.mkstemp(prefix='.settings-',suffix='.tmp',dir=folder)
        try:
            with os.fdopen(descriptor,'w') as stream:
                os.fchmod(stream.fileno(),0o600)
                json.dump(committed,stream,indent=2,ensure_ascii=False)
                stream.write('\n');stream.flush();os.fsync(stream.fileno())
            os.replace(temporary,path)
            directory=os.open(folder,os.O_DIRECTORY)
            try:os.fsync(directory)
            finally:os.close(directory)
        finally:
            Path(temporary).unlink(missing_ok=True)
    return {'ok':True,'document':committed}

if __name__=='__main__':
    import sys
    try:
        raw=sys.stdin.buffer.readline(4*1024*1024+1)
        if len(raw)>4*1024*1024:raise ValueError('Settings are too large to save safely.')
        request=json.loads(raw)
        result=save(request['document'],request.get('base')) if isinstance(request,dict) and 'document' in request else save(request)
    except Exception as error:
        result={'ok':False,'message':str(error) if isinstance(error,ValueError) else 'Settings could not be saved.'}
    print(json.dumps(result,separators=(',',':')))
