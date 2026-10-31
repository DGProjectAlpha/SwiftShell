# Packaging

SwiftShell can be installed from a git checkout today. A distro package and a release archive are described here so later work has a place to land. Neither has been built or published.

## Layout

| Path | Role |
|---|---|
| `~/.local/share/swiftshell/app` | Installed Quickshell files. The installer owns this tree. |
| `~/.local/share/swiftshell/lib` | Installed command scripts. |
| `~/.local/share/swiftshell/manifest` | Product marker. Uninstall reads it before removing files. |
| `~/.local/bin/swiftshell` | User launcher. Replaced only when it carries the SwiftShell marker. |
| `~/.config/swiftshell/settings.json` | User settings. Install does not replace an existing file. Uninstall keeps the directory. |
| `~/.local/state/swiftshell/active` | Activation marker. |
| `~/.local/share/applications/swiftshell.desktop` | Application entry created by activation. It is not an autostart entry. |
| `~/.config/quickshell/swiftshell` | Optional symlink created by activation when that name is free. |

`XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and `XDG_STATE_HOME` replace the `~/.local` and `~/.config` prefixes when they are set.

A user install wins over a system copy. The draft `/usr/bin/swiftshell` runs the copy under the user data directory when that copy exists. Otherwise it exports the package root and runs `/usr/share/swiftshell/lib/swiftshell`; `start`, `activate`, `status`, and `doctor` therefore resolve the packaged app instead of incorrectly requiring `~/.local/share/swiftshell`.

## Operations

| Command | Effect |
|---|---|
| `./install.sh` | Copy or update the app, install the launcher, seed missing settings. |
| `swiftshell activate` | Record activation, add the desktop entry, and link a free Quickshell name. |
| `swiftshell deactivate` | Stop this install, remove the link, desktop entry, and activation marker. |
| `swiftshell uninstall` | Remove installed files and the launcher. Settings stay. |
| `swiftshell uninstall --purge-settings` | Also remove `~/.config/swiftshell`. |

None of these write Hyprland config, keyboard shortcuts, or service units.

## Future AUR package

`packaging/aur/PKGBUILD` is a draft. It installs shared files under `/usr/share/swiftshell` and a wrapper at `/usr/bin/swiftshell`. It does not run `install.sh`, does not touch a home directory, and does not enable a service.

The package manifest marks the shared tree as SwiftShell. `swiftshell uninstall` removes only per-user activation artifacts and tells the user to remove package-owned files with the package manager; `--purge-settings` may additionally remove only the user's SwiftShell settings. A hermetic package-layout test exercises status, start, activation, uninstall handoff, and settings purge. The PKGBUILD itself is still unbuilt on Arch.

Before anyone submits it:

- Choose a license. The draft uses `LicenseRef-None` because the repository does not have one yet.
- Replace `sha256sums=('SKIP')` with a real sum for a tag.
- Build it with `makepkg` on Arch and record the result.
- Keep user activation as a per-user command. A package install must not become the default Quickshell config.

## Future release archive

A source archive can contain the same tree as the git checkout:

```text
swiftshell-<version>/
  install.sh
  shell/
  scripts/
  README.md
  docs/
```

The install command stays `./install.sh`. No archive is produced by the current scripts. Tag a version, then generate the archive from that tag when the project is ready to publish one.
