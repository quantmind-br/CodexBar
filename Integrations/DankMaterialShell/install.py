#!/usr/bin/env python3
"""Install the Linux desktop app and the DankMaterialShell bar plugin for this user."""
import argparse
import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

REPO = Path(__file__).resolve().parents[2]
PLUGIN_ID = 'codexBar'
PLUGIN_FILES = ['plugin.json', 'CodexBarWidget.qml', 'CodexBarSettings.qml']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cli', required=True, help='CodexBar Linux CLI')
    parser.add_argument('--binary', help='codexbar-linux desktop binary')
    parser.add_argument('--provider')
    parser.add_argument('--no-autostart', action='store_true')
    args = parser.parse_args()
    command = [sys.executable, str(REPO / 'Integrations/Linux/install.py'), '--cli', args.cli]
    if args.binary:
        command.extend(['--binary', args.binary])
    if args.provider:
        command.extend(['--provider', args.provider])
    if args.no_autostart:
        command.append('--no-autostart')
    if subprocess.call(command) != 0:
        return 1
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config'))
    # DMS draws the bar widget, so the standalone tray would be a duplicate indicator.
    preferences = config / 'codexbar/linux.json'
    settings = json.loads(preferences.read_text(encoding='utf-8'))
    settings['showTray'] = False
    target = Path(os.path.realpath(preferences))
    target.write_text(json.dumps(settings, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    plugin = config / 'DankMaterialShell/plugins' / PLUGIN_ID
    if plugin.exists() or plugin.is_symlink():
        # Archive outside the plugin discovery directory so DMS never loads a stale copy.
        stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
        backup = config / 'DankMaterialShell/backups' / f'{PLUGIN_ID}-{stamp}'
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(plugin), backup)
    plugin.mkdir(parents=True)
    source = Path(__file__).resolve().parent
    for name in PLUGIN_FILES:
        shutil.copy2(source / name, plugin / name)
    icons = plugin / 'icons'
    icons.mkdir()
    # A checkout keeps the marks in Sources; a release archive carries them beside the Omarchy adapter.
    for folder in [REPO / 'Sources/CodexBar/Resources', REPO / 'Integrations/Omarchy/icons']:
        for icon in sorted(folder.glob('ProviderIcon-*.svg')):
            shutil.copy2(icon, icons / icon.name)
    print(f'Installed {plugin}. Enable CodexBar in DMS Settings → Plugins, then add it to a bar.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
