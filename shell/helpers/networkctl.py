#!/usr/bin/env python3
"""NetworkManager adapter. Requests arrive on stdin; credentials never enter argv.

Only observed interfaces, profile UUIDs and AP BSSIDs may be acted upon. Commands
use fixed argument lists, no shell, and raw nmcli diagnostics are never returned.
"""
import json
import os
import re
import shutil
import subprocess
import sys

UUID = re.compile(r'^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
MAC = re.compile(r'^(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$')
DEVICE = re.compile(r'^[A-Za-z0-9][A-Za-z0-9_.:-]{0,63}$')
NETWORK_TYPES = {'ethernet','wifi'}


class NetworkError(ValueError):
    def __init__(self, message, code='operation-failed'):
        super().__init__(message)
        self.code = code



def fields(line):
    """Split nmcli's documented escaped terse output, including colon SSIDs."""
    result, word, escaped = [], [], False
    for char in line:
        if escaped:
            word.append(char); escaped = False
        elif char == '\\':
            escaped = True
        elif char == ':':
            result.append(''.join(word)); word = []
        else:
            word.append(char)
    if escaped:
        word.append('\\')
    result.append(''.join(word))
    return result


def nm(args, secret=None, timeout=8):
    command = ['nmcli','--colors','no','--escape','yes'] + args
    env = dict(os.environ,LC_ALL='C')
    try:
        result = subprocess.run(command,input=secret,capture_output=True,text=True,timeout=timeout,env=env)
    except (OSError,subprocess.SubprocessError):
        raise NetworkError('The network service did not respond. Try again.', 'timeout') from None
    if result.returncode:
        messages = {3:'The connection attempt timed out.',4:'The connection could not be activated. Check the password and signal, then try again.',
                    5:'The connection could not be disconnected.',8:'NetworkManager is not running.',10:'The selected network is no longer available.'}
        codes = {3:'timeout',4:'activation-failed',5:'disconnect-failed',7:'authentication-required',8:'unavailable',10:'not-found'}
        if result.returncode==7:
            message='This connection needs authentication. Try again with its password, or use an existing system authentication prompt.'
        else:
            message=messages.get(result.returncode,'NetworkManager could not complete this change. Check your permissions and try again.')
        raise NetworkError(message,codes.get(result.returncode,'permission-denied'))
    return result.stdout


def rows(args):
    return [fields(line) for line in nm(['--terse']+args).splitlines() if line]


def device_details(name):
    detail = {}
    lines = rows(['--fields','GENERAL.STATE,GENERAL.REASON,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS','device','show',name])
    for parts in lines:
        if len(parts)>=2:
            detail[parts[0]]=parts[1]
    addresses = [value for key,value in detail.items() if key.startswith('IP4.ADDRESS')]
    dns = [value for key,value in detail.items() if key.startswith('IP4.DNS')]
    return dict(addresses=addresses,gateway=detail.get('IP4.GATEWAY',''),dns=dns)


def snapshot():
    if not shutil.which('nmcli'):
        return dict(ok=True,available=False,reason='NetworkManager tools are not installed.',devices=[],networks=[],profiles=[],wifiEnabled=False,wifiHardware=False)
    state = fields(nm(['--get-values','STATE,CONNECTIVITY','general']).strip())
    radio = nm(['--get-values','WIFI-HW,WIFI','general']).strip().split(':')
    devices = []
    for row in rows(['--fields','DEVICE,TYPE,STATE,CONNECTION','device','status']):
        if len(row)!=4 or row[1] not in NETWORK_TYPES or not DEVICE.fullmatch(row[0]):
            continue
        name,kind,status,connection = row
        devices.append(dict(id=name,kind=kind,state=status,connection='' if connection=='--' else connection,
                            connected=status.startswith('connected'),available=status not in ('unavailable','unmanaged'),**device_details(name)))
    profiles = []
    for row in rows(['--fields','NAME,UUID,TYPE,DEVICE','connection','show']):
        if len(row)!=4 or not UUID.fullmatch(row[1]) or row[2] not in ('802-3-ethernet','802-11-wireless','wifi','ethernet'):
            continue
        profiles.append(dict(name=row[0],id=row[1],kind='wifi' if row[2] in ('802-11-wireless','wifi') else 'ethernet',device='' if row[3]=='--' else row[3]))
    networks = []
    if any(device['kind']=='wifi' and device['available'] for device in devices):
        for row in rows(['--fields','BSSID,SSID,SIGNAL,SECURITY,IN-USE,DEVICE','device','wifi','list','--rescan','no']):
            if len(row)!=6 or not MAC.fullmatch(row[0]) or not DEVICE.fullmatch(row[5]) or not row[1]:
                continue
            security='' if row[3]=='--' else row[3]
            enterprise='802.1X' in security or 'WPA-EAP' in security
            personal=not enterprise and ('WPA' in security or security=='')
            try: signal=max(0,min(100,int(row[2])))
            except ValueError: signal=0
            networks.append(dict(id=row[0],name=row[1],signal=signal,security=security,active=row[4]=='*',device=row[5],supported=personal))
    networks.sort(key=lambda row:(not row['active'],-row['signal'],row['name'].casefold()))
    return dict(ok=True,available=True,state=state[0] if state else '',connectivity=state[1] if len(state)>1 else '',
                devices=devices,profiles=profiles,networks=networks,wifiHardware=bool(radio and radio[0]=='enabled'),wifiEnabled=len(radio)>1 and radio[1]=='enabled')


def active_connections():
    active=[]
    for values in rows(['--fields','UUID,STATE,DEVICE','connection','show','--active']):
        if len(values)==3 and UUID.fullmatch(values[0]) and DEVICE.fullmatch(values[2]):
            active.append(dict(id=values[0],state=values[1].casefold(),device=values[2]))
    return active


def cancel_connection(payload,current):
    """Refuse established links; cancel an observed activation for this target."""
    identifier=payload.get('id','')
    name=payload.get('device','')
    if identifier and (not isinstance(identifier,str) or not UUID.fullmatch(identifier) and not MAC.fullmatch(identifier)):
        raise ValueError('The connection cancellation request is invalid.')
    if identifier and UUID.fullmatch(identifier):
        if not any(profile['id']==identifier for profile in current['profiles']):
            raise ValueError('The selected saved connection is no longer available.')
        candidates=[row for row in active_connections() if row['id']==identifier]
    else:
        if not any(device['id']==name for device in current['devices']):
            raise ValueError('The selected network device is no longer available.')
        candidates=[row for row in active_connections() if row['device']==name]
    candidate=next((row for row in candidates if row['state']=='activating'),None)
    if candidate is None:
        # A successful connection can race the Cancel button. Do not turn it off.
        return dict(current,cancelled=False,message='The connection is no longer waiting to connect. Its current status is shown below.')
    nm(['--wait','10','connection','down','uuid',candidate['id']],timeout=13)
    remaining=active_connections()
    if any(row['id']==candidate['id'] and row['device']==candidate['device'] for row in remaining):
        raise NetworkError('The cancellation could not be confirmed. Check the connection status and try again.','cancel-unconfirmed')
    return dict(snapshot(),cancelled=True,message='Connection cancelled.')


def request(payload):
    if not isinstance(payload,dict) or set(payload)-{'action','device','id','enabled','secret'}:
        raise ValueError('The network request is invalid.')
    action=payload.get('action','snapshot')
    current=snapshot()
    if action=='snapshot':return current
    if not current['available']:raise ValueError(current['reason'])
    if action=='cancel-connect':return cancel_connection(payload,current)
    if action=='wifi-radio':
        if type(payload.get('enabled')) is not bool:raise ValueError('Choose whether Wi-Fi is enabled.')
        nm(['radio','wifi','on' if payload['enabled'] else 'off'])
    elif action in ('device-connect','device-disconnect','scan','wifi-connect'):
        name=payload.get('device','')
        device=next((row for row in current['devices'] if row['id']==name),None)
        if device is None:raise ValueError('The selected network device is no longer available.')
        if action=='scan':
            if device['kind']!='wifi' or not device['available']:raise ValueError('Turn on an available Wi-Fi adapter before scanning.')
            nm(['--wait','15','device','wifi','rescan','ifname',name],timeout=18)
        elif action=='wifi-connect':
            target=next((row for row in current['networks'] if row['id']==payload.get('id') and row['device']==name),None)
            if target is None:raise ValueError('The selected network is no longer available. Refresh and try again.')
            if not target['supported']:raise ValueError('Use an existing connection profile for enterprise or WEP networks.')
            secret=payload.get('secret','')
            if not isinstance(secret,str) or len(secret)>64 or any(char in secret for char in '\r\n\x00'):
                raise ValueError('The Wi-Fi password is invalid.')
            if target['security'] and not (8<=len(secret)<=63 or len(secret)==64 and all(char in '0123456789abcdefABCDEF' for char in secret)):
                raise ValueError('Enter an 8–63 character Wi-Fi password or a 64-digit hexadecimal key.')
            # --ask reads the passphrase from stdin. It is never exposed in the
            # process list, saved by SwiftShell, or included in returned output.
            nm(['--ask','--wait','25','device','wifi','connect',target['id'],'ifname',name],secret=secret+'\n' if secret else '',timeout=30)
        else:
            nm(['--wait','20','device','connect' if action=='device-connect' else 'disconnect',name],timeout=24)
    elif action=='profile-connect':
        profile=next((row for row in current['profiles'] if row['id']==payload.get('id')),None)
        if profile is None:raise ValueError('The saved connection is no longer available.')
        nm(['--wait','25','connection','up','uuid',profile['id']],timeout=30)
    else:raise ValueError('The network action is not supported.')
    return snapshot()


if __name__=='__main__':
    try:
        raw=sys.stdin.readline(16385)
        if len(raw)>16384:raise ValueError('The network request is too large.')
        result=request(json.loads(raw or '{}'))
    except Exception as error:
        result=dict(ok=False,code=getattr(error,'code','invalid-request' if isinstance(error,ValueError) else 'unavailable'),message=str(error) if isinstance(error,ValueError) else 'The network service is unavailable.')
    print(json.dumps(result,separators=(',',':')))
