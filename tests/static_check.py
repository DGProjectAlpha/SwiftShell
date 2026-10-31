#!/usr/bin/env python3
"""Static checks for the SwiftShell QML tree. This does not load Qt."""

import pathlib
import re
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
    SHELL / "components" / "FlatButton.qml",
    SHELL / "components" / "CompactSlider.qml",
    SHELL / "components" / "SectionHeader.qml",
    SHELL / "components" / "ServiceStatus.qml",
    SHELL / "popovers" / "PopoverHost.qml",
    SHELL / "popovers" / "PopoverSurface.qml",
    SHELL / "popovers" / "CalendarPanel.qml",
    SHELL / "popovers" / "ControlCenterPanel.qml",
    SHELL / "popovers" / "AudioSection.qml",
    SHELL / "bar" / "ControlIndicator.qml",
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
    SHELL / "logic" / "palette.js",
    SHELL / "logic" / "theme.js",
    SHELL / "logic" / "calendar.js",
    SHELL / "logic" / "popover.js",
    SHELL / "logic" / "audio.js",
    SHELL / "logic" / "bar.js",
    SHELL / "logic" / "launcher.js",
    SHELL / "launcher" / "LauncherWindow.qml",
    SHELL / "services" / "LauncherModel.qml",
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
    ROOT / "tests" / "qml" / "tst_implicit_size.qml",
    ROOT / "tests" / "qml" / "tst_shell_load.qml",
    ROOT / "tests" / "stubs" / "Quickshell" / "qmldir",
    ROOT / "tests" / "stubs" / "Quickshell" / "Hyprland" / "qmldir",
    ROOT / "tests" / "stubs" / "Quickshell" / "Io" / "qmldir",
    ROOT / "tests" / "stubs" / "Quickshell" / "Services" / "Pipewire" / "qmldir",
    ROOT / "tests" / "stubs" / "Quickshell" / "Wayland" / "qmldir",
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


TYPE_NAME = re.compile(r"^[A-Z][A-Za-z0-9_]*$")

# QtObject has no default property. These types do, or they inherit one.
ACCEPTS_DEFAULT_CHILD = {
    "Item",
    "Rectangle",
    "Text",
    "Row",
    "Column",
    "Grid",
    "Flow",
    "MouseArea",
    "FocusScope",
    "Loader",
    "Repeater",
    "RowLayout",
    "ColumnLayout",
    "GridLayout",
    "StackLayout",
    "ShellRoot",
    "Scope",
    "Singleton",
    "PanelWindow",
    "PopupWindow",
    "Variants",
    "FileView",
    "LazyLoader",
}

NO_DEFAULT_CHILD = {"QtObject"}


def tokenize_qml(text):
    tokens = []
    index = 0
    line = 1
    length = len(text)
    while index < length:
        char = text[index]
        if char == "\n":
            line += 1
            index += 1
            continue
        if char.isspace():
            index += 1
            continue
        if char == "/" and index + 1 < length and text[index + 1] == "/":
            index += 2
            while index < length and text[index] != "\n":
                index += 1
            continue
        if char == "/" and index + 1 < length and text[index + 1] == "*":
            index += 2
            while index + 1 < length and not (text[index] == "*" and text[index + 1] == "/"):
                if text[index] == "\n":
                    line += 1
                index += 1
            index = min(index + 2, length)
            continue
        if char in ("'", '"', "`"):
            quote = char
            index += 1
            while index < length and text[index] != quote:
                if text[index] == "\\":
                    index += 2
                    continue
                if text[index] == "\n":
                    line += 1
                index += 1
            index += 1
            tokens.append(("string", "", line))
            continue
        if char.isalpha() or char == "_":
            end = index + 1
            while end < length and (text[end].isalnum() or text[end] == "_"):
                end += 1
            tokens.append(("ident", text[index:end], line))
            index = end
            continue
        if char in "{}:.":
            tokens.append((char, char, line))
            index += 1
            continue
        if char in "()[];,":
            tokens.append(("punct", char, line))
            index += 1
            continue
        index += 1
    return tokens


def qml_root_type(text):
    tokens = tokenize_qml(text)
    for index, token in enumerate(tokens):
        if token[0] != "{":
            continue
        previous = tokens[index - 1] if index else None
        if previous and previous[0] == "ident" and TYPE_NAME.match(previous[1]):
            return previous[1]
    return ""


def parent_accepts_child(parent, component_roots):
    seen = set()
    current = parent
    while current and current not in seen:
        seen.add(current)
        if current in ACCEPTS_DEFAULT_CHILD:
            return True
        if current in NO_DEFAULT_CHILD:
            return False
        current = component_roots.get(current)
        if current is None:
            return True
    return True


def nesting_errors(text, filename, component_roots):
    errors = []
    tokens = tokenize_qml(text)
    stack = []
    for index, token in enumerate(tokens):
        if token[0] == "{":
            previous = tokens[index - 1] if index else None
            type_name = ""
            assigned = False
            if previous and previous[0] == "ident" and TYPE_NAME.match(previous[1]):
                type_name = previous[1]
                before = tokens[index - 2] if index >= 2 else None
                assigned = before is not None and before[0] == ":"
            if type_name and stack and stack[-1][0] == "qml" and not assigned:
                parent = stack[-1][1]
                if not parent_accepts_child(parent, component_roots):
                    errors.append(
                        filename
                        + ":"
                        + str(previous[2])
                        + " nests "
                        + type_name
                        + " inside "
                        + parent
                        + ", which has no default object property"
                    )
            if type_name and (not stack or stack[-1][0] == "qml"):
                stack.append(("qml", type_name))
            else:
                stack.append(("script", ""))
            continue
        if token[0] == "}":
            if stack:
                stack.pop()
            else:
                errors.append(filename + ":" + str(token[2]) + " has an extra closing brace")
    return errors


# Qt 6.4 qmltypes: QQuickImplicitSizeItem marks implicitWidth and implicitHeight
# read-only. qmllint still treats the base Item property as writable, so the
# engine is the authority. Item, Rectangle, MouseArea, FocusScope, and the
# Layout types keep a writable implicit size. PopupWindow and PanelWindow are
# Quickshell windows and are not in this map.
QT_PROTOTYPE = {
    "AnimatedImage": "Image",
    "BorderImage": "ImageBase",
    "Column": "Positioner",
    "ColumnLayout": "Item",
    "Flow": "Positioner",
    "FocusScope": "Item",
    "Gradient": "QtObject",
    "Grid": "Positioner",
    "GridLayout": "Item",
    "Image": "ImageBase",
    "ImageBase": "ImplicitSizeItem",
    "ImplicitSizeItem": "Item",
    "Item": "QtObject",
    "Loader": "ImplicitSizeItem",
    "MouseArea": "Item",
    "Positioner": "ImplicitSizeItem",
    "Rectangle": "Item",
    "Repeater": "Item",
    "Row": "Positioner",
    "RowLayout": "Item",
    "StackLayout": "Item",
    "Text": "ImplicitSizeItem",
    "TextEdit": "ImplicitSizeItem",
    "TextInput": "ImplicitSizeItem",
}

READONLY_PROPS = {
    "Flow": {"effectiveLayoutDirection"},
    "Gradient": {"stops"},
    "Grid": {"effectiveLayoutDirection", "effectiveHorizontalItemAlignment"},
    "Image": {"paintedWidth", "paintedHeight"},
    "ImageBase": {"status", "progress", "frameCount"},
    "ImplicitSizeItem": {"implicitWidth", "implicitHeight"},
    "Item": {
        "activeFocus",
        "anchors",
        "baseline",
        "bottom",
        "children",
        "childrenRect",
        "data",
        "horizontalCenter",
        "layer",
        "left",
        "resources",
        "right",
        "states",
        "top",
        "transform",
        "transformOriginPoint",
        "transitions",
        "verticalCenter",
        "visibleChildren",
    },
    "Loader": {"item", "progress", "status"},
    "MouseArea": {
        "containsMouse",
        "containsPress",
        "drag",
        "mouseX",
        "mouseY",
        "pressed",
        "pressedButtons",
    },
    "Rectangle": {"border"},
    "Repeater": {"count"},
    "Row": {"effectiveLayoutDirection"},
    "Text": {
        "advance",
        "contentHeight",
        "contentWidth",
        "effectiveHorizontalAlignment",
        "fontInfo",
        "hoveredLink",
        "lineCount",
        "paintedHeight",
        "paintedWidth",
        "truncated",
    },
    "TextEdit": {
        "canPaste",
        "canRedo",
        "canUndo",
        "contentHeight",
        "contentWidth",
        "cursorRectangle",
        "effectiveHorizontalAlignment",
        "hoveredLink",
        "inputMethodComposing",
        "length",
        "lineCount",
        "paintedHeight",
        "paintedWidth",
        "preeditText",
        "selectedText",
        "selectionEnd",
        "selectionStart",
        "textDocument",
    },
    "TextInput": {
        "acceptableInput",
        "canPaste",
        "canRedo",
        "canUndo",
        "contentHeight",
        "contentWidth",
        "cursorRectangle",
        "displayText",
        "effectiveHorizontalAlignment",
        "inputMethodComposing",
        "length",
        "preeditText",
        "selectedText",
        "selectionEnd",
        "selectionStart",
    },
}


def readonly_names(type_name, component_roots):
    names = set()
    seen = set()
    current = type_name
    while current and current not in seen:
        seen.add(current)
        names.update(READONLY_PROPS.get(current, ()))
        if current in component_roots and component_roots[current]:
            current = component_roots[current]
            continue
        current = QT_PROTOTYPE.get(current)
    return names


def is_property_declaration(tokens, index):
    for back in range(1, 5):
        if index >= back and tokens[index - back][1] == "property":
            return True
    return False


def is_signal_handler(name):
    return len(name) > 2 and name.startswith("on") and name[2].isupper()


def readonly_implicit_errors(text, filename, component_roots):
    errors = []
    tokens = tokenize_qml(text)
    stack = []
    for index, token in enumerate(tokens):
        if token[0] == "{":
            previous = tokens[index - 1] if index else None
            type_name = ""
            if previous and previous[0] == "ident" and TYPE_NAME.match(previous[1]):
                type_name = previous[1]
            stack.append(type_name)
            continue
        if token[0] == "}":
            if stack:
                stack.pop()
            continue
        if token[0] != "ident":
            continue
        nxt = tokens[index + 1] if index + 1 < len(tokens) else None
        if not nxt or nxt[0] != ":":
            continue
        name = token[1]
        if name == "id" or is_signal_handler(name) or is_property_declaration(tokens, index):
            continue
        if index > 0 and tokens[index - 1][0] == ".":
            continue
        if not stack or stack[-1] == "":
            continue
        if name not in readonly_names(stack[-1], component_roots):
            continue
        errors.append(
            filename
            + ":"
            + str(token[2])
            + " assigns "
            + name
            + " on "
            + stack[-1]
            + ", which is read-only"
        )
    return errors


def check_readonly_implicit_fixtures():
    errors = []
    column = readonly_implicit_errors(
        "import QtQuick\nColumn {\n    implicitWidth: 10\n    width: implicitWidth\n}\n",
        "fixture-column.qml",
        {},
    )
    if not any("assigns implicitWidth on Column" in item for item in column):
        errors.append("readonly fixture missed a Column implicitWidth assignment")
    if any("width" in item and "assigns implicitWidth" not in item for item in column):
        errors.append("readonly fixture flagged a read of implicitWidth")
    loader = readonly_implicit_errors(
        "import QtQuick\nLoader {\n    implicitHeight: item ? item.implicitHeight : 0\n}\n",
        "fixture-loader.qml",
        {},
    )
    if not any("assigns implicitHeight on Loader" in item for item in loader):
        errors.append("readonly fixture missed a Loader implicitHeight assignment")
    item = readonly_implicit_errors(
        "import QtQuick\nItem {\n    implicitWidth: 10\n    implicitHeight: 4\n}\n",
        "fixture-item.qml",
        {},
    )
    if item:
        errors.append("readonly fixture flagged an Item: " + "; ".join(item))
    read = readonly_implicit_errors(
        "import QtQuick\nRow {\n    width: implicitWidth\n}\n",
        "fixture-read.qml",
        {},
    )
    if read:
        errors.append("readonly fixture flagged a read: " + "; ".join(read))
    handler = readonly_implicit_errors(
        "import QtQuick\nItem {\n    onImplicitWidthChanged: reposition()\n}\n",
        "fixture-handler.qml",
        {},
    )
    if handler:
        errors.append("readonly fixture flagged a signal handler: " + "; ".join(handler))
    nested = readonly_implicit_errors(
        "import QtQuick\nItem {\n    Column {\n        implicitWidth: 3\n    }\n}\n",
        "fixture-nested.qml",
        {},
    )
    if not any("assigns implicitWidth on Column" in item for item in nested):
        errors.append("readonly fixture missed a nested Column")
    custom = readonly_implicit_errors(
        "import QtQuick\nCalendarPanel {\n    implicitWidth: 10\n}\n",
        "fixture-custom.qml",
        {"CalendarPanel": "Column"},
    )
    if not any("CalendarPanel" in item for item in custom):
        errors.append("readonly fixture missed a component rooted in Column")
    safe_custom = readonly_implicit_errors(
        "import QtQuick\nCalendarPanel {\n    implicitWidth: 10\n}\n",
        "fixture-custom-item.qml",
        {"CalendarPanel": "Item"},
    )
    if safe_custom:
        errors.append("readonly fixture flagged an Item-rooted component: " + "; ".join(safe_custom))
    anchors = readonly_implicit_errors(
        "import QtQuick\nItem {\n    anchors.top: parent.top\n    anchors { top: true; left: true }\n    Rectangle { border.width: 1 }\n    onImplicitWidthChanged: reposition()\n}\n",
        "fixture-anchors.qml",
        {},
    )
    if anchors:
        errors.append("readonly fixture flagged a grouped property or handler: " + "; ".join(anchors))
    content = readonly_implicit_errors(
        "import QtQuick\nText {\n    contentWidth: 10\n}\n",
        "fixture-text.qml",
        {},
    )
    if not any("assigns contentWidth on Text" in item for item in content):
        errors.append("readonly fixture missed Text.contentWidth")
    pressed = readonly_implicit_errors(
        "import QtQuick\nMouseArea {\n    pressed: true\n    onClicked: activated()\n}\n",
        "fixture-mouse.qml",
        {},
    )
    if not any("assigns pressed on MouseArea" in item for item in pressed):
        errors.append("readonly fixture missed MouseArea.pressed")
    if any("onClicked" in item or "clicked" in item for item in pressed):
        errors.append("readonly fixture flagged a click handler: " + "; ".join(pressed))
    status = readonly_implicit_errors(
        "import QtQuick\nLoader {\n    status: Loader.Ready\n}\n",
        "fixture-status.qml",
        {},
    )
    if not any("assigns status on Loader" in item for item in status):
        errors.append("readonly fixture missed Loader.status")
    layout = readonly_implicit_errors(
        "import QtQuick\nimport QtQuick.Layouts\nRowLayout {\n    implicitWidth: 12\n    implicitHeight: 8\n}\n",
        "fixture-layout.qml",
        {},
    )
    if layout:
        errors.append("readonly fixture flagged a layout: " + "; ".join(layout))
    return errors


def qmltypes_candidates():
    found = []
    import os

    for part in os.environ.get("QML_IMPORT_PATH", "").split(":"):
        if part:
            found.append(pathlib.Path(part) / "QtQuick" / "plugins.qmltypes")
    found.extend(
        [
            pathlib.Path("/usr/lib/x86_64-linux-gnu/qt6/qml/QtQuick/plugins.qmltypes"),
            pathlib.Path("/usr/lib/qt6/qml/QtQuick/plugins.qmltypes"),
            pathlib.Path("/usr/lib64/qt6/qml/QtQuick/plugins.qmltypes"),
        ]
    )
    return [path for path in found if path.is_file()]


def qmltypes_property_readonly(text, component_name, property_name):
    marker = 'name: "' + component_name + '"'
    start = text.find(marker)
    if start < 0:
        return None
    end = text.find("\n    Component {", start)
    body = text[start:] if end < 0 else text[start:end]
    prop = 'name: "' + property_name + '"'
    at = body.find(prop)
    if at < 0:
        return None
    block = body[at:body.find("}", at)]
    return "isReadonly: true" in block and "write:" not in block


def check_qmltypes_agreement():
    paths = qmltypes_candidates()
    if not paths:
        return []
    text = paths[0].read_text(encoding="utf-8", errors="replace")
    errors = []
    expectations = {
        ("QQuickImplicitSizeItem", "implicitWidth", True),
        ("QQuickImplicitSizeItem", "implicitHeight", True),
        ("QQuickItem", "implicitWidth", False),
        ("QQuickItem", "implicitHeight", False),
        ("QQuickLoader", "status", True),
        ("QQuickText", "contentWidth", True),
    }
    for component_name, property_name, readonly in expectations:
        actual = qmltypes_property_readonly(text, component_name, property_name)
        if actual is None:
            errors.append(
                "qmltypes agreement: missing "
                + component_name
                + "."
                + property_name
                + " in "
                + str(paths[0])
            )
            continue
        if actual != readonly:
            errors.append(
                "qmltypes agreement: "
                + component_name
                + "."
                + property_name
                + " readonly="
                + str(actual)
                + ", expected "
                + str(readonly)
            )
    return errors


def check_nesting_fixtures():
    errors = []
    broken = nesting_errors("import QtQuick\nQtObject {\n    Item {}\n}\n", "fixture-broken.qml", {})
    if not any("nests Item inside QtObject" in item for item in broken):
        errors.append("nesting fixture missed a QtObject child")
    assigned = nesting_errors(
        "import QtQuick\nQtObject {\n    property Item child: Item {}\n}\n",
        "fixture-assigned.qml",
        {},
    )
    if assigned:
        errors.append("nesting fixture flagged a property object: " + "; ".join(assigned))
    scope = nesting_errors("import Quickshell\nScope {\n    Variants {\n        Item {}\n    }\n}\n", "fixture-scope.qml", {})
    if scope:
        errors.append("nesting fixture flagged a Scope child: " + "; ".join(scope))
    script = nesting_errors(
        "import QtQuick\nQtObject {\n    function run() {\n        if (true) {\n        }\n    }\n}\n",
        "fixture-script.qml",
        {},
    )
    if script:
        errors.append("nesting fixture flagged a script block: " + "; ".join(script))
    return errors


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


def project_component_names():
    return {path.stem for path in SHELL.rglob("*.qml")}


def types_from_directory(directory):
    names = {path.stem for path in directory.glob("*.qml")}
    qmldir = directory / "qmldir"
    if not qmldir.is_file():
        return names
    for line in qmldir.read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if not parts or parts[0].startswith("#"):
            continue
        if parts[0] == "singleton" and len(parts) >= 2:
            names.add(parts[1])
        elif parts[0][:1].isupper():
            names.add(parts[0])
    return names


def imported_component_names(qml_path, text):
    names = types_from_directory(qml_path.parent)
    names.discard(qml_path.stem)
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
        target = resolve_import(qml_path, spec)
        if target is None:
            continue
        if target.is_dir():
            names.update(types_from_directory(target))
        elif target.suffix == ".qml":
            names.add(target.stem)
    return names


def element_type_names(text):
    tokens = tokenize_qml(text)
    names = []
    for index, token in enumerate(tokens):
        if token[0] != "{":
            continue
        previous = tokens[index - 1] if index else None
        if previous and previous[0] == "ident" and TYPE_NAME.match(previous[1]):
            names.append(previous[1])
    return names


def unresolved_component_errors(text, qml_path, project_names):
    available = imported_component_names(qml_path, text)
    errors = []
    seen = set()
    for name in element_type_names(text):
        if name not in project_names or name in available or name in seen:
            continue
        seen.add(name)
        errors.append(str(qml_path) + " uses " + name + " without importing its module")
    return errors


def check_component_import_fixture(project_names):
    errors = []
    path = SHELL / "bar" / "FixtureBar.qml"
    broken = "import QtQuick\nPanelWindow {\n    BarLabel { text: \"Search\" }\n}\n"
    broken_errors = unresolved_component_errors(broken, path, project_names)
    if not any("BarLabel" in item for item in broken_errors):
        errors.append("component import fixture missed a BarLabel without ../components")
    fixed = "import QtQuick\nimport \"../components\"\nPanelWindow {\n    BarLabel { text: \"Search\" }\n}\n"
    fixed_errors = unresolved_component_errors(fixed, path, project_names)
    if fixed_errors:
        errors.append("component import fixture flagged an imported BarLabel: " + "; ".join(fixed_errors))
    return errors


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


def theme_property_names(text):
    names = set()
    pattern = re.compile(
        r"\bproperty\s+(?:[A-Za-z_][A-Za-z0-9_]*(?:<[^>\n]+>)?)\s+([A-Za-z_][A-Za-z0-9_]*)"
    )
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            continue
        match = pattern.search(stripped)
        if match:
            names.add(match.group(1))
    return names


def theme_reference_errors(theme_names):
    errors = []
    pattern = re.compile(r"\bTheme\.([A-Za-z_][A-Za-z0-9_]*)")
    for path in SHELL.rglob("*.qml"):
        if path.name == "Theme.qml":
            continue
        text = path.read_text(encoding="utf-8")
        for match in pattern.finditer(text):
            name = match.group(1)
            if name not in theme_names:
                errors.append(str(path.relative_to(ROOT)) + " reads missing Theme." + name)
    return errors


def main():
    errors = []
    errors.extend(check_nesting_fixtures())
    errors.extend(check_readonly_implicit_fixtures())
    errors.extend(check_qmltypes_agreement())
    project_names = project_component_names()
    errors.extend(check_component_import_fixture(project_names))
    for path in REQUIRED:
        if not path.is_file():
            errors.append("missing " + str(path.relative_to(ROOT)))

    qml_files = list(SHELL.rglob("*.qml"))
    if not qml_files:
        errors.append("no qml files found")

    component_roots = {}
    for path in qml_files:
        component_roots[path.stem] = qml_root_type(path.read_text(encoding="utf-8"))

    load_test = ROOT / "tests" / "qml" / "tst_shell_load.qml"
    if load_test.is_file():
        load_text = load_test.read_text(encoding="utf-8")
        for path in qml_files:
            relative = str(path.relative_to(ROOT))
            if relative not in load_text:
                errors.append("shell load test does not mention " + relative)

    shell_files = [ROOT / "install.sh", ROOT / "scripts" / "swiftshell"]
    shell_files.extend((ROOT / "scripts").rglob("*.sh"))

    for path in qml_files:
        text = path.read_text(encoding="utf-8")
        for token in FORBIDDEN:
            if token in text:
                errors.append(str(path.relative_to(ROOT)) + " contains " + token)
        for token in (
            "Easing.OutBounce",
            "Easing.InBounce",
            "Easing.OutInBounce",
            "Easing.InOutBounce",
            "Easing.OutElastic",
            "Easing.InElastic",
            "Easing.OutInElastic",
            "Easing.InOutElastic",
            "Easing.OutBack",
            "Easing.InBack",
            "Easing.OutInBack",
            "Easing.InOutBack",
            "SpringAnimation",
        ):
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
        if "Process {" in text:
            errors.append(str(path.relative_to(ROOT)) + " polls or spawns a process")
        if "Timer {" in text:
            slideshow = path.name == "SlideshowClock.qml" and "Math.max(60000" in text
            banner = path.name == "NotificationHost.qml" and "repeat: false" in text and "repeat: true" not in text
            if not slideshow and not banner:
                errors.append(str(path.relative_to(ROOT)) + " polls or spawns a process")
        errors.extend(nesting_errors(text, str(path.relative_to(ROOT)), component_roots))
        errors.extend(readonly_implicit_errors(text, str(path.relative_to(ROOT)), component_roots))
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
        errors.extend(unresolved_component_errors(text, path, project_names))

    popover = (SHELL / "popovers" / "PopoverSurface.qml").read_text(encoding="utf-8")
    if "clip: true" in popover:
        errors.append("PopoverSurface clips to a rectangle")
    button = (SHELL / "components" / "FlatButton.qml").read_text(encoding="utf-8")
    toggle = (SHELL / "components" / "SettingsToggle.qml").read_text(encoding="utf-8")
    if "elide: Text.ElideRight" not in button:
        errors.append("FlatButton does not elide a long label")
    if "elide: Text.ElideRight" not in toggle:
        errors.append("SettingsToggle does not elide a long label")
    package = (ROOT / "packaging" / "aur" / "PKGBUILD").read_text(encoding="utf-8")
    if "doctor.sh" not in package:
        errors.append("PKGBUILD does not install doctor.sh")
    if "assets/wallpapers/swiftshell-default-crimson.png" not in package:
        errors.append("PKGBUILD does not install the wallpaper file")
    if "LicenseRef-None" not in package:
        errors.append("PKGBUILD license changed without an owner decision")
    theme_names = theme_property_names((SHELL / "themes" / "Theme.qml").read_text(encoding="utf-8"))
    if "textPrimary" not in theme_names or "text" in theme_names:
        errors.append("Theme foreground token is missing")
    errors.extend(theme_reference_errors(theme_names))

    for path in shell_files:
        check_shell(path, errors)

    shell_qml = (SHELL / "shell.qml").read_text(encoding="utf-8")
    bar = (SHELL / "bar" / "BarWindow.qml").read_text(encoding="utf-8")
    store = (SHELL / "services" / "SettingsStore.qml").read_text(encoding="utf-8")
    theme = (SHELL / "themes" / "Theme.qml").read_text(encoding="utf-8")
    checks = {
        "shell id": "pragma ShellId swiftshell" in shell_qml,
        "shell root": "ShellRoot" in shell_qml,
        "bar host is a scope": qml_root_type((SHELL / "bar" / "BarHost.qml").read_text(encoding="utf-8")) == "Scope",
        "settings singleton type": qml_root_type(store) == "Singleton",
        "hyprland singleton type": qml_root_type((SHELL / "services" / "HyprlandModel.qml").read_text(encoding="utf-8")) == "Singleton",
        "theme singleton type": qml_root_type(theme) == "Singleton",
        "transparent bar": "Theme.transparent" in bar and "Qt.rgba(0, 0, 0, 0)" in theme,
        "ignore exclusion by default": "ExclusionMode.Ignore" in bar,
        "bar search label module": 'import "../components"' in bar,
        "bar can reserve again": "ExclusionMode.Normal" in bar and "writeZone" in bar,
        "launcher rereads desktop entries": "onApplicationsChanged" in (SHELL / "services" / "LauncherModel.qml").read_text(encoding="utf-8"),
        "launcher icon theme": "Quickshell.iconPath" in (SHELL / "launcher" / "LauncherWindow.qml").read_text(encoding="utf-8"),
        "launcher releases focus when hidden": "WlrKeyboardFocus.None" in (SHELL / "launcher" / "LauncherWindow.qml").read_text(encoding="utf-8") and "inputPlan" in (SHELL / "launcher" / "LauncherWindow.qml").read_text(encoding="utf-8"),
        "bar height follows settings": "barMetrics.height" in theme and "height: 28" in store,
        "target monitor": 'targetMonitor: ""' in store,
        "clock default": "use24Hour: true" in store,
        "reserve default": "reserveSpace: true" in store,
        "workspace default": "workspaceIds: []" in store,
        "spotlight frame": "spotlightFrame" in (SHELL / "launcher" / "LauncherWindow.qml").read_text(encoding="utf-8"),
        "launcher request toggle": "requestAction" in (SHELL / "services" / "LauncherModel.qml").read_text(encoding="utf-8"),
        "focused launcher screen": "resolveLauncherScreen" in (SHELL / "services" / "LauncherModel.qml").read_text(encoding="utf-8"),
        "bar follows placement helper": "selectBarPlacement" in (SHELL / "bar" / "BarHost.qml").read_text(encoding="utf-8"),
        "launcher is not pinned to the bar": "LauncherModel.screen = window.screen" not in bar,
        "workspace indicators can follow live ids": "indicatorItems" in bar,
        "socket dispatch": "Hyprland.dispatch" in (SHELL / "services" / "HyprlandModel.qml").read_text(encoding="utf-8"),
        "lua workspace expression": "hl.dsp.focus({ workspace = " in (SHELL / "logic" / "workspaces.js").read_text(encoding="utf-8"),
        "existing workspaces do not use activate()": ".activate()" not in (SHELL / "services" / "HyprlandModel.qml").read_text(encoding="utf-8"),
        "target screens are assigned": "function refreshTargetScreens" in (SHELL / "bar" / "BarHost.qml").read_text(encoding="utf-8") and "readonly property var targetScreens" not in (SHELL / "bar" / "BarHost.qml").read_text(encoding="utf-8"),
        "one exclusion write": "exclusionMode: reserveSpace" not in bar and "Bar.exclusionUpdate" in bar,
        "theme singleton": "singleton Theme 1.0 Theme.qml" in (SHELL / "themes" / "qmldir").read_text(encoding="utf-8"),
        "popup surface stays transparent": "surfaceFormat.opaque: false" in (SHELL / "popovers" / "PopoverHost.qml").read_text(encoding="utf-8") and "Theme.transparent" in (SHELL / "popovers" / "PopoverHost.qml").read_text(encoding="utf-8"),
        "calendar today control": 'label: "Today"' in (SHELL / "popovers" / "CalendarPanel.qml").read_text(encoding="utf-8"),
        "audio binding": "PwObjectTracker" in (SHELL / "popovers" / "AudioSection.qml").read_text(encoding="utf-8"),
        "wallpaper sampling is not claimed": "Wallpaper tint is not sampled yet." in (SHELL / "logic" / "palette.js").read_text(encoding="utf-8"),
        "focus grab dismissal": "HyprlandFocusGrab" in (SHELL / "popovers" / "PopoverHost.qml").read_text(encoding="utf-8"),
        "settings window is a floating toplevel": qml_root_type((SHELL / "settings" / "SettingsWindow.qml").read_text(encoding="utf-8")) == "FloatingWindow",
        "settings window is not a panel": "PanelWindow" not in (SHELL / "settings" / "SettingsWindow.qml").read_text(encoding="utf-8"),
        "settings window loads on demand": 'source: "settings/SettingsWindow.qml"' in shell_qml and "Loader" in shell_qml,
        "settings blur is reported unavailable": 'available: false' in (SHELL / "logic" / "capabilities.js").read_text(encoding="utf-8") and "BackgroundEffect" in (SHELL / "logic" / "capabilities.js").read_text(encoding="utf-8"),
        "wallpaper is a background layer": "WlrLayer.Background" in (SHELL / "wallpaper" / "WallpaperSurface.qml").read_text(encoding="utf-8") and "WlrKeyboardFocus.None" in (SHELL / "wallpaper" / "WallpaperSurface.qml").read_text(encoding="utf-8") and "ExclusionMode.Ignore" in (SHELL / "wallpaper" / "WallpaperSurface.qml").read_text(encoding="utf-8") and 'source: "wallpaper/WallpaperHost.qml"' in shell_qml,
        "spotlight settings opens the window": "settingsRequested" in (SHELL / "services" / "LauncherModel.qml").read_text(encoding="utf-8"),
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
