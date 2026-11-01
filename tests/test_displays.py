import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('displayctl', Path(__file__).parents[1]/'shell/helpers/displayctl.py')
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)

# Sanitized real 0.57 monitor data from this workstation.
BASE = [dict(name='DP-1',width=2560,height=1440,refresh=164.834,scale=1,transform=0,x=0,y=0,enabled=True,
             modes=[dict(width=2560,height=1440,refresh=164.83),dict(width=1920,height=1080,refresh=60)],mirror='none'),
        dict(name='HDMI-A-1',width=1920,height=1080,refresh=60,scale=1.25,transform=0,x=2560,y=720,enabled=True,
             modes=[dict(width=1920,height=1080,refresh=60),dict(width=1280,height=720,refresh=60)],mirror='none')]


class DisplayValidation(unittest.TestCase):
    def test_current_layout_and_named_outputs(self):
        self.assertEqual(d.validate(BASE, BASE)[1]['scale'],1.25)
        self.assertEqual(d.logical_size(BASE[1]), (1536,864))
    def test_rejects_unsupported_modes_and_last_output_disable(self):
        for field,value in [('width',3333),('refresh',999),('scale',float('nan')),('transform',9),('x','bad')]:
            bad=copy.deepcopy(BASE);bad[0][field]=value
            with self.subTest(field=field), self.assertRaises(ValueError): d.validate(bad,BASE)
        bad=copy.deepcopy(BASE)
        for item in bad:item['enabled']=False
        with self.assertRaises(ValueError): d.validate(bad,BASE)
    def test_rejects_overlap_and_hotplug_stale_request(self):
        bad=copy.deepcopy(BASE);bad[1]['x']=20
        with self.assertRaises(ValueError):d.validate(bad,BASE)
        with self.assertRaises(ValueError):d.validate(BASE[:1],BASE)
    def test_rotation_and_fractional_scale(self):
        changed=copy.deepcopy(BASE);changed[1]['transform']=1
        self.assertEqual(d.logical_size(changed[1]),(864,1536))
        self.assertEqual(d.validate(changed,BASE)[1]['transform'],1)
        changed[1]['scale']=1.75
        with self.assertRaises(ValueError):d.validate(changed,BASE)
    def test_patches_do_not_reset_color_hdr_or_other_properties(self):
        changed=copy.deepcopy(BASE[0]);changed['y']=20
        self.assertEqual(d.lua_spec(changed,BASE[0]),'hl.monitor({output="DP-1",position="0x20"})')
        self.assertEqual(d.lua_spec(BASE[0],changed),'hl.monitor({output="DP-1",position="0x0"})')
        self.assertEqual(d.lua_spec(BASE[0],BASE[0]),'')
    def test_monitor_name_quoted_not_executed(self):
        changed=copy.deepcopy(BASE[0]);changed['name']='DP-1"}; error("bad") --';changed['scale']=1.25
        self.assertIn('DP-1\\"',d.lua_spec(changed,BASE[0]))
    def test_atomic_recovery_snapshot_and_matching(self):
        with tempfile.TemporaryDirectory() as folder:
            journal=Path(folder)/'transaction.json'
            d.atomic(journal,{'state':'applying','before':BASE})
            self.assertEqual(d.read(journal,{})['before'],BASE)
            self.assertEqual(journal.stat().st_mode & 0o777,0o600)
        self.assertTrue(d.matches(BASE,BASE))
        other=copy.deepcopy(BASE);other[1]['y']=0
        self.assertFalse(d.matches(BASE,other))


if __name__=='__main__':unittest.main()
