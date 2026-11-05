import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).parents[1]/'shell/helpers'))
import defaultappsctl as d

class DefaultApplications(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.home=Path(self.temp.name)
        self.env=patch.dict(os.environ,{'XDG_CONFIG_HOME':str(self.home/'config'),'XDG_DATA_HOME':str(self.home/'data'),'XDG_DATA_DIRS':str(self.home/'system'),'XDG_STATE_HOME':str(self.home/'state'),'XDG_CONFIG_DIRS':str(self.home/'etc'),'XDG_CURRENT_DESKTOP':'Hyprland'})
        self.env.start();self.apps=self.home/'data/applications';self.apps.mkdir(parents=True)
        self.entry('browser.desktop','Browser','MimeType=x-scheme-handler/https;x-scheme-handler/http;text/html;\nCategories=WebBrowser;')
        self.entry('calendar.desktop','Calendar','Categories=Calendar;')
        self.entry('terminal.desktop','Terminal','Categories=TerminalEmulator;')
    def tearDown(self):self.env.stop();self.temp.cleanup()
    def entry(self,name,label,extra=''):
        (self.apps/name).write_text('[Desktop Entry]\nType=Application\nName='+label+'\nExec=true\n'+extra+'\n')
    def test_discovery_supports_real_roles_and_masks_hidden_entries(self):
        system=self.home/'system/applications';system.mkdir(parents=True)
        (system/'hidden.desktop').write_text('[Desktop Entry]\nType=Application\nName=Hidden\nExec=true\nMimeType=application/pdf;\n')
        self.entry('hidden.desktop','Hidden','Hidden=true')
        entries=d.desktop_entries()
        self.assertNotIn('hidden.desktop',entries)
        self.assertEqual([i['id'] for i in d.candidates('browser',entries)],['browser.desktop'])
        self.assertEqual([i['id'] for i in d.candidates('terminal',entries)],['terminal.desktop'])
    def test_no_arbitrary_ids_or_non_supporting_apps(self):
        for role,app in [('browser','../../evil.desktop'),('browser','terminal.desktop'),('absent','browser.desktop')]:
            with self.assertRaises(ValueError):d.choose(role,app)
    def test_choose_verifies_defaults_and_undo_restores_previous(self):
        defaults={m:'old.desktop' for m in d.ROLES['browser'][1]}
        def assign(mime,desktop,expected=''):defaults[mime]=desktop
        with patch.object(d,'query',side_effect=lambda m:defaults[m]),patch.object(d,'assign',side_effect=assign):
            d.choose('browser','browser.desktop')
            self.assertEqual(set(defaults.values()),{'browser.desktop'})
            d.reset('browser')
            self.assertEqual(set(defaults.values()),{'old.desktop'})
        backups=list((d.state_path().parent/'backups').glob('*.json'))
        self.assertEqual(len(backups),2)
        self.assertEqual(d.state_path().stat().st_mode & 0o777,0o600)
    def test_failure_rolls_back_partial_mime_changes(self):
        defaults={m:'old.desktop' for m in d.ROLES['browser'][1]}
        def assign(mime,desktop,expected=''):
            if mime=='text/html' and desktop=='browser.desktop':raise ValueError('test failure')
            defaults[mime]=desktop
        with patch.object(d,'query',side_effect=lambda m:defaults[m]),patch.object(d,'assign',side_effect=assign):
            with self.assertRaises(ValueError):d.choose('browser','browser.desktop')
        self.assertEqual(set(defaults.values()),{'old.desktop'})
        self.assertFalse(d.state_path().exists())
    def test_external_changes_are_not_overwritten_by_undo(self):
        defaults={m:'old.desktop' for m in d.ROLES['browser'][1]}
        with patch.object(d,'query',side_effect=lambda m:defaults[m]),patch.object(d,'assign',side_effect=lambda m,a,expected='':defaults.__setitem__(m,a)):
            d.choose('browser','browser.desktop');defaults['text/html']='other.desktop'
            with self.assertRaises(ValueError):d.reset('browser')
        self.assertEqual(defaults['text/html'],'other.desktop')
    def test_shell_preferred_calendar_does_not_invent_mime_registration(self):
        with patch.object(d,'query',return_value=''),patch.object(d,'assign') as assign:
            d.choose('calendar','calendar.desktop');assign.assert_not_called()
            result=d.snapshot();calendar=next(r for r in result['roles'] if r['id']=='calendar')
            self.assertTrue(calendar['shellOnly']);self.assertEqual(calendar['current'],'calendar.desktop')
    def test_removing_owned_default_preserves_comments_and_other_values(self):
        path=d.config_home()/'mimeapps.list';path.parent.mkdir(parents=True)
        path.write_text('# user comment\n[Default Applications]\ntext/html=browser.desktop;\napplication/pdf=other.desktop;\n[Added Associations]\ntext/html=browser.desktop;\n')
        d.remove_owned_default('text/html','browser.desktop')
        result=path.read_text();self.assertIn('# user comment',result);self.assertIn('application/pdf=other.desktop;',result)
        self.assertEqual(result.count('text/html=browser.desktop;'),1)
    def test_malformed_saved_preferences_are_protected(self):
        d.state_path().parent.mkdir(parents=True)
        d.state_path().write_text('{broken')
        with patch.object(d,'command') as command:
            with self.assertRaises(ValueError):d.choose('browser','browser.desktop')
            command.assert_not_called()
        self.assertEqual(d.state_path().read_text(),'{broken')
    def test_unsupported_preferences_are_protected(self):
        d.atomic(d.state_path(),{'version':999,'roles':{}})
        with self.assertRaises(ValueError):d.preferences()
    def test_launch_uses_desktop_parser_and_url_validation(self):
        with patch.object(d,'command',return_value='browser.desktop') as command:
            d.launch('browser','https://example.invalid/test?a=1&b=2')
            self.assertEqual(command.call_args.args[0],['xdg-open','https://example.invalid/test?a=1&b=2'])
            d.launch('browser');self.assertEqual(command.call_args.args[0],['gio','launch',str(self.apps/'browser.desktop')])
            for target in ['javascript:alert(1)','file:///etc/passwd','https://bad\nurl']:
                with self.assertRaises(ValueError):d.launch('browser',target)

    def test_terminal_choice_links_the_original_desktop_command(self):
        import hyprsource
        change=dict(supported=True,changed=True,transaction='a'*32,previousCommand='kitty')
        with patch.object(hyprsource,'sync_terminal',return_value=change) as sync:
            d.choose('terminal','terminal.desktop')
            sync.assert_called_once_with('true')
        selected=d.preferences()['roles']['terminal']
        self.assertEqual(selected['desktopTerminal'],{'originalCommand':'kitty','assignedCommand':'true'})
    def test_terminal_parser_drops_desktop_field_codes_and_quotes_arguments(self):
        self.assertEqual(d.terminal_command({'exec':'konsole --workdir "a b" %U'}),"konsole --workdir 'a b'")
        with self.assertRaises(ValueError):d.terminal_command({'exec':'konsole %unsupported'})
    def test_terminal_preference_write_failure_rolls_back_the_source_transaction(self):
        import hyprsource
        change=dict(supported=True,changed=True,transaction='b'*32,previousCommand='kitty')
        with patch.object(hyprsource,'sync_terminal',return_value=change),patch.object(d,'backup'),patch.object(d,'atomic',side_effect=OSError('Synthetic disk failure')),patch.object(d,'rollback_terminal') as rollback:
            with self.assertRaises(OSError):d.choose('terminal','terminal.desktop')
            rollback.assert_called_once_with(change)

if __name__=='__main__':unittest.main()
