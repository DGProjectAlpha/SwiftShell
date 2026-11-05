#!/usr/bin/env python3
"""Fixed local screenshot/clipboard operations. Never log clipboard or image content."""
import argparse,json,os,re,shutil,subprocess,sys,signal
_active=set()
def interrupted(signum,frame):
    for process in tuple(_active):
        try:process.kill()
        except OSError:pass
    raise SystemExit(128+signum)
if __name__=="__main__":
    signal.signal(signal.SIGTERM,interrupted)
    signal.signal(signal.SIGINT,interrupted)
MAX_TEXT=4096
MAX_IMAGE=64*1024*1024

def capabilities():
    return {'ok':True,'clipboard':bool(shutil.which('wl-paste')),'screenshot':bool(shutil.which('grim') and shutil.which('wl-copy')),'region':bool(shutil.which('grim') and shutil.which('slurp') and shutil.which('wl-copy'))}

def bounded_output(argv,limit,timeout=5):
    with subprocess.Popen(argv,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL) as process:
        _active.add(process)
        # A stalled compositor must not leave a reader waiting forever.
        import threading
        guard=threading.Timer(timeout,process.kill);guard.daemon=True;guard.start()
        try:
            data=process.stdout.read(limit+1)
            if len(data)>limit:
                process.kill();process.wait();raise ValueError('Content exceeds the safe size limit.')
            if process.wait()!=0:raise ValueError('The desktop operation was cancelled or unavailable.')
            return data
        finally:
            guard.cancel();_active.discard(process)
            if process.poll() is None:process.kill();process.wait()

def clipboard():
    types=bounded_output(['wl-paste','--list-types'],8192).decode('utf-8','replace').lower().splitlines()
    if any('password' in item or 'secret' in item or 'sensitive' in item for item in types):return {'ok':True,'skip':True}
    if not any(item.startswith('text/plain') or item in ['utf8_string','text','string'] for item in types):return {'ok':True,'skip':True}
    try:text=bounded_output(['wl-paste','--no-newline','--type','text/plain'],MAX_TEXT*4).decode('utf-8')
    except (ValueError,UnicodeError):return {'ok':True,'skip':True}
    if len(text)>MAX_TEXT or '\x00' in text or not text.strip():return {'ok':True,'skip':True}
    return {'ok':True,'text':text}

def capture(mode,output=''):
    argv=['grim']
    if mode=='region':
        try:geometry=bounded_output(['slurp'],256,120).decode('ascii').strip()
        except ValueError:return {'ok':False,'cancelled':True,'message':'Screenshot cancelled.'}
        if not re.fullmatch(r'-?\d+,-?\d+ [1-9]\d*x[1-9]\d*',geometry):raise ValueError('Screen selection was cancelled.')
        argv+=['-g',geometry]
    elif mode=='output':
        from displayctl import ipc
        names={item['name'] for item in json.loads(ipc('j/monitors'))}
        if output not in names:raise ValueError('That display is no longer connected.')
        argv+=['-o',output]
    else:raise ValueError('Unknown screenshot mode.')
    image=bounded_output(argv+['-'],MAX_IMAGE,20)
    if not image.startswith(b'\x89PNG\r\n\x1a\n'):raise ValueError('The screenshot could not be captured.')
    subprocess.run(['wl-copy','--type','image/png'],input=image,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True,timeout=10)
    return {'ok':True,'message':'Screenshot copied to clipboard.'}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['capabilities','clipboard','region','output']);parser.add_argument('output',nargs='?',default='');args=parser.parse_args()
    try:
        result=capabilities() if args.action=='capabilities' else clipboard() if args.action=='clipboard' else capture(args.action,args.output)
    except (OSError,ValueError,subprocess.SubprocessError):
        # Compositor/command output may contain private data; never echo it.
        result={'ok':False,'message':'The desktop operation was cancelled or unavailable.'}
    print(json.dumps(result,ensure_ascii=False))
if __name__=='__main__':main()
