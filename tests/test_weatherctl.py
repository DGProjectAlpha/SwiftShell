#!/usr/bin/env python3
import datetime as dt
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
ROOT=Path(__file__).parents[1]
spec=importlib.util.spec_from_file_location('weatherctl',ROOT/'shell/helpers/weatherctl.py');weather=importlib.util.module_from_spec(spec);spec.loader.exec_module(weather)
NOW=1793880000
PLACE={'name':'Berlin, Germany','latitude':52.52,'longitude':13.405,'timezone':'Europe/Berlin'}
def fixture():
 base=1793833200
 hours=[base+i*3600 for i in range(168)]
 daily=[base+i*86400 for i in range(7)]
 return {'timezone':'Europe/Berlin','current':{'time':NOW,'temperature_2m':8.2,'apparent_temperature':6.5,'relative_humidity_2m':72,'is_day':1,'precipitation':0,'weather_code':3,'wind_speed_10m':10,'wind_direction_10m':245},'hourly':{'time':hours,'temperature_2m':[7+i%24*.2 for i in range(168)],'precipitation_probability':[i%4*20 for i in range(168)],'precipitation':[.1 if i%4 else 0 for i in range(168)],'relative_humidity_2m':[70]*168,'wind_speed_10m':[10]*168,'weather_code':[3]*168,'is_day':[1]*168},'daily':{'time':daily,'weather_code':[3,61,2,0,80,3,1],'temperature_2m_min':[4]*7,'temperature_2m_max':[10]*7,'sunrise':[t+7*3600 for t in daily],'sunset':[t+17*3600 for t in daily],'precipitation_sum':[1]*7,'precipitation_probability_max':[60]*7,'uv_index_max':[2]*7}}
AIR={'current':{'us_aqi':32,'european_aqi':20,'pm2_5':5.1,'pm10':9.2,'ozone':40,'nitrogen_dioxide':12}}
class WeatherTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.env=patch.dict(os.environ,{'XDG_CACHE_HOME':self.temp.name});self.env.start()
 def tearDown(self):self.env.stop();self.temp.cleanup()
 def test_validation_rejects_invalid_locations_and_never_sends_request(self):
  with patch.object(weather,'request_json') as request:
   for place in [{},dict(PLACE,latitude=float('nan')),dict(PLACE,longitude=181),dict(PLACE,latitude=True),dict(PLACE,name='')]:
    with self.assertRaises(weather.WeatherError):weather.forecast({'location':place})
   request.assert_not_called()
 def test_forecast_normalizes_full_daily_hourly_and_partial_air_quality(self):
  data=weather.normalize(fixture(),AIR,PLACE,'metric',NOW)
  self.assertEqual(data['current']['temperature'],8.2);self.assertEqual(len(data['days']),7);self.assertEqual(len(data['days'][0]['hours']),24);self.assertEqual(len(data['hours']),24)
  self.assertEqual(data['airQuality']['usAqi'],32);self.assertEqual(data['units']['precipitation'],'mm')
  self.assertIsNone(weather.normalize(fixture(),{},PLACE,'metric',NOW)['airQuality']['usAqi'])
 def test_forecast_cache_avoids_network_and_preserves_exact_age_offline(self):
  request={'location':PLACE,'units':'metric'}
  with patch.object(weather.time,'time',return_value=NOW),patch.object(weather,'request_json',side_effect=[fixture(),AIR]) as network:
   first=weather.forecast(request);second=weather.forecast(request)
   self.assertTrue(first['ok']);self.assertFalse(first['cached']);self.assertTrue(second['cached']);self.assertEqual(network.call_count,2)
  with patch.object(weather.time,'time',return_value=NOW+3600),patch.object(weather,'request_json',side_effect=weather.WeatherError('Offline')):
   offline=weather.forecast(dict(request,force=True));self.assertTrue(offline['data']['stale']);self.assertEqual(offline['data']['fetchedAt'],NOW*1000)
  self.assertEqual((next(weather.folder().glob('forecast-*.json')).stat().st_mode&0o777),0o600)
 def test_imperial_units_reach_verified_provider_parameters(self):
  with patch.object(weather.time,'time',return_value=NOW),patch.object(weather,'request_json',side_effect=[fixture(),AIR]) as network:
   result=weather.forecast({'location':PLACE,'units':'imperial'})
   params=network.call_args_list[0].args[1];self.assertEqual(params['temperature_unit'],'fahrenheit');self.assertEqual(params['precipitation_unit'],'inch');self.assertEqual(result['data']['units']['wind'],'mph')
 def test_air_quality_failure_keeps_weather_available(self):
  with patch.object(weather,'request_json',side_effect=[fixture(),weather.WeatherError('Unavailable')]):
   self.assertTrue(weather.forecast({'location':PLACE})['ok'])
 def test_city_search_cached_and_never_uses_ip_location(self):
  rows={'results':[dict(PLACE,name='Berlin',admin1='Berlin',country='Germany')]}
  with patch.object(weather,'request_json',return_value=rows) as network:
   result=weather.geocode('Berlin');again=weather.geocode('Berlin');self.assertEqual(network.call_count,1);self.assertEqual(network.call_args.args[0],weather.GEOCODE);self.assertEqual(result['locations'][0]['latitude'],52.52);self.assertTrue(again['cached'])
 def test_explicit_address_fallback_cached_and_rate_limited(self):
  rows=[{'display_name':'Public fixture address','lat':'52.52','lon':'13.405'}]
  with patch.object(weather.time,'time',return_value=NOW),patch.object(weather,'request_json',side_effect=[{},rows,{}]) as network:
   result=weather.geocode('Public fixture road');self.assertEqual(result['locations'][0]['longitude'],13.405);self.assertIn('OpenStreetMap',result['attribution'])
   self.assertTrue(weather.geocode('Public fixture road')['cached'])
   with self.assertRaises(weather.WeatherError):weather.geocode('Other fixture road')
   self.assertEqual(network.call_count,3)
 def test_approximate_lookup_only_runs_for_explicit_action_and_excludes_ip(self):
  data={'success':True,'ip':'192.0.2.1','city':'Fixture City','region':'Fixture Region','country':'Fixture Country','latitude':52.52,'longitude':13.405,'timezone':{'id':'Europe/Berlin'}}
  with patch.object(weather,'request_json',return_value=data) as network:
   result=weather.run({'action':'locate'});self.assertEqual(network.call_args.args[0],weather.APPROXIMATE);self.assertNotIn('192.0.2.1',json.dumps(result));self.assertNotIn('ip',result['location'])
 def test_bounded_response_and_generic_network_errors(self):
  class Response:
   def __enter__(self):return self
   def __exit__(self,*args):pass
   def read(self,size):return b'x'*(weather.MAX_BYTES+1)
  with patch.object(weather.urllib.request,'urlopen',return_value=Response()):
   with self.assertRaises(weather.WeatherError):weather.request_json(weather.FORECAST)
  with patch.object(weather.urllib.request,'urlopen',side_effect=OSError('private URL')):
   with self.assertRaises(weather.WeatherError) as error:weather.request_json(weather.FORECAST)
   self.assertNotIn('private',str(error.exception))
 def test_malformed_current_conditions_are_not_invented(self):
  raw=fixture();raw['current']['temperature_2m']=None
  with self.assertRaises(weather.WeatherError):weather.normalize(raw,AIR,PLACE,'metric',NOW)
if __name__=='__main__':unittest.main()
