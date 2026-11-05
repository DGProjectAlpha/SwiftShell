#!/usr/bin/env python3
"""Bounded weather operations. Private location/search data travels on stdin only."""
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from zoneinfo import ZoneInfo,ZoneInfoNotFoundError

USER_AGENT='SwiftShell/0.1 (+https://github.com/DGProjectAlpha/SwiftShell)'
MAX_BYTES=2*1024*1024
FORECAST='https://api.open-meteo.com/v1/forecast'
AIR='https://air-quality-api.open-meteo.com/v1/air-quality'
GEOCODE='https://geocoding-api.open-meteo.com/v1/search'
ADDRESS='https://nominatim.openstreetmap.org/search'
APPROXIMATE='https://ipwho.is/'

class WeatherError(ValueError):pass

def folder():
    result=Path(os.environ.get('XDG_CACHE_HOME',str(Path.home()/'.cache')))/'swiftshell/weather'
    result.mkdir(parents=True,exist_ok=True,mode=0o700)
    return result

def atomic(path,value):
    fd,name=tempfile.mkstemp(prefix='.weather-',dir=path.parent)
    try:
        with os.fdopen(fd,'w') as stream:
            json.dump(value,stream,separators=(',',':'));stream.flush();os.fsync(stream.fileno())
        os.replace(name,path)
    finally:
        try:os.unlink(name)
        except FileNotFoundError:pass

def read(path):
    try:
        if path.stat().st_size>MAX_BYTES:return None
        value=json.loads(path.read_text())
        return value if isinstance(value,dict) else None
    except (OSError,ValueError):return None

def request_json(endpoint,params=None):
    url=endpoint+('?' + urllib.parse.urlencode(params) if params else '')
    request=urllib.request.Request(url,headers={'User-Agent':USER_AGENT,'Accept':'application/json'})
    try:
        with urllib.request.urlopen(request,timeout=8) as response:
            payload=response.read(MAX_BYTES+1)
        if len(payload)>MAX_BYTES:raise WeatherError('The weather service returned too much data.')
        return json.loads(payload)
    except (OSError,ValueError,urllib.error.URLError):
        raise WeatherError('Weather services are unavailable. Check your connection and try again.') from None

def number(value):return isinstance(value,(int,float)) and not isinstance(value,bool) and math.isfinite(value)

def location(value):
    if not isinstance(value,dict):raise WeatherError('Choose a location first.')
    lat,lon=value.get('latitude'),value.get('longitude')
    if not number(lat) or not number(lon) or not -90<=lat<=90 or not -180<=lon<=180:raise WeatherError('Choose a valid location.')
    name=value.get('name')
    if not isinstance(name,str) or not name.strip() or len(name)>180:raise WeatherError('Choose a named location.')
    result={'name':name.strip(),'latitude':round(lat,5),'longitude':round(lon,5)}
    if isinstance(value.get('timezone'),str) and len(value['timezone'])<=80:result['timezone']=value['timezone']
    return result

def geocode(query):
    if not isinstance(query,str) or not 2<=len(query.strip())<=200 or any(ord(c)<32 for c in query):raise WeatherError('Enter a city, postal code or address.')
    query=query.strip();key=hashlib.sha256(query.casefold().encode()).hexdigest()
    path=folder()/('place-'+key+'.json');saved=read(path)
    if saved and time.time()-saved.get('fetchedAt',0)<86400:return {'ok':True,'locations':saved.get('locations',[]),'attribution':saved.get('attribution',''),'cached':True}
    result=request_json(GEOCODE,{'name':query,'count':8,'language':'en','format':'json'})
    places=[]
    for entry in result.get('results',[])[:8]:
        label=', '.join(dict.fromkeys(str(entry.get(k,'')).strip() for k in ['name','admin1','country'] if entry.get(k)))
        try:places.append(location({'name':label,'latitude':entry.get('latitude'),'longitude':entry.get('longitude'),'timezone':entry.get('timezone','')}))
        except WeatherError:continue
    attribution='Location search: Open-Meteo / GeoNames'
    if not places:
        # Addresses are searched only after the user's explicit Search action.
        # Cache/rate limiting and an identifying UA follow public Nominatim policy.
        import fcntl
        with (folder()/'address-search.lock').open('a+') as guard:
            fcntl.flock(guard,fcntl.LOCK_EX)
            throttle=read(folder()/'address-search-rate.json') or {}
            if time.time()-throttle.get('time',0)<1.05:raise WeatherError('Wait a moment before searching again.')
            atomic(folder()/'address-search-rate.json',{'time':time.time()})
            # Administrators may redirect this integration if the public operator
            # requests it, without changing application source or user queries.
            endpoint=os.environ.get('SWIFTSHELL_ADDRESS_SEARCH_URL',ADDRESS)
            parsed=urllib.parse.urlsplit(endpoint)
            if parsed.scheme!='https' or not parsed.netloc or parsed.username or parsed.password or parsed.query or parsed.fragment:raise WeatherError('Address search is unavailable.')
            rows=request_json(endpoint,{'q':query,'format':'jsonv2','limit':6,'addressdetails':0})
        if isinstance(rows,list):
            for entry in rows[:6]:
                try:places.append(location({'name':str(entry.get('display_name',''))[:180],'latitude':float(entry['lat']),'longitude':float(entry['lon'])}))
                except (WeatherError,ValueError,TypeError,KeyError):continue
        attribution='Address search: © OpenStreetMap contributors'
    atomic(path,{'fetchedAt':time.time(),'locations':places,'attribution':attribution})
    return {'ok':True,'locations':places,'attribution':attribution,'cached':False}

def approximate():
    # Called solely by the explicit approximate-location choice; never startup.
    result=request_json(APPROXIMATE)
    if not isinstance(result,dict) or result.get('success') is False:raise WeatherError('Approximate location is unavailable. Search for a place instead.')
    label=', '.join(dict.fromkeys(str(result.get(k,'')).strip() for k in ['city','region','country'] if result.get(k)))
    zone=result.get('timezone',{});zone=zone.get('id','') if isinstance(zone,dict) else ''
    return {'ok':True,'location':location({'name':label,'latitude':result.get('latitude'),'longitude':result.get('longitude'),'timezone':zone})}

def cell(section,key,index):
    values=section.get(key,[])
    if not isinstance(values,list) or index>=len(values):return None
    value=values[index]
    return value if number(value) else None

def scalar(section,key):
    value=section.get(key)
    return value if number(value) else None

def normalize(raw,air,place,units,now=None):
    now=time.time() if now is None else now
    if not isinstance(raw,dict) or not isinstance(raw.get('current'),dict) or not isinstance(raw.get('daily'),dict):raise WeatherError('The forecast is incomplete. Try again later.')
    zone=raw.get('timezone','UTC')
    try:tz=ZoneInfo(zone)
    except (ZoneInfoNotFoundError,TypeError):tz=dt.timezone.utc;zone='UTC'
    current=raw['current'];daily=raw['daily'];hourly=raw.get('hourly',{})
    current_data={'time':scalar(current,'time'),'temperature':scalar(current,'temperature_2m'),'feelsLike':scalar(current,'apparent_temperature'),'humidity':scalar(current,'relative_humidity_2m'),'precipitation':scalar(current,'precipitation'),'wind':scalar(current,'wind_speed_10m'),'windDirection':scalar(current,'wind_direction_10m'),'code':scalar(current,'weather_code'),'isDay':current.get('is_day',1)==1}
    if current_data['temperature'] is None:raise WeatherError('Current conditions are unavailable.')
    hours=[]
    for i,timestamp in enumerate(hourly.get('time',[])[:192]):
        if not number(timestamp):continue
        local=dt.datetime.fromtimestamp(timestamp,tz)
        hours.append({'time':timestamp,'day':local.date().isoformat(),'label':local.strftime('%H:%M'),'temperature':cell(hourly,'temperature_2m',i),'probability':cell(hourly,'precipitation_probability',i),'precipitation':cell(hourly,'precipitation',i),'humidity':cell(hourly,'relative_humidity_2m',i),'wind':cell(hourly,'wind_speed_10m',i),'code':cell(hourly,'weather_code',i),'isDay':cell(hourly,'is_day',i)!=0})
    today=dt.datetime.fromtimestamp(now,tz).date().isoformat();days=[]
    for i,timestamp in enumerate(daily.get('time',[])[:7]):
        if not number(timestamp):continue
        local=dt.datetime.fromtimestamp(timestamp,tz);key=local.date().isoformat()
        sunrise=cell(daily,'sunrise',i);sunset=cell(daily,'sunset',i)
        days.append({'key':key,'label':'Today' if key==today else local.strftime('%A'),'date':local.strftime('%b %d'),'code':cell(daily,'weather_code',i),'low':cell(daily,'temperature_2m_min',i),'high':cell(daily,'temperature_2m_max',i),'precipitation':cell(daily,'precipitation_sum',i),'probability':cell(daily,'precipitation_probability_max',i),'uv':cell(daily,'uv_index_max',i),'sunrise':dt.datetime.fromtimestamp(sunrise,tz).strftime('%H:%M') if sunrise else '—','sunset':dt.datetime.fromtimestamp(sunset,tz).strftime('%H:%M') if sunset else '—','hours':[hour for hour in hours if hour['day']==key]})
    air_current=air.get('current',{}) if isinstance(air,dict) else {}
    quality={'usAqi':scalar(air_current,'us_aqi'),'euAqi':scalar(air_current,'european_aqi'),'pm25':scalar(air_current,'pm2_5'),'pm10':scalar(air_current,'pm10'),'ozone':scalar(air_current,'ozone'),'nitrogenDioxide':scalar(air_current,'nitrogen_dioxide')}
    return {'location':place,'fetchedAt':round(now*1000),'timezone':zone,'current':current_data,'days':days,'hours':[hour for hour in hours if hour['time']>=now-1800][:24],'airQuality':quality,'units':{'temperature':'°F' if units=='imperial' else '°C','wind':'mph' if units=='imperial' else 'km/h','precipitation':'in' if units=='imperial' else 'mm'},'stale':False,'attribution':'Weather: Open-Meteo · Air quality: CAMS / Open-Meteo'}

def forecast(request):
    place=location(request.get('location'));units=request.get('units','metric')
    if units not in ['metric','imperial']:raise WeatherError('Choose Celsius or Fahrenheit.')
    key=hashlib.sha256(json.dumps([place['latitude'],place['longitude'],units]).encode()).hexdigest();path=folder()/('forecast-'+key+'.json');saved=read(path)
    if saved and (not number(saved.get('fetchedAt')) or not isinstance(saved.get('current'),dict) or not isinstance(saved.get('days'),list)):saved=None
    refresh=request.get('refreshMinutes',15)
    if not number(refresh) or not 5<=refresh<=120:refresh=15
    age=time.time()*1000-(saved or {}).get('fetchedAt',0)
    if saved and request.get('force') is not True and 0<=age<refresh*60000:return {'ok':True,'data':saved,'cached':True}
    params={'latitude':place['latitude'],'longitude':place['longitude'],'timezone':'auto','timeformat':'unixtime','forecast_days':7,'current':'temperature_2m,apparent_temperature,relative_humidity_2m,is_day,precipitation,weather_code,wind_speed_10m,wind_direction_10m','hourly':'temperature_2m,relative_humidity_2m,precipitation_probability,precipitation,weather_code,wind_speed_10m,is_day','daily':'weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_sum,precipitation_probability_max,uv_index_max'}
    if units=='imperial':params.update(temperature_unit='fahrenheit',wind_speed_unit='mph',precipitation_unit='inch')
    try:
        raw=request_json(FORECAST,params)
        try:air=request_json(AIR,{'latitude':place['latitude'],'longitude':place['longitude'],'timezone':'auto','timeformat':'unixtime','current':'us_aqi,european_aqi,pm2_5,pm10,ozone,nitrogen_dioxide','forecast_days':1})
        except WeatherError:air={}
        data=normalize(raw,air,place,units);atomic(path,data)
        return {'ok':True,'data':data,'cached':False}
    except WeatherError:
        if saved:
            saved['stale']=True
            return {'ok':True,'data':saved,'cached':True,'message':'Offline · showing the saved forecast.'}
        raise

def run(request):
    if not isinstance(request,dict):raise WeatherError('The weather request is invalid.')
    action=request.get('action')
    if action=='search':return geocode(request.get('query'))
    if action=='locate':return approximate()
    if action=='forecast':return forecast(request)
    raise WeatherError('The weather action is unavailable.')

if __name__=='__main__':
    import sys
    try:
        line=sys.stdin.readline(8193)
        if len(line)>8192:raise WeatherError('The weather request is too long.')
        result=run(json.loads(line))
    except Exception as error:result={'ok':False,'message':str(error) if isinstance(error,WeatherError) else 'Weather services are unavailable. Try again later.'}
    print(json.dumps(result,separators=(',',':')))
