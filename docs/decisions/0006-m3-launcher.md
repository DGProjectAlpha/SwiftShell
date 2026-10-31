# M3 launcher

Discovery, icons, and the empty-catalog snapshot described below were corrected in `0007-m3-stabilization.md` after the launcher was opened on CachyOS. This note is the original M3 decision.

The launcher is a separate layer-shell window. It is not a second bar and it does not register Super+Space.

Discovery uses Quickshell 0.2 `DesktopEntries.applications`, which already omits Hidden and NoDisplay application entries. The snapshot is taken when the launcher opens and released when it closes. Search runs on that snapshot. The Node check ranked 400 names in 1.96 ms. That number is not a frame time on the NVIDIA session.

`DesktopEntry.execute()` is the launch path. The search string is not appended to the command and is not passed through a shell. Power actions use fixed `loginctl` argument lists and require a second confirmation. They were not executed in the cloud.

Recent entries are at most eight desktop ids, written with an atomic file replace, and only after a launch from this launcher. Pinned ids are `launcher.pinnedIds` in the settings file. Missing icons that are not absolute paths are monograms. Icon theme lookup is not implemented.

The window was not opened with `qs`. Application launch, focus return, and the Super+Space handoff are hardware checks. The handoff procedure is `docs/launcher-shortcut.md`. Applying it is a manual edit with a backup. This change does not apply it.
