# CodexBar for DankMaterialShell

A DankBar widget plugin for the [Linux desktop app](../Linux/README.md). The pill
shows each displayed provider's logo, tinted to the warning color when that
provider's quota runs low, for every configured provider (turn off **Icons only** to
add the quota text, limited by `barProviders`); the popout lists every provider's
windows, reset times and local spending, and opens the Usage & Spend and Settings
windows. One `codexbar-linux` process owns provider polling, settings,
notifications and spending scans, including when several bars show the widget.

Build the Linux desktop app and install a CodexBar Linux CLI first (see the Linux
README), then run from the repository root:

```sh
python3 Integrations/DankMaterialShell/install.py --cli /absolute/path/to/codexbar
```

The same command works inside an extracted `CodexBarDesktop` release archive.

The installer runs the Linux installer (launcher, autostart, `linux.json`), turns
off the standalone tray to avoid a duplicate indicator, and copies the plugin and
the provider SVG logos to `~/.config/DankMaterialShell/plugins/codexBar`. An
existing copy is archived under `~/.config/DankMaterialShell/backups`. Enable
CodexBar in DMS Settings → Plugins and add it to a bar.

The widget reads the backend's private IPC snapshot (`codexbar-linux --snapshot`)
every five seconds; it never runs provider queries itself. When the backend is
absent it starts `codexbar-linux --background`, at most once a minute, because not
every compositor runs XDG autostart entries. Left click opens the popout, right
click requests one shared backend refresh. Unknown quota stays unavailable, old
data carries a `!` stale marker, and a lane under the notification threshold turns
the marks to the theme's warning color.

The plugin settings hold only the backend executable (default `codexbar-linux`),
whether to start it, icons only (default on), and the snapshot interval. Providers and their order,
accounts, refresh interval, notifications and bar detail (`showBarDetail`,
`showScopedCaps`, `barProviders`) are the backend's; change them in the CodexBar
Settings window or with `codexbar-linux --configure '<json>'`.

Remove `~/.config/DankMaterialShell/plugins/codexBar` and its bar entry to remove
the plugin. The desktop app and its autostart are independent; see the Linux
README for uninstall instructions.

```sh
python3 Integrations/DankMaterialShell/test_install.py
```
