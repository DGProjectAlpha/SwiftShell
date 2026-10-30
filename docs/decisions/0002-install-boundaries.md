# Install boundaries

## Status

Accepted for the packaging milestone. The scripts were run against a temporary home directory and stub binaries. They were not run on Hyprland.

## Decision

- `./install.sh` copies the shell into `$XDG_DATA_HOME/swiftshell` and the launcher into `~/.local/bin`.
- Settings stay in `$XDG_CONFIG_HOME/swiftshell`. Install creates them only when `settings.json` is absent. Uninstall keeps them unless `--purge-settings` is passed.
- Activation is a separate command. It may add a free `quickshell/swiftshell` symlink and a desktop entry. It does not write an autostart entry, a service unit, or a Hyprland config.
- A non-empty install directory without SwiftShell's manifest or shell id is left untouched.
- An existing launcher or desktop entry without the SwiftShell marker is left untouched.
- Package installation is optional, Arch-only, and requires `--install-deps` plus a yes answer.
- A future AUR package installs under `/usr` and does not run the user installer as root.

## Consequences

A running Noctalia or other Quickshell config keeps its files. The two bars can still overlap visually if both are started. Stopping SwiftShell is the recovery for that overlap.
