#!/usr/bin/env python3
"""Real Settings and right-click visibility controls, disk readback and scoped restore."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument("--live", action="store_true", required=True)
parser.parse_args()
root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / "shell/helpers"))
from displayctl import ipc, logical_size

command = ["qs", "ipc", "-p", str(root / "shell"), "call", "swiftshell"]
config = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "swiftshell/settings.json"


def call(*args):
    return subprocess.check_output(command + list(args), text=True)


def state():
    return json.loads(call("diagnostics"))


def wait(predicate, message):
    for _ in range(140):
        if predicate():
            return
        time.sleep(0.05)
    raise AssertionError(message)


def page():
    return state()["window"]["pageGeometry"]


def window():
    return next(client for client in json.loads(ipc("j/clients")) if client.get("title") == "SwiftShell Settings" and client.get("class") == "org.quickshell")


def bar(output):
    return next(item for item in state()["barSurfaces"] if item["output"] == output)


def shown(output):
    return "search" in sum(bar(output)["modules"].values(), [])


def preferences():
    return json.loads(config.read_text())["bar"]


def overrides():
    return json.loads(preferences().get("hiddenOutputsJson", "{}"))


def dispatch(expression):
    assert ipc("eval hl.dispatch(" + expression + ")").strip() == "ok"


original = state()
saved = preferences()
prior = overrides()
monitors = json.loads(ipc("j/monitors"))
focus = next(monitor["name"] for monitor in monitors if monitor["focused"])
cursor = json.loads(ipc("j/cursorpos"))
active = json.loads(ipc("j/activewindow")).get("address")
targets = [monitor for monitor in monitors if any(item["output"] == monitor["name"] for item in original["barSurfaces"])]
backup = Path("/tmp/swiftshell-bar-visibility-settings-backup.json")
shutil.copy2(config, backup)
backup.chmod(0o600)
changed = set()

try:
    with tempfile.TemporaryDirectory(prefix="swiftshell-bar-visibility-") as directory:
        folder = Path(directory)
        for name, protocol, source, libraries in [
            ("pointer", "wlr-virtual-pointer-unstable-v1.xml", "settings-pointer.c", ["-lwayland-client"]),
            ("keyboard", "virtual-keyboard-unstable-v1.xml", "spotlight-keyboard.c", ["-lwayland-client", "-lxkbcommon"]),
        ]:
            definition = root / "tests/protocols" / protocol
            subprocess.run(["wayland-scanner", "client-header", str(definition), str(folder / (name + "-client.h"))], check=True)
            subprocess.run(["wayland-scanner", "private-code", str(definition), str(folder / (name + "-protocol.c"))], check=True)
            subprocess.run(["cc", "-Wall", "-Wextra", "-Werror", "-I" + str(folder), str(root / "tests/helpers" / source), str(folder / (name + "-protocol.c")), "-o", str(folder / name)] + libraries, check=True)

        def click(x, y, button="left"):
            x, y = round(x), round(y)
            monitor = next(monitor for monitor in monitors if monitor["x"] <= x < monitor["x"] + logical_size(monitor)[0] and monitor["y"] <= y < monitor["y"] + logical_size(monitor)[1])
            width, height = map(round, logical_size(monitor))
            args = [str(folder / "pointer"), str(x - monitor["x"]), str(y - monitor["y"]), str(width), str(height), "0", "0", monitor["name"], str(x), str(y), button]
            for _ in range(3):
                result = subprocess.run(args)
                if result.returncode == 0:
                    return
                if result.returncode != 6:  # Mapping was checked before sending any press.
                    result.check_returncode()
                time.sleep(0.15)
            result.check_returncode()

        def click_in_window(rectangle):
            client = window()
            x, y = rectangle["x"] + rectangle["width"] / 2, rectangle["y"] + rectangle["height"] / 2
            assert 0 <= x < client["size"][0] and 0 <= y < client["size"][1]
            click(client["at"][0] + x, client["at"][1] + y)

        def select_output(output):
            click_in_window(page()["selector"])
            wait(lambda: any(item["value"] == output for item in page()["selector"]["items"]), "Display choices did not open")
            item = next(item for item in page()["selector"]["items"] if item["value"] == output)
            click_in_window(item)
            wait(lambda: page()["output"] == output and not page()["selector"]["items"], "Display selection did not update")

        call("launcher", "close")
        for monitor in targets:
            call("barPanel", monitor["name"], "close")
        call("launcher", "open")
        call("launcherQuery", "module order")
        wait(lambda: any(item["kind"] == "setting-result" for item in state()["spotlight"]["card"]["providers"]), "Widget settings search result did not appear")
        subprocess.run([str(folder / "keyboard"), "enter"], check=True)
        wait(lambda: state()["category"] == "bar" and state()["window"] and state()["window"]["pageGeometry"] and not state()["windowBusy"], "Native bar settings did not open")
        assert "selector" in page(), "Activate the visibility repair build before this test"

        for monitor in targets:
            output = monitor["name"]
            select_output(output)
            before = shown(output)
            other = {item["name"]: shown(item["name"]) for item in targets if item["name"] != output}
            row = next(row for row in page()["rows"] if row["id"] == "search")
            assert row["visibility"]["shown"] == before
            changed.add(output)
            click_in_window(row["visibility"])
            wait(lambda: shown(output) != before, "Settings visibility button did not change the selected bar")
            wait(lambda: state()["settingsPersistence"] == "ready" and ("search" not in overrides()[output]) != before, "Visibility did not persist atomically")
            assert all(shown(name) == value for name, value in other.items())

            width, height = logical_size(monitor)
            surface = bar(output)
            if surface["edge"] == "top":
                x, y = monitor["x"] + width * 0.35, monitor["y"] + surface["height"] / 2
            elif surface["edge"] == "bottom":
                x, y = monitor["x"] + width * 0.35, monitor["y"] + height - surface["height"] / 2
            elif surface["edge"] == "left":
                x, y = monitor["x"] + surface["width"] / 2, monitor["y"] + height * 0.35
            else:
                x, y = monitor["x"] + width - surface["width"] / 2, monitor["y"] + height * 0.35
            click(x, y, "right")
            wait(lambda: bar(output)["menu"]["visible"] and bar(output)["menu"]["id"] == "customize", "Right-click bar menu did not open")
            geometry = bar(output)["menu"]["geometry"]
            toggle = next(item for item in geometry["items"] if item["module"] == "search")
            assert toggle["checked"] != before
            click(geometry["x"] + toggle["x"] + toggle["width"] / 2, geometry["y"] + toggle["y"] + toggle["height"] / 2)
            wait(lambda: shown(output) == before and next(row for row in page()["rows"] if row["id"] == "search")["visibility"]["shown"] == before, "Context-menu visibility did not update Settings and the actual bar")
            assert page()["output"] == output, "Monitor focus changed the editor selection"
            assert all(shown(name) == value for name, value in other.items())
            call("barPanel", output, "close")
        assert preferences().get("hiddenModules", []) == saved.get("hiddenModules", [])
        print("PASS real Settings display selector, Show/Hide, right-click bidirectional sync, atomic visibility persistence and independent bars on " + str(len(targets)) + " monitors", flush=True)
finally:
    for output in changed:
        call("barPanel", output, "close")
        if output in prior:
            call("moduleVisibility", output, " " + json.dumps(prior[output]))
        else:
            call("moduleInherit", output)
    if changed:
        wait(lambda: state()["settingsPersistence"] == "ready" and all(overrides().get(output) == prior.get(output) for output in changed), "Original visibility did not restore")
    call("launcher", "close")
    call("settings", original["category"])
    wait(lambda: not state()["windowBusy"], "Settings did not settle after restoration")
    if not original["settingsOpen"]:
        call("window", "close")
    for surface in original["barSurfaces"]:
        if surface["menu"]["visible"]:
            call("barPanel", surface["output"], surface["menu"]["id"])
    if active and any(client["address"] == active for client in json.loads(ipc("j/clients"))):
        dispatch("hl.dsp.focus({window=" + json.dumps("address:" + active) + "})")
    dispatch("hl.dsp.cursor.move({x=" + str(cursor["x"]) + ",y=" + str(cursor["y"]) + "})")
    dispatch("hl.dsp.focus({monitor=" + json.dumps(focus) + "})")
