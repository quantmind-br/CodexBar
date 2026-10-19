import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class InstallTests(unittest.TestCase):
    def test_install_and_reinstall_place_one_plugin_and_hide_the_tray(self):
        with tempfile.TemporaryDirectory(prefix='codexbar dms ') as temporary:
            home = Path(temporary)
            config = home / 'config'
            preferences = config / 'codexbar/linux.json'
            preferences.parent.mkdir(parents=True)
            preferences.write_text(json.dumps({'provider': 'claude', 'showTray': True}))
            script = Path(__file__).with_name('install.py')
            environment = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config), XDG_DATA_HOME=str(home / 'data'))
            for _ in range(2):
                subprocess.run(['python3', str(script), '--cli', '/usr/bin/true', '--binary', '/usr/bin/true'],
                               env=environment, check=True, capture_output=True)
            settings = json.loads(preferences.read_text())
            self.assertEqual(settings['provider'], 'claude')
            self.assertFalse(settings['showTray'])
            self.assertEqual(preferences.stat().st_mode & 0o077, 0)
            plugins = config / 'DankMaterialShell/plugins'
            self.assertEqual([path.parent.name for path in plugins.glob('*/plugin.json')], ['codexBar'])
            plugin = plugins / 'codexBar'
            manifest = json.loads((plugin / 'plugin.json').read_text())
            self.assertEqual(manifest['id'], 'codexBar')
            for name in [manifest['component'], manifest['settings']]:
                self.assertTrue((plugin / name).is_file())
            sources = Path(__file__).resolve().parents[2] / 'Sources/CodexBar/Resources'
            logos = sorted(path.name for path in sources.glob('ProviderIcon-*.svg'))
            self.assertTrue(logos)
            self.assertEqual(sorted(path.name for path in (plugin / 'icons').iterdir()), logos)
            # The previous copy is archived outside the directory DMS scans for plugins.
            self.assertEqual(len(list((config / 'DankMaterialShell/backups').iterdir())), 1)
            self.assertTrue((config / 'autostart/com.steipete.CodexBar.desktop').exists())

    def test_requires_a_cli(self):
        script = Path(__file__).with_name('install.py')
        result = subprocess.run(['python3', str(script)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('--cli', result.stderr)


if __name__ == '__main__':
    unittest.main()
