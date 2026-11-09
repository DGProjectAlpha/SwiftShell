# Testing

Run from the repository root:

```sh
scripts/check.sh
```

The script runs static/import checks, pure JavaScript suites, Python helper and
filesystem tests, temporary-home installer tests and Qt QML suites. It selects
a Qt 6 runner, uses `tests/stubs` ahead of system QML imports and exits on failure.
Optional image/folder dialog suites run when their Qt modules are installed;
missing modules are reported explicitly. See `.github/workflows/check.yml` for
CI packages. Test dependencies include Node, Python 3, Lua compiler and Qt Quick,
QtTest, Controls, Layouts, Window and Core modules; native Quickshell is separate.

For a focused check:

```sh
python3 tests/static_check.py
node tests/bar-layouts.test.js
python3 tests/test_settingswrite.py
QML_IMPORT_PATH=tests/stubs:/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_shell_load.qml -platform offscreen
```

Adjust the system Qt import path for the distribution. The full script discovers
it automatically. The shell-load list covers every shipped QML document and
instantiates real project controls with API stand-ins. Its narrow exceptions
for unavailable native attached types are not evidence of native startup.
Installer fixtures do not install packages or modify the real HOME.

## Native validation

Native tests are opt-in. Read each runner first: some use temporary settings,
some open fixtures, and some operate the running shell or change scoped runtime
integrations. Interactive tests must run `tests/live/fullscreen_guard.py` before
creating windows, rules, sending input or changing focus. A fullscreen app on
*either* display blocks them, including client-requested fullscreen. Do not add
or use a bypass. Read-only diagnostics and genuinely windowless tests are safe
alternatives; do not reinterpret an old approval as permission for another test.

Examples, only in the appropriate isolated session:

```sh
python scripts/test-bar-settings-native.py
python scripts/test-bar-text-native.py --target-sizes --output-dir /tmp/swiftshell-bar-rendering
python tests/live/popover-close.py --help
python tests/live/settings-first-frame.py --help
```

The first two use temporary copies/settings. The latter runners target existing
UI and must be reviewed before invocation. Native regressions live in
`tests/live/`; input/protocol fixtures are in `tests/helpers/` and
`tests/protocols/`. Keep diagnostic entry points out of the packaged shell tree.

Windowless checks:

```sh
scripts/test-workspaces-native.sh --snapshot
python tests/live/settings-cold-start.py --live
```

The workspace runner copies its fixture into a temporary shell tree so imports
stay inside Quickshell’s configuration boundary. It reads snapshots and exits without dispatch
or settings access. The cold-start runner writes only temporary XDG preferences
and verifies fresh-process readback; it does not load or map UI surfaces.

## Startup and recovery

In an authorized isolated desktop session, run `scripts/launch.sh`, inspect its
log, confirm expected bars and lazy Settings load, then `scripts/stop.sh`.
Do not start a second foreground shell over a game. For the installed copy use
`swiftshell start` / `swiftshell stop`. If path selection fails, inspect
`qs list --all` and stop only the matching instance with `qs kill --id <id>`.
Noctalia is a separate executable. Never kill all Quickshell processes.

## Evidence and acceptance

[The dated native validation record](reports/native-validation.md) preserves
commands, observations, failures and remaining gates from local sessions.
[The capability matrix](capability-matrix.md) summarizes current status.
[First run](first-run.md) is the manual smoke checklist.

Passing `scripts/check.sh` proves repository checks, not compositor blur, display
scaling, focus, physical hotplug, GPU behavior, live device authentication,
reboot or lock/suspend. Mark these **NOT RUN** unless observed. Record exact
commands, versions, output scales and limitations for new native evidence.
