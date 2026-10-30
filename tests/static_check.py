#!/usr/bin/env python3
"""Static checks for the SwiftShell QML tree. This does not load Qt."""

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SHELL = ROOT / "shell"
SCRIPTS = ROOT / "scripts"

REQUIRED = [
    SHELL / "shell.qml",
    SHELL / "bar" / "BarHost.qml",
    SHELL / "bar" / "BarWindow.qml",
    SHELL / "bar" / "WorkspaceIndicators.qml",
    SHELL / "bar" / "ClockModule.qml",
    SHELL / "bar" / "FocusedTitle.qml",
    SHELL / "components" / "BarLabel.qml",
    SHELL / "themes" / "Theme.qml",
    SHELL / "themes" / "qmldir",
    SHELL / "services" / "SettingsStore.qml",
    SHELL / "services" / "HyprlandModel.qml",
    SHELL / "services" / "qmldir",
    SHELL / "config" / "defaults.json",
    SHELL / "logic" / "clock.js",
    SHELL / "logic" / "monitors.js",
    SHELL / "logic" / "workspaces.js",
    SHELL / "logic" / "windows.js",
    SHELL / "logic" / "settings.js",
    SCRIPTS / "launch.sh",
    SCRIPTS / "stop.sh",
    SCRIPTS / "install.sh",
    SCRIPTS / "swiftshell",
    SCRIPTS / "lib" / "common.sh",
    SCRIPTS / "lib" / "deps.sh",
    SCRIPTS / "lib" / "activate.sh",
    SCRIPTS / "lib" / "deactivate.sh",
    SCRIPTS / "lib" / "uninstall.sh",
    ROOT / "install.sh",
    ROOT / "docs" / "install.md",
    ROOT / "packaging" / "README.md",
    ROOT / "packaging" / "aur" / "PKGBUILD",
]

FORBIDDEN = (
    "hyprctl",
    "pkill",
    "killall",
    "sudo",
    "systemctl",
    "binds.lua",
    "monitors.lua",
    "decorations.lua",
    ".config/hypr",
    "quickshell/noctalia",
    "QtQuick.Controls",
)


def scan_qml(text):
    line_comment = False
    block_comment = False
    quote = ""
    escaped = False
    depth = 0
    paren = 0
    for index, char in enumerate(text):
        nxt = text[index + 1] if index + 1 < len(text) else ""
        if line_comment:
            if char == "\n":
                line_comment = False
            continue
        if block_comment:
            if char == "*" and nxt == "/":
                block_comment = False
            continue
        if quote:
            if escaped:
                escaped = False
                continue
            if char == "\\":
                escaped = True
                continue
            if char == quote:
                quote = ""
            continue
        if char == "/" and nxt == "/":
            line_comment = True
            continue
        if char == "/" and nxt == "*":
            block_comment = True
            continue
        if char in ("'", '"', "`"):
            quote = char
            continue
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
        elif char == "(":
            paren += 1
        elif char == ")":
            paren -= 1
        if depth < 0 or paren < 0:
            return depth, paren, True
    return depth, paren, False


def resolve_import(qml_path, spec):
    if spec.startswith("root:"):
        return None
    base = qml_path.parent
    target = (base / spec).resolve()
    if target.is_dir() and ((target / "qmldir").is_file() or any(target.glob("*.qml"))):
        return target
    if target.suffix == ".js" and target.is_file():
        return target
    if target.with_suffix(".qml").is_file():
        return target.with_suffix(".qml")
    return None


def shell_code(text):
    lines = []
    for line in text.splitlines():
        in_single = False
        in_double = False
        out = []
        for char in line:
            if char == "'" and not in_double:
                in_single = not in_single
            elif char == '"' and not in_single:
                in_double = not in_double
            elif char == "#" and not in_single and not in_double:
                break
            out.append(char)
        lines.append("".join(out))
    return lines


def check_shell(path, errors):
    relative = str(path.relative_to(ROOT))
    for line in shell_code(path.read_text(encoding="utf-8")):
        for token in (
            "hyprctl dispatch",
            "hyprctl keyword",
            "hyprctl reload",
            "pkill",
            "killall",
            "systemctl",
            "binds.lua",
            "monitors.lua",
            "decorations.lua",
            ".config/hypr",
            "quickshell/noctalia",
        ):
            if token in line:
                errors.append(relative + " contains " + token)
        if "hyprctl" in line and "hyprctl version" not in line and "command -v hyprctl" not in line:
            errors.append(relative + " contains hyprctl outside a version probe")
        if "sudo" in line and not (path.name == "deps.sh" and "pacman -S" in line):
            errors.append(relative + " contains sudo")


def main():
    errors = []
    for path in REQUIRED:
        if not path.is_file():
            errors.append("missing " + str(path.relative_to(ROOT)))

    qml_files = list(SHELL.rglob("*.qml"))
    if not qml_files:
        errors.append("no qml files found")

    shell_files = [ROOT / "install.sh", ROOT / "scripts" / "swiftshell"]
    shell_files.extend((ROOT / "scripts").rglob("*.sh"))

    for path in qml_files:
        text = path.read_text(encoding="utf-8")
        for token in FORBIDDEN:
            if token in text:
                errors.append(str(path.relative_to(ROOT)) + " contains " + token)
        depth, paren, negative = scan_qml(text)
        if negative or depth != 0 or paren != 0:
            errors.append(
                str(path.relative_to(ROOT))
                + " has unbalanced structure (braces "
                + str(depth)
                + ", parentheses "
                + str(paren)
                + ")"
            )
        if "Timer {" in text or "Process {" in text:
            errors.append(str(path.relative_to(ROOT)) + " polls or spawns a process")
        for line in text.splitlines():
            stripped = line.strip()
            if not stripped.startswith("import "):
                continue
            if '"' not in stripped and "'" not in stripped:
                continue
            quote = '"' if '"' in stripped else "'"
            spec = stripped.split(quote)[1]
            if spec.startswith("Qt") or spec.startswith("Quickshell"):
                continue
            if resolve_import(path, spec) is None:
                errors.append(str(path.relative_to(ROOT)) + " has unresolved import " + spec)

    for path in shell_files:
        check_shell(path, errors)

    shell_qml = (SHELL / "shell.qml").read_text(encoding="utf-8")
    bar = (SHELL / "bar" / "BarWindow.qml").read_text(encoding="utf-8")
    store = (SHELL / "services" / "SettingsStore.qml").read_text(encoding="utf-8")
    theme = (SHELL / "themes" / "Theme.qml").read_text(encoding="utf-8")
    checks = {
        "shell id": "pragma ShellId swiftshell" in shell_qml,
        "shell root": "ShellRoot" in shell_qml,
        "transparent bar": "Theme.transparent" in bar and "Qt.rgba(0, 0, 0, 0)" in theme,
        "ignore exclusion by default": "ExclusionMode.Ignore" in bar,
        "bar height": "barHeight: 28" in theme,
        "target monitor": 'targetMonitor: "HDMI-A-1"' in store,
        "clock default": "use24Hour: true" in store,
        "reserve default": "reserveSpace: false" in store,
        "workspace default": "workspaceIds: [4, 5, 6]" in store,
        "socket dispatch": "Hyprland.dispatch" in (SHELL / "services" / "HyprlandModel.qml").read_text(encoding="utf-8"),
        "theme singleton": "singleton Theme 1.0 Theme.qml" in (SHELL / "themes" / "qmldir").read_text(encoding="utf-8"),
    }
    for name, ok in checks.items():
        if not ok:
            errors.append("missing expected prototype marker: " + name)

    if errors:
        for error in errors:
            print("static check: " + error, file=sys.stderr)
        return 1

    print("static checks passed (" + str(len(qml_files)) + " qml files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
