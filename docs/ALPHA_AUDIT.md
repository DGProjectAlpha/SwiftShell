# SwiftShell alpha audit

Baseline: `38d05df` (`origin/main` after PR #26). No newer commit was on `origin/main` when this audit was written.

This register is from reading the source, the Quickshell 0.2 FileView and Notification APIs, and the Qt modules installed in the cloud workspace. A QML file existing is not treated as the feature working. Nothing here was shown on a Hyprland session.

Classes:

- **Confirmed:** the source does this, and the effect follows from that code or from the documented API.
- **Probable:** the source can do this, and a live session is still required to see it.
- **Incomplete:** the control or page exists and does not perform the named job.
- **Hardware:** only a session can decide it.

Severity is P0 (data loss, a dead control, or a false ownership claim), P1 (a major feature that misbehaves), or P2 (polish).

## Findings

| ID | Class | Sev | Evidence | Root cause | Proposed fix | Acceptance |
|---|---|---|---|---|---|---|
| A1 | Confirmed | P0 | `SettingsStore.qml` sets `backupAdapter.document` and calls `backupFile.writeAdapter()`. The adapter's only field is `document`. Quickshell `writeAdapter()` serializes adapter properties. `migrationDecision` also sets `backupText` from `JSON.stringify(snapshot)`, and `snapshot()` is the adapter view, not the file bytes. | The backup is a wrapped, reserialized adapter. `swiftshell rollback-settings` copies that file over `settings.json`. | Write `FileView.setText()` with the original `settingsFile.text()`. Do not overwrite a backup that already restores. Leave the original file untouched until that backup save succeeds. Keep unknown keys in `extensionsJson` when migrating a parsed original. Unwrap an old `{ "document": "<json>" }` backup on restore. | Filesystem fixtures for v1, v2, v3, malformed JSON, an unknown key, and a failed backup. Rollback bytes match a compatible settings object. A malformed file is not replaced. |
| A2 | Confirmed | P0 | `BatteryModule.qml`, `MediaModule.qml`, and `TrayModule.qml` use `Theme.text`. `Theme.qml` declares `textPrimary`, `textMuted`, `panelText`, and `textHover`. It does not declare `text`. | The optional bar modules bind a missing color. | Bind `textPrimary`. Reject unknown `Theme.*` names in the static check. Instantiate each module with a populated stub. | Static check fails if `Theme.text` returns. The three modules load with and without data. |
| A3 | Confirmed | P0 | `NotificationsModel.dismiss` only updates the JS model. `NotificationHost` sets `tracked = true` and never calls `dismiss()` or `expire()`. `expireTimeout` is not read. The loader error in `shell.qml` logs a warning and leaves `notificationOwnership` at `on`. The page then shows "SwiftShell, after confirmation". Actions are stored as names and `actionsSupported` is false. | The server keeps tracked notifications after the banner is gone. The preference is treated as proof of ownership. | Call the native `dismiss()` or `expire()`. Honor `expireTimeout` (`0` stays, a negative value uses a short default). On `closed`, drop the banner. Record server state separately from the saved preference. Invoke actions when the server exposes them. | A stub notification records `dismiss` or `expire`. A failed host leaves the preference on and the page says the server is not running. Ownership still defaults off. |
| A4 | Confirmed | P0 | `tst_shell_load.qml` compiles many files and instantiates some pages. It does not build `BatteryModule`, `MediaModule`, or `TrayModule` with a non-empty model. `FileView` tests never write a temporary settings file. | The suite cannot see A1 or A2. | Add the instantiation cases and the filesystem migration tests. | `scripts/check.sh` runs both. A green stub run is still not a Hyprland startup. |
| A5 | Confirmed | P1 | `WallpaperSurface` uses one `WallpaperModel`. `noteLoaded` and `noteFinish` are idempotent after the first call because the state machine leaves `preloading` or `transitioning`. Two monitors can still both start the fade. `displayPath` prefers `WallpaperModel.shownPath` over `sourceForOutput`. `ColorAnalysis.refresh` reads `SettingsStore.wallpaperPath` and ignores the slide and the crop. `sourceSize.width` is capped and `sourceSize.height` is not. `failed` sets `slideState` to `error` until settings change. | One slideshow clock drives every output. Sampling and per-output paths do not follow the pixels on that output. A portrait decode can exceed the long-edge cap. An error has no resume. | Count one completion per generation. Let an output override stay on its own file. Sample the path that output is showing, and ignore a late response. Cap the longer edge. A failed slide returns to `waiting` on the current image. | Logic tests cover two callbacks, an output override, a stale sample, a portrait cap, and recovery from `failed`. |
| A6 | Confirmed | P1 | `Theme.textPrimary` comes from `surface.text` (manual and automatic). `Theme.panelText` comes from `palette.text`. Most controls use `panelText`. `textHover` is the hex pair `#2E2E2E` / `#D4D4D4`. | Manual and automatic text do not reach buttons, rows, or the bar. | Use `textPrimary` and `textMuted` for foreground text. Derive hover from the palette. Keep the transparent bar and the scrim. | A manual hex changes the token the bar and a settings row read. The bar color stays transparent. |
| A7 | Confirmed | P1 | `selectBarPlacement` returns the focused screen whenever `targetMonitor` is empty. `BarHost` refreshes when `outputRevision` changes. The model is a one-element list, so only one bar exists. | Empty preference follows focus and moves the bar. | Add `bar.placement`: `focused`, `primary`, or `all`. A non-empty monitor name still wins. Default stays `focused` so existing files do not change until the user picks another policy. | Logic tests place one bar, the first screen, or every screen. No connector name is hardcoded. |
| A8 | Probable | P1 | `PwObjectTracker` in `AudioSection.qml` lists the default sink and source. Stream sliders call `node.audio.volume` on other nodes. Quickshell documents node audio as invalid until the node is tracked. `TrayModule` calls `display(hostWindow, 0, 0)`. | Streams may not be bound. Menus open at the window origin. | Track stream nodes that are on screen. Pass the delegate position into `display`. | The tracker list includes the stream id. The menu call uses the delegate point, not `0, 0`. Hardware volume and menu placement stay unverified. |
| A9 | Incomplete | P1 | `DisplaysPage` disables Apply. `APPLY_REASON` says no layout call is verified. `ShortcutsPage` stores chords and does not install them. | A safe Lua transaction and a safe bind installer were not verified. Writing user Lua or calling an unproven dispatcher can break the session. | Leave both unavailable. State the blocker on the page. Do not add a control that pretends to apply. | Tests still require the disabled apply control and the sentence that saving a chord does not install it. |
| A10 | Incomplete | P1 | `NETWORK_REASON` and `BRIGHTNESS_REASON` match the Quickshell 0.2 type list: no NetworkManager type and no backlight type. This workspace has no Qt D-Bus QML module to wrap those services cleanly. Bluetooth uses `Quickshell.Bluetooth` and does not start discovery. | A shell-out helper would be a second service stack and a place for secrets. | Keep the honest unavailable pages. Do not store Wi-Fi secrets. Do not start a scan. | The pages still contain the reasons. No password field is added. |
| A11 | Incomplete | P1 | Slideshow paths are typed. `QtQuick.Dialogs` and `Qt.labs.folderlistmodel` are not installed in this workspace (`/usr/lib/x86_64-linux-gnu/qt6/qml` has neither). Jpeg and webp are displayed and not sampled. PNG sampling uses an in-process inflate of the file. | A folder picker cannot be compiled here. Claiming "no folder API exists on CachyOS" would go past this machine. | Keep path entry. Do not import a missing dialog module. Cap the PNG buffer that is already capped by `MAX_EDGE` for the decode request. | Check script does not require `QtQuick.Dialogs`. The wallpaper page still says files are chosen by path. |
| A12 | Confirmed | P1 | `packaging/aur/PKGBUILD` copies `common.sh`, `deps.sh`, `activate.sh`, `deactivate.sh`, `uninstall.sh`, and `swiftshell`. It does not copy `doctor.sh`. `scripts/swiftshell` sources `doctor.sh` from that directory. `cp -a shell` keeps `shell/assets/wallpapers/swiftshell-default-crimson.png` as a symlink to `../../../assets/...`, which is outside the package. `license` is `LicenseRef-None`. `sha256sums` is `SKIP`. The source URL assumes tag `v0.1.0`. | A packaged `swiftshell doctor` fails closed. The packaged wallpaper link dangles. No license has been chosen, and no tag exists. | Copy `doctor.sh`. Install the real PNG the way `install.sh` does. Leave the license and checksum as an explicit draft. Point the package docs at the user-local installer. | A packaging fixture lists `doctor.sh` and a regular PNG. The license line stays unchosen. |
| A13 | Probable | P1 | `NotificationHost` is one `PanelWindow` with no `screen` binding, so it follows Quickshell's default screen. History is the JS array in `NotificationsModel`, capped at 40, and it is gone after exit. Sounds are not played. | One banner stack, no disk history, no sound backend. | Keep one host and say which screen it uses. Do not add a sound control until a backend exists. Persistence stays off so the server does not promise a saved history it does not have. | The page still says sounds are not played. History cap tests stay at 40. |
| A14 | Hardware | P2 | Blur, scale 1.5, hotplug, exclusive zone, Super+Space, and real notification handoff are marked NOT RUN in `docs/capability-matrix.md`. | No Hyprland session is available in this workspace. Compositor blur would require a verified, optional, reversible rule file. That writer does not exist, and editing the user's Lua is not authorized. | Keep the scrim. Do not write Hyprland config. | The matrix does not change a hardware row to PASS. |
| A15 | Confirmed | P2 | `tst_shell_load.qml` can pass while `Theme.text` is unbound, because those modules are not created. Install tests never round-trip a settings backup through the JSON the shell writes. | The gates do not encode A1–A3. | Extend the gates in the same changes as the fixes. Add a workflow that runs the same `scripts/check.sh` commands when the runner image has the tools. Do not report a CI result that was not produced. | The local `scripts/check.sh` output is quoted with a time. CI is described as added or not run, separately. |

## What this audit will not call working

Settings rollback, bar battery/media/tray colors, notification dismissal, wallpaper sampling, display apply, shortcut installation, network, brightness, blur, and any Hyprland pixel check.

## Disposition

| ID | State |
|---|---|
| A1 | Repaired in the settings-backup change. The backup text is the original file. Rollback unwraps an old `document` string. A malformed file is not rewritten. Not run inside Quickshell on a Hyprland session. |
| A2 | Repaired. Bar modules use `textPrimary`. The static check rejects an unknown `Theme` name. Offscreen tests create the modules empty and populated. Not shown on a session. |
| A6 | Partially repaired. `panelText` and `panelMuted` now follow the surface. Hover comes from the palette. Hardware contrast is not measured. |
| A3 | Repaired in source. Dismiss and expire call the native object. The saved preference is separate from `serverState`. Not run against another notification owner. |
| A4 | Partially repaired. Battery, media, and tray modules are instantiated empty and populated. The notification host is still not instantiated, because the Wayland attached type is not stubbed. |
| A5 | Repaired in source for per-output paths, duplicate slideshow completion, failed-slide recovery, and the sample path. Folder picking and jpeg sampling stay unavailable here. Not shown on a session. |
| A7 | Repaired in source. `bar.placement` is `focused`, `primary`, or `all`. Default remains `focused`. Not shown on a session. |
| A8 | Repaired in source. Stream nodes are included in the tracker list. Tray menus use the clicked item's position. Not shown on a session. |
| A12 | Repaired in the draft package file list. `doctor.sh` and the real PNG are installed. The license is still unchosen and the package was not built. |
| A9–A11, A13–A15 | Still open. Display apply, shortcut install, network, brightness, folder scan, blur, and hardware checks stay gated. |

## Repair order

1. A1 backup bytes and filesystem tests.
2. A2 theme tokens and the singleton check.
3. A3 notification lifecycle and the ownership distinction.
4. A4 instantiation coverage, folded into those changes.
5. A5 wallpaper generation, per-output path, sampling, and the decode cap.
6. A6 shared foreground tokens.
7. A7 placement policy.
8. A8 stream tracking and tray coordinates.
9. A12 package file list and the real PNG.
10. A9, A10, A11, A13, and A14 stay gated, with the blocker left in the UI or the docs.
