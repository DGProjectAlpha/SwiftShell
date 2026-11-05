#!/usr/bin/env python3
"""Locate and transactionally edit loaded Lua shortcut source spans.

No configuration is evaluated while parsing. Only literal/constant-concatenated
chords and literal options tables are eligible. Live callbacks are preserved by
verified Hyprland 0.57 registry references; no full compositor reload is issued.
"""
from dataclasses import dataclass
import base64
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import time
import uuid
from displayctl import atomic, ipc

MODS={'SHIFT':1,'CTRL':4,'CONTROL':4,'ALT':8,'SUPER':64,'MOD4':64}
OPTIONS={'description','desc','repeating','locked','release','non_consuming','auto_consuming','transparent','ignore_mods','dont_inhibit','long_press','submap_universal','mouse','click','drag','allow_input_capture'}

@dataclass
class Token:
    kind:str
    text:str
    start:int
    end:int
    line:int


def lex(text):
    result=[];index=0;line=1
    while index<len(text):
        start=index;char=text[index]
        if char.isspace():
            line+=char=='\n';index+=1;continue
        if text.startswith('--',index):
            long=re.match(r'--\[(=*)\[',text[index:])
            if long:
                close=']'+long[1]+']';end=text.find(close,index+len(long[0]));end=len(text) if end<0 else end+len(close)
            else:
                end=text.find('\n',index);end=len(text) if end<0 else end
            line+=text[index:end].count('\n');index=end;continue
        if char in ('"',"'"):
            quote=char;index+=1
            while index<len(text):
                if text[index]=='\\':index+=2;continue
                if text[index]==quote:index+=1;break
                index+=1
            token=Token('string',text[start:index],start,index,line)
        else:
            long=re.match(r'\[(=*)\[',text[index:])
            if long:
                close=']'+long[1]+']';end=text.find(close,index+len(long[0]))
                index=len(text) if end<0 else end+len(close)
                token=Token('long',text[start:index],start,index,line)
            elif re.match(r'[A-Za-z_]',char):
                match=re.match(r'[A-Za-z_]\w*',text[index:]);index+=len(match[0]);token=Token('id',match[0],start,index,line)
            elif char.isdigit():
                match=re.match(r'\d+(?:\.\d+)?',text[index:]);index+=len(match[0]);token=Token('number',match[0],start,index,line)
            else:
                value='..' if text.startswith('..',index) else char;index+=len(value);token=Token('symbol',value,start,index,line)
        result.append(token);line+=text[start:index].count('\n')
    return result


def string_value(token):
    if token.kind=='long':
        match=re.match(r'\[(=*)\[',token.text);return token.text[len(match[0]):-len(match[1])-2].removeprefix('\n')
    if token.kind!='string':raise ValueError('Not a string literal')
    raw=token.text[1:-1];out=[];index=0
    escaped={'n':'\n','r':'\r','t':'\t','a':'\a','b':'\b','f':'\f','v':'\v','\\':'\\','"':'"',"'":"'"}
    while index<len(raw):
        if raw[index]!='\\':out.append(raw[index]);index+=1;continue
        index+=1
        if index>=len(raw):raise ValueError('Invalid Lua string')
        char=raw[index]
        if char in escaped:out.append(escaped[char]);index+=1
        elif char.isdigit():
            match=re.match(r'\d{1,3}',raw[index:]);out.append(chr(int(match[0])));index+=len(match[0])
        elif char=='x' and re.fullmatch(r'[0-9a-fA-F]{2}',raw[index+1:index+3]):out.append(chr(int(raw[index+1:index+3],16)));index+=3
        elif char=='z':
            index+=1
            while index<len(raw) and raw[index].isspace():index+=1
        elif char=='\n':out.append('\n');index+=1
        else:raise ValueError('Unsupported Lua string escape')
    return ''.join(out)


def constant(tokens,values):
    """Small non-executing evaluator for strings, variables and concatenation."""
    index=0
    def atom():
        nonlocal index
        if index>=len(tokens):raise ValueError('Incomplete constant')
        token=tokens[index];index+=1
        if token.text=='(':
            value=expression()
            if index>=len(tokens) or tokens[index].text!=')':raise ValueError('Unclosed constant')
            index+=1;return value
        if token.kind in ('string','long'):return string_value(token)
        if token.kind=='number':return int(token.text) if token.text.isdecimal() else float(token.text)
        if token.text in ('true','false'):return token.text=='true'
        if token.kind=='id' and token.text in values:return values[token.text]
        raise ValueError('Computed constant')
    def expression():
        nonlocal index
        value=atom()
        while index<len(tokens) and tokens[index].text=='..':
            index+=1;value=str(value)+str(atom())
        return value
    value=expression()
    if index!=len(tokens):raise ValueError('Computed expression')
    return value


def call_arguments(tokens,opening):
    depth=1;braces=0;brackets=0;blocks=[];start=opening+1;args=[]
    for index in range(start,len(tokens)):
        word=tokens[index].text
        if word=='(':depth+=1
        elif word==')':
            depth-=1
            if depth==0:
                args.append(tokens[start:index]);return args,index
        elif word=='{':braces+=1
        elif word=='}':braces-=1
        elif word=='[':brackets+=1
        elif word==']':brackets-=1
        elif word in ('function','if','do','repeat'):blocks.append(word)
        elif word in ('end','until') and blocks:blocks.pop()
        elif word==',' and depth==1 and braces==0 and brackets==0 and not blocks:
            args.append(tokens[start:index]);start=index+1
    raise ValueError('Unclosed binding call')


def literal_options(tokens,values):
    if not tokens:return {}
    if tokens[0].text!='{' or tokens[-1].text!='}':raise ValueError('Computed options')
    result={};index=1
    while index<len(tokens)-1:
        if tokens[index].text in (',',';'):index+=1;continue
        name=tokens[index].text
        if name not in OPTIONS or index+1>=len(tokens) or tokens[index+1].text!='=':raise ValueError('Unsupported binding option')
        index+=2;start=index;depth=0
        while index<len(tokens)-1:
            if tokens[index].text=='(':depth+=1
            if tokens[index].text==')':depth-=1
            if depth==0 and tokens[index].text in (',',';'):break
            index+=1
        value=constant(tokens[start:index],values)
        if name in ('description','desc'):
            if not isinstance(value,str):raise ValueError('Computed description')
        elif type(value) is not bool:raise ValueError('Computed binding flag')
        result[name]=value
    if any(result.get(name) for name in ('mouse','click','drag')):raise ValueError('Mouse bindings require a mouse recorder')
    return result


def chord(value):
    if not isinstance(value,str):raise ValueError('Computed shortcut')
    pieces=[part.strip() for part in value.split('+')]
    if not pieces or not pieces[-1]:raise ValueError('No key')
    modifiers=[];mask=0
    for item in pieces[:-1]:
        if item.upper() not in MODS:raise ValueError('Unsupported modifiers')
        bit=MODS[item.upper()];mask|=bit
        name={1:'shift',4:'ctrl',8:'alt',64:'super'}[bit]
        if name not in modifiers:modifiers.append(name)
    key=pieces[-1]
    if not re.fullmatch(r'(?:[A-Za-z0-9_]+|code:\d+)',key):raise ValueError('Unsupported key')
    return dict(modifiers=modifiers,key=key,mask=mask,text=value)


def config_root():
    return Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'hypr'


def source_paths(root=None):
    base=(root or config_root()).resolve();main=base/'hyprland.lua'
    if not main.is_file():return []
    visited=set();ordered=[]
    def walk(path):
        path=path.resolve()
        if path in visited or not path.is_relative_to(base) or not path.is_file() or path.stat().st_size>2*1024*1024:return
        visited.add(path)
        text=path.read_text();tokens=lex(text)
        for index,token in enumerate(tokens[:-2]):
            if token.text=='require' and tokens[index+1].text=='(' and tokens[index+2].kind in ('string','long'):
                module=string_value(tokens[index+2])
                if re.fullmatch(r'[A-Za-z_][A-Za-z0-9_.]*',module):walk(base/(module.replace('.','/')+'.lua'))
        ordered.append(path)
    walk(main);return ordered


def discover(root=None):
    base=(root or config_root()).resolve();globals={};bindings=[];assignments=[]
    for path in source_paths(base):
        text=path.read_text();tokens=lex(text);values=dict(globals);index=0;blocks=[];call_index=0
        while index<len(tokens):
            token=tokens[index]
            if token.text=='hl' and index+3<len(tokens) and [part.text for part in tokens[index:index+4]]==['hl','.','bind','(']:
                try:args,end=call_arguments(tokens,index+3)
                except ValueError:index+=1;continue
                call_index+=1
                if 'function' not in blocks and len(args)>=2 and args[0]:
                    try:
                        value=constant(args[0],values);binding=chord(value)
                        options=literal_options(args[2],values) if len(args)>2 else {}
                        digest=hashlib.sha256(text.encode()).hexdigest()
                        identifier=hashlib.sha256((str(path.relative_to(base))+':'+str(call_index)+':'+digest).encode()).hexdigest()[:32]
                        binding.update(id='source:'+identifier,path=path,relative=str(path.relative_to(base)),line=token.line,
                                       start=args[0][0].start,end=args[0][-1].end,options=options,description=options.get('description',options.get('desc','')),
                                       digest=digest,source=text,args=args,values=dict(values))
                        bindings.append(binding)
                    except ValueError:pass
                index=end+1;continue
            if token.text in ('function','if','do','repeat'):blocks.append(token.text)
            elif token.text in ('end','until') and blocks:blocks.pop()
            if not blocks:
                local=token.text=='local'
                name_index=index+1 if local else index
                if name_index+2<len(tokens) and tokens[name_index].kind=='id' and tokens[name_index+1].text=='=':
                    end=name_index+2
                    while end<len(tokens) and tokens[end].line==tokens[name_index].line and tokens[end].text!=';':end+=1
                    expression=tokens[name_index+2:end]
                    try:
                        value=constant(expression,values);name=tokens[name_index].text;values[name]=value
                        if not local:globals[name]=value
                        if expression:assignments.append(dict(name=name,value=value,path=path,start=expression[0].start,end=expression[-1].end,source=text,local=local))
                    except ValueError:pass
            index+=1
    return bindings,assignments


def matches(binding,live):
    if live.get('submap'):return False
    if int(live.get('modmask',0))!=binding['mask']:return False
    key=binding['key']
    same=int(live.get('keycode',0))==int(key[5:]) if key.startswith('code:') else str(live.get('key','')).casefold()==key.casefold()
    return same and (live.get('description') or '')==binding['description']


def linked(observed,root=None):
    bindings,_=discover(root);result={}
    for index,entry in enumerate(observed):
        candidates=[binding for binding in bindings if matches(binding,entry)]
        shared=sum(1 for other in observed if not other.get('submap') and other.get('modmask')==entry.get('modmask') and other.get('key')==entry.get('key') and other.get('keycode',0)==entry.get('keycode',0))
        if len(candidates)==1 and shared==1 and str(entry.get('arg','')).isdecimal():result[index]=candidates[0]
    return result


def lua(value):
    if value is True:return 'true'
    if value is False:return 'false'
    if isinstance(value,str):return json.dumps(value,ensure_ascii=False)
    if isinstance(value,dict):return '{'+','.join('['+lua(key)+']='+lua(item) for key,item in value.items())+'}'
    raise ValueError('Unsupported Lua value')


def state_root():
    return Path(os.environ.get('XDG_STATE_HOME',str(Path.home()/'.local/state')))/'swiftshell/source-shortcuts'


def digest(raw):return hashlib.sha256(raw).hexdigest()


def validate_lua(text):
    with tempfile.NamedTemporaryFile('w',suffix='.lua',encoding='utf-8') as temporary:
        temporary.write(text);temporary.flush()
        try:result=subprocess.run(['luac','-p',temporary.name],capture_output=True,timeout=3)
        except (OSError,subprocess.SubprocessError):raise ValueError('Lua validation is unavailable. No desktop configuration was changed.') from None
        if result.returncode:raise ValueError('The proposed desktop shortcut did not pass Lua validation. No change was kept.')


def write_source(path,raw,expected):
    path=Path(path)
    if digest(path.read_bytes())!=expected:raise ValueError('The desktop configuration changed. Refresh before editing it again.')
    mode=stat.S_IMODE(path.stat().st_mode)
    descriptor,name=tempfile.mkstemp(prefix='.swiftshell-edit-',suffix='.tmp',dir=path.parent)
    try:
        with os.fdopen(descriptor,'wb') as stream:
            os.fchmod(stream.fileno(),mode);stream.write(raw);stream.flush();os.fsync(stream.fileno())
        os.replace(name,path)
        descriptor=os.open(path.parent,os.O_DIRECTORY)
        try:os.fsync(descriptor)
        finally:os.close(descriptor)
    finally:
        Path(name).unlink(missing_ok=True)


def same_key(entry,key):
    if entry.get('submap') or int(entry.get('modmask',0))!=key['mask']:return False
    return int(entry.get('keycode',0))==int(key['key'][5:]) if key['key'].startswith('code:') else str(entry.get('key','')).casefold()==key['key'].casefold()


class Runtime:
    watchdog=True
    def binds(self):return json.loads(ipc('j/binds'))
    def evaluate(self,code):
        if ipc('eval '+code).strip()!='ok':raise ValueError('Hyprland did not accept the desktop shortcut change.')
    def autoreload_disabled(self):
        value=json.loads(ipc('j/getoption misc:disable_autoreload'))
        return bool(value.get('bool',value.get('int',False)))
    def autoreload(self,disabled):self.evaluate('hl.config({misc={disable_autoreload='+lua(disabled)+'}})')
    def probe(self,entry):
        version=json.loads(ipc('j/version')).get('version','')
        if not re.search(r'(?:^|v)0\.57(?:\.|$)',version):raise ValueError('Source shortcut editing is verified for Hyprland 0.57. No configuration was changed.')
        reference=str(entry.get('arg',''))
        if not reference.isdecimal():raise ValueError('This desktop callback cannot be preserved safely.')
        self.evaluate('assert(type(debug)=="table" and type(debug.getregistry)=="function" and type(debug.getregistry()['+reference+'])=="function","Desktop callback unavailable")')
    def replace(self,transaction,entry,binding,new_chord,command=None,global_terminal=None):
        reference=str(entry['arg']);options=lua(binding['options'])
        code='_G.__swiftshell_source_edits=_G.__swiftshell_source_edits or {}; '
        code+='local callback=debug.getregistry()['+reference+']; assert(type(callback)=="function","Desktop callback unavailable"); '
        code+='local tx={callback=callback,options='+options+',old='+lua(binding['text'])+',new='+lua(new_chord)+',oldTerminal=TERMINAL}; '
        code+='_G.__swiftshell_source_edits['+lua(transaction)+']=tx; '
        if global_terminal is not None:code+='TERMINAL='+lua(global_terminal)+'; '
        code+='local nextCallback='+('hl.dsp.exec_cmd('+lua(command)+')' if command is not None else 'callback')+'; '
        code+='local ok=pcall(function() hl.unbind(tx.old); tx.next=hl.bind(tx.new,nextCallback,tx.options); assert(tx.next,"Shortcut creation failed") end); '
        code+='if not ok then if tx.next then tx.next:remove() end; hl.bind(tx.old,tx.callback,tx.options); tx.restored=true; TERMINAL=tx.oldTerminal; error("Desktop shortcut was not replaced") end'
        self.evaluate(code)
    def recovery_context(self,saved):
        transaction=saved['id']
        try:
            self.evaluate('assert(_G.__swiftshell_source_edits and _G.__swiftshell_source_edits['+lua(transaction)+'],"Recovery context unavailable")')
            return
        except ValueError:pass
        current=[entry for entry in self.binds() if same_key(entry,chord(saved['new'])) and (entry.get('description') or '')==saved['old']['description']]
        if len(current)!=1:raise ValueError('The desktop shortcut changed after this edit. Recovery was left pending.')
        self.probe(current[0])
        callback='debug.getregistry()['+str(current[0]['arg'])+']'
        if saved.get('oldCommand') is not None:callback='hl.dsp.exec_cmd('+lua(saved['oldCommand'])+')'
        code='_G.__swiftshell_source_edits=_G.__swiftshell_source_edits or {}; '
        code+='local tx={callback='+callback+',options='+lua(saved['old']['options'])+',old='+lua(saved['old']['text'])+',new='+lua(saved['new'])+'}; '
        code+='tx.next={remove=function() hl.unbind('+lua(saved['new'])+') end}; '
        if 'oldTerminal' in saved:code+='tx.oldTerminal='+lua(saved['oldTerminal'])+'; '
        code+='_G.__swiftshell_source_edits['+lua(transaction)+']=tx'
        self.evaluate(code)
    def rollback(self,transaction,binding,old_missing=True):
        code='local tx=_G.__swiftshell_source_edits and _G.__swiftshell_source_edits['+lua(transaction)+']; '
        code+='assert(tx,"Shortcut recovery context unavailable"); if tx.restored then return end; if tx.next then tx.next:remove() end; '
        if old_missing:code+='hl.bind(tx.old,tx.callback,tx.options); '
        code+='tx.restored=true; TERMINAL=tx.oldTerminal; '
        self.evaluate(code)


def source_key(binding):return {key:binding[key] for key in ('key','mask','description','text','options')}


def transaction_files(changes):
    files=[]
    for path,after in changes.items():
        before=Path(path).read_bytes();validate_lua(after.decode())
        files.append(dict(path=str(path),before=base64.b64encode(before).decode(),beforeHash=digest(before),afterHash=digest(after),after=base64.b64encode(after).decode()))
    return files


_LOCK_DEPTH=0
@contextlib.contextmanager
def locked():
    global _LOCK_DEPTH
    if _LOCK_DEPTH:
        _LOCK_DEPTH+=1
        try:yield
        finally:_LOCK_DEPTH-=1
        return
    folder=state_root();folder.mkdir(parents=True,exist_ok=True,mode=0o700)
    with (folder/'edit.lock').open('a+') as stream:
        fcntl.flock(stream,fcntl.LOCK_EX);_LOCK_DEPTH=1
        try:yield
        finally:_LOCK_DEPTH=0


def serialized(function):
    def wrapped(*args,**kwargs):
        with locked():return function(*args,**kwargs)
    return wrapped


def stable_bindings(observed,excluded):
    return sorted(json.dumps(value,sort_keys=True) for index,value in enumerate(observed) if index!=excluded)


def read_journal(path):
    saved=json.loads(Path(path).read_text())
    if not isinstance(saved,dict) or saved.get('version')!=1 or saved.get('session')!=os.environ.get('HYPRLAND_INSTANCE_SIGNATURE',''):
        raise ValueError('This desktop shortcut recovery belongs to another session.')
    root=Path(saved.get('root','')).resolve()
    for file in saved.get('files',[]):
        if not Path(file.get('path','')).resolve().is_relative_to(root):raise ValueError('Desktop shortcut recovery data is invalid.')
    return saved


@serialized
def recover(path,runtime=None):
    runtime=runtime or Runtime();saved=read_journal(path)
    if saved.get('status') not in ('pending','error','committed'):return
    runtime.autoreload(True)
    try:
        # Verify every source before changing any of them or the callback.
        for file in saved['files']:
            current=digest(Path(file['path']).read_bytes())
            if current not in (file['beforeHash'],file['afterHash']):
                raise ValueError('The desktop configuration changed after this edit and was left unchanged.')
        old=saved['old'];entries=runtime.binds()
        original=[entry for entry in entries if same_key(entry,old) and (entry.get('description') or '')==old['description']]
        untouched=saved.get('phase','prepared')=='prepared' and len(original)==1 and str(original[0].get('arg',''))==saved.get('entryArg','')
        if not untouched and hasattr(runtime,'recovery_context'):runtime.recovery_context(saved)
        for file in saved['files']:
            target=Path(file['path']);current=digest(target.read_bytes())
            if current==file['afterHash'] and current!=file['beforeHash']:write_source(target,base64.b64decode(file['before']),current)
        if not untouched:
            present=bool(original)
            runtime.rollback(saved['id'],old,not present or old['text']==saved['new'])
        time.sleep(.08)
        saved['status']='rolled-back';atomic(Path(path),saved)
    finally:
        runtime.autoreload(saved['autoreloadDisabled'])


def start_guard(path):
    subprocess.Popen([sys.executable,str(Path(__file__).resolve()),'--guard',str(path),'--owner',str(os.getpid())],stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)


def transact(binding,new_chord,changes,entry,observed,index,root=None,runtime=None,command=None,global_terminal=None,old_command=None,old_terminal=None,expected_sources=None):
    runtime=runtime or Runtime();runtime.probe(entry)
    base=(root or config_root()).resolve()
    folder=state_root();folder.mkdir(parents=True,exist_ok=True,mode=0o700)
    transaction=uuid.uuid4().hex;path=folder/(transaction+'.json')
    expected_sources=expected_sources or {binding['path']:binding['digest']}
    for source,expected in expected_sources.items():
        if digest(Path(source).read_bytes())!=expected:raise ValueError('The desktop configuration changed. Refresh before editing it again.')
    files=transaction_files(changes)
    saved=dict(version=1,id=transaction,session=os.environ.get('HYPRLAND_INSTANCE_SIGNATURE',''),root=str(base),files=files,
               old=source_key(binding),new=new_chord,autoreloadDisabled=runtime.autoreload_disabled(),status='pending',phase='prepared',entryArg=str(entry.get('arg','')))
    if old_command is not None:saved['oldCommand']=old_command
    if old_terminal is not None:saved['oldTerminal']=old_terminal
    atomic(path,saved)
    if runtime.watchdog:start_guard(path)
    runtime.autoreload(True)
    try:
        runtime.replace(transaction,entry,binding,new_chord,command,global_terminal)
        saved["phase"]="runtime-applied";atomic(path,saved)
        after=runtime.binds();expected=chord(new_chord)
        candidates=[value for value in after if same_key(value,expected) and (value.get('description') or '')==binding['description']]
        if len(after)!=len(observed) or len(candidates)!=1:
            raise ValueError('The desktop shortcut did not match after applying it.')
        remaining=list(after);remaining.remove(candidates[0])
        if sorted(json.dumps(value,sort_keys=True) for value in remaining)!=stable_bindings(observed,index):
            raise ValueError('Another desktop shortcut changed during the edit. The source was left unchanged.')
        for file in files:write_source(Path(file['path']),base64.b64decode(file['after']),file['beforeHash'])
        time.sleep(.08)
        saved['phase']='source-written';atomic(path,saved)
    except Exception:
        recover(path,runtime)
        raise
    finally:
        runtime.autoreload(saved['autoreloadDisabled'])
    saved['status']='committed';atomic(path,saved)
    atomic(folder/'latest.json',{'version':1,'transaction':transaction})
    return transaction


@serialized
def apply(identifier,modifiers,key,root=None,runtime=None):
    import shortcutsctl
    runtime=runtime or Runtime();observed=runtime.binds();sources=linked(observed,root)
    selected=next(((index,binding) for index,binding in sources.items() if binding['id']==identifier),None)
    if selected is None:raise ValueError('This source shortcut changed or is not safely editable. Refresh and try again.')
    index,binding=selected
    next_key=shortcutsctl.normalize(modifiers,key)
    new=shortcutsctl.chord_text(next_key)
    if binding['mask']==shortcutsctl.mask(next_key) and binding['key'].casefold()==next_key['key'].casefold():return ''
    conflict=shortcutsctl.collision(next_key,[value for pos,value in enumerate(observed) if pos!=index])
    if conflict:raise ValueError('Already used by '+conflict+'. Choose another shortcut.')
    source=binding['source'];patched=source[:binding['start']]+lua(new)+source[binding['end']:]
    return transact(binding,new,{binding['path']:patched.encode()},observed[index],observed,index,root,runtime)


@serialized
def undo(runtime=None):
    latest=state_root()/'latest.json'
    if not latest.is_file():raise ValueError('No desktop shortcut edit is available to undo.')
    identifier=json.loads(latest.read_text()).get('transaction','')
    if not re.fullmatch(r'[a-f0-9]{32}',identifier):raise ValueError('Desktop shortcut recovery is invalid.')
    path=state_root()/(identifier+'.json');saved=read_journal(path)
    if saved.get('status')!='committed':raise ValueError('This desktop shortcut change has already been undone.')
    recover(path,runtime)


def terminal_binding(root=None):
    bindings,assignments=discover(root)
    variables=[item for item in assignments if item['name']=='TERMINAL' and not item['local'] and isinstance(item['value'],str)]
    if len(variables)!=1:return None
    variable=variables[0]
    raw=lex(variable['source'][variable['start']:variable['end']])
    if len(raw)!=1 or raw[0].kind not in ('string','long'):return None
    candidates=[]
    for binding in bindings:
        action=binding['args'][1]
        if len(action)<8 or [item.text for item in action[:6]]!=['hl','.','dsp','.','exec_cmd','(']:continue
        if not any(item.text=='TERMINAL' and item.kind=='id' for item in action[6:-1]):continue
        try:
            arguments,last=call_arguments(action,5)
            if last!=len(action)-1 or len(arguments)!=1:continue
            # A terminal launched with a task suffix (for example -e btop) is
            # a separate action, not the default-terminal launch binding.
            if not arguments[0] or arguments[0][-1].text!='TERMINAL' or sum(token.kind=='id' and token.text=='TERMINAL' for token in arguments[0])!=1:continue
            command=constant(arguments[0],binding['values'])
            if not isinstance(command,str):continue
            candidates.append((binding,arguments[0],command))
        except ValueError:continue
    if len(candidates)!=1:return None
    binding,expression,command=candidates[0]
    return dict(binding=binding,variable=variable,expression=expression,command=command)


@serialized
def sync_terminal(command,root=None,runtime=None):
    if not isinstance(command,str) or not command.strip() or len(command)>4096 or any(ord(char)<32 for char in command):
        raise ValueError('The selected terminal command is not supported.')
    matched=terminal_binding(root)
    if matched is None:return {'supported':False,'changed':False}
    if matched['variable']['value']==command:
        return dict(supported=True,changed=False,previousCommand=command)
    runtime=runtime or Runtime();observed=runtime.binds();sources=linked(observed,root)
    selected=next(((index,binding) for index,binding in sources.items() if binding['id']==matched['binding']['id']),None)
    if selected is None:raise ValueError('The desktop terminal shortcut could not be matched safely. Refresh and try again.')
    index,binding=selected;variable=matched['variable']
    values=dict(binding['values'],TERMINAL=command)
    next_command=constant(matched['expression'],values)
    source=variable['source'];patched=source[:variable['start']]+lua(command)+source[variable['end']:]
    transaction=transact(binding,binding['text'],{variable['path']:patched.encode()},observed[index],observed,index,root,runtime,next_command,command,matched['command'],variable['value'],{variable['path']:digest(variable['source'].encode())})
    return dict(supported=True,changed=True,transaction=transaction,previousCommand=variable['value'])


def guard(path,owner):
    while True:
        try:
            saved=read_journal(path)
            if saved.get('status')!='pending':return
            raw=Path('/proc/'+str(owner)+'/stat').read_text()
            alive=raw.rsplit(')',1)[1].strip().split()[0]!='Z'
        except FileNotFoundError:alive=False
        except (OSError,ValueError,KeyError):return
        if not alive:
            try:recover(path)
            except Exception:pass
            return
        time.sleep(.2)


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--guard');parser.add_argument('--owner',type=int,default=0)
    args=parser.parse_args()
    if args.guard:guard(Path(args.guard),args.owner)
