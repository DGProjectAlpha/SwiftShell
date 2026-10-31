# M0/M1 boundaries

## Status

Accepted for the first prototype. Local rendering is still unproven.

## Context

The first shell has to be launchable beside the working Noctalia session. The product spec also wants a real transparent bar on HDMI-A-1 with workspaces 4–6 and a clock. A cloud agent cannot see that session.

## Decision

- The prototype lives in `shell/` and starts only through `qs --path`.
- The default output is HDMI-A-1. Other screens get no window.
- The bar color is transparent and the height token is 28 logical pixels.
- Workspace state comes from Quickshell's Hyprland object model. Activation uses the workspace object or one `dispatch` string. No `hyprctl` process is started.
- `bar.reserveSpace` originally defaulted to false so the bar would not reserve the top edge while Noctalia was still responsible for that output. `0007-m3-stabilization.md` changes the default for a new settings file to true and keeps false as the overlay. An existing settings file is not rewritten.
- Keyboard shortcuts are unchanged. The bar is not focusable.
- Settings are a separate JSON file under the generic XDG config directory. A failed load does not rewrite an existing file.
- Logic that does not need a compositor lives in `shell/logic` and has Node tests. QML is checked with a Python structure scan until `qmllint` is available.

## Consequences

A first launch can overlap Noctalia visually if Noctalia already draws on HDMI-A-1. Stopping this prototype is the recovery. The overlap is not a config change.

The next milestone should not start until this bar has been loaded on the target machine and the log, screen match, and shutdown path have been recorded.
