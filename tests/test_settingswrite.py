import json,os,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).parents[1]/'shell/helpers'))
import settingswrite
class AtomicPreferencesTests(unittest.TestCase):
    def test_stale_writer_preserves_unrelated_external_updates(self):
        with tempfile.TemporaryDirectory() as temp,patch.dict(os.environ,{'XDG_CONFIG_HOME':temp}):
            base={'version':3,'appearance':{'radius':8,'mode':'dark'},'bar':{'hiddenModules':[]}}
            settingswrite.save(base)
            external=json.loads(json.dumps(base));external['bar']['hiddenModules']=['clock'];external['futureSetting']={'keep':True}
            settingswrite.save(external)
            local=json.loads(json.dumps(base));local['appearance']['radius']=12
            result=settingswrite.save(local,base)
            saved=json.loads((Path(temp)/'swiftshell/settings.json').read_text())
            self.assertEqual(saved['appearance']['radius'],12)
            self.assertEqual(saved['bar']['hiddenModules'],['clock'])
            self.assertEqual(saved['futureSetting'],{'keep':True})
            self.assertEqual(result['document'],saved)
    def test_newer_changed_leaf_wins_without_replacing_its_siblings(self):
        base={'appearance':{'mode':'dark','radius':8},'list':[1,2]}
        local={'appearance':{'mode':'dark','radius':10},'list':[2,1]}
        current={'appearance':{'mode':'light','radius':11},'list':[1,2]}
        result=settingswrite.merge_changes(base,local,current)
        self.assertEqual(result,{'appearance':{'mode':'light','radius':10},'list':[2,1]})
        self.assertEqual(current['appearance']['radius'],11)
    def test_same_document_after_external_edit_is_written_not_cached(self):
        with tempfile.TemporaryDirectory() as temp,patch.dict(os.environ,{'XDG_CONFIG_HOME':temp}):
            document={'version':3,'clock':{'use24Hour':False}}
            self.assertTrue(settingswrite.save(document)['ok'])
            path=Path(temp)/'swiftshell/settings.json'
            path.write_text(json.dumps({'version':3,'clock':{'use24Hour':True}}))
            self.assertTrue(settingswrite.save(document)['ok'])
            self.assertFalse(json.loads(path.read_text())['clock']['use24Hour'])
            self.assertEqual(path.stat().st_mode & 0o777,0o600)
    def test_malformed_future_and_unreadable_documents_are_protected(self):
        with tempfile.TemporaryDirectory() as temp,patch.dict(os.environ,{'XDG_CONFIG_HOME':temp}):
            folder=Path(temp)/'swiftshell';folder.mkdir();path=folder/'settings.json'
            for raw in ['{broken',json.dumps({'version':99}),json.dumps({'version':True})]:
                path.write_text(raw)
                result=settingswrite.save({'version':3})
                self.assertFalse(result['ok']);self.assertTrue(result['protected'])
                self.assertEqual(path.read_text(),raw)
    def test_failed_replace_retains_previous_file_and_removes_temporary(self):
        with tempfile.TemporaryDirectory() as temp,patch.dict(os.environ,{'XDG_CONFIG_HOME':temp}):
            settingswrite.save({'version':3,'value':'original'})
            folder=Path(temp)/'swiftshell';path=folder/'settings.json';raw=path.read_text()
            with patch.object(settingswrite.os,'replace',side_effect=PermissionError):
                with self.assertRaises(PermissionError):settingswrite.save({'version':3,'value':'changed'})
            self.assertEqual(path.read_text(),raw)
            self.assertEqual(list(folder.glob('.settings-*.tmp')),[])
if __name__=='__main__':unittest.main()
