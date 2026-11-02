import importlib.util,sys,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).parents[1]/'shell/helpers'))
spec=importlib.util.spec_from_file_location('desktoptools',Path(__file__).parents[1]/'shell/helpers/desktoptools.py');tools=importlib.util.module_from_spec(spec);spec.loader.exec_module(tools)
class DesktopTools(unittest.TestCase):
 def test_password_hint_never_reads_content(self):
  with patch.object(tools,'bounded_output',return_value=b'text/plain\nx-kde-passwordManagerHint\n') as read:
   self.assertTrue(tools.clipboard()['skip']);self.assertEqual(read.call_count,1)
 def test_images_never_enter_text_history(self):
  with patch.object(tools,'bounded_output',return_value=b'image/png\n') as read:
   self.assertTrue(tools.clipboard()['skip']);self.assertEqual(read.call_count,1)
 def test_only_bounded_plain_text_is_returned(self):
  with patch.object(tools,'bounded_output',side_effect=[b'text/plain\n',b'fixture text']):self.assertEqual(tools.clipboard()['text'],'fixture text')
 def test_large_and_invalid_text_are_skipped(self):
  for value in [b'x'*4097,b'a\0b',b'\xff']:
   with patch.object(tools,'bounded_output',side_effect=[b'text/plain\n',value]):self.assertTrue(tools.clipboard()['skip'])
 def test_region_uses_typed_geometry_and_png_clipboard(self):
  with patch.object(tools,'bounded_output',side_effect=[b'-10,20 40x30\n',b'\x89PNG\r\n\x1a\nfixture']) as read,patch.object(tools.subprocess,'run') as copy:
   self.assertTrue(tools.capture('region')['ok']);self.assertEqual(read.call_args_list[1].args[0],['grim','-g','-10,20 40x30','-']);self.assertEqual(copy.call_args.args[0],['wl-copy','--type','image/png'])
 def test_bad_region_cannot_inject_command(self):
  with patch.object(tools,'bounded_output',return_value=b'1,2 10x10; touch /tmp/should-not-exist') as read:
   with self.assertRaises(ValueError):tools.capture('region')
   self.assertEqual(read.call_count,1)
 def test_escape_cancels_without_capturing(self):
  with patch.object(tools,"bounded_output",side_effect=ValueError("cancelled")) as read:
   self.assertTrue(tools.capture("region")["cancelled"]);self.assertEqual(read.call_count,1)
 def test_missing_output_is_refused(self):
  with patch('displayctl.ipc',return_value='[{"name":"DP-1"}]'),patch.object(tools,'bounded_output') as read:
   with self.assertRaises(ValueError):tools.capture('output','not-connected')
   read.assert_not_called()
 def test_real_bounded_transport(self):
  self.assertEqual(tools.bounded_output([sys.executable,'-c','print("fixture")'],32),b'fixture\n')
  with self.assertRaises(ValueError):tools.bounded_output([sys.executable,'-c','print("x"*1000)'],32)
if __name__=='__main__':unittest.main()
