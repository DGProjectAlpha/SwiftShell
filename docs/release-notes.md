# SwiftShell alpha

This tree is an installable alpha. It is not stable. Cloud checks do not show a Hyprland session. The next useful step is to install it, start it beside Noctalia, and debug what you see.

Revert any milestone by reverting its merge commit. The merges below are on `main`.

| Milestone | Pull request | Merge | What landed |
|---|---|---|---|
| M3.2 Spotlight placement | #10 | `bce0c31` | Centered launcher on the focused monitor, in source |
| M4.0 Settings window | #11 | `1847c22` | One floating settings window |
| M4.1 Settings navigation | #12 | `db4570d` | Search, undo, and appearance controls |
| M4.2 Bar size | #13 | `ef3a193` | Height 22–52 and module order |
| M4.3 Blur report | #14 | `3afff8a` | Blur reported unavailable; surfaces keep the scrim |
| M4.4 Wallpaper | #15 | `6e46d15` | One background layer per output |
| M4.5 Slideshow and contrast | #16 | `dd1e7f2` | Slide list, png top-edge contrast, manual colors |
| M4.6 Displays | #17 | `6d9a0d1` | Arrangement preview. Apply stays off |
| M4.7 Shortcuts | #18 | `b5acb9e` | Preferred chords stored. Binds are not installed |
| M5.1 Audio, media, tray | #19 | `f3b605f` | PipeWire, MPRIS, and tray items behind loaders |
| M5.2 Services | #20 | `4034ac3` | Bluetooth, battery, and confirmed power actions |
| M6.1 Notifications | #21 | `10795ef` | Ownership stays off until a second confirmation |
| M6.2 Notification rules | #22 | `3c42fb5` | Show, quiet, and hide. Sounds are not played |
| M7.1 Polish | #23 | `395cd39` | Long labels elide. The radius is not a blur mask |
| M7.2 Bounds | #24 | `07162f2` | 24 search rows, 4 banners, 40 history rows, high contrast |
| M8.1 Doctor | #25 | `407668a` | Read-only doctor and settings-only rollback |

Times above are the merge commits. The later ones were merged on 30 Oct 2026 between 9:04 PM and 10:25 PM America/New_York.

## Install

```sh
git clone https://github.com/DGProjectAlpha/SwiftShell.git
cd SwiftShell
./install.sh
swiftshell doctor
swiftshell activate
swiftshell start
```

`./install.sh` does not edit Hyprland or Noctalia. If both shells draw on the same output, set `bar.reserveSpace` to `false` in `~/.config/swiftshell/settings.json` before judging the layout. Stop SwiftShell with `swiftshell stop`. Remove it with `swiftshell uninstall`. Settings stay unless you pass `--purge-settings`.

## What this alpha does not claim

- Backdrop blur. Panels are a translucent scrim. The corner radius is not a rounded blur mask.
- Network management or hardware brightness. Those pages say why.
- Notification sounds.
- Applying a display layout.
- Installing a shortcut. Super+Space stays on the compositor until `docs/launcher-shortcut.md` is applied by hand.
- A scanned Bluetooth inquiry. The page can use devices the adapter already knows.
- Jpeg and webp contrast sampling. They can still be shown as wallpaper.
- A folder scan for the slideshow. Slides are paths you add.
- Stable behavior on a live session. That has not been run for this alpha.
