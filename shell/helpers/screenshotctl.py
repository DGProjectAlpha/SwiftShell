#!/usr/bin/env python3
"""Bounded screenshot capture, private review cache and explicit PNG export.

No clipboard content is read and images/selected filenames are never logged.
"""
import argparse
import json
import os
from pathlib import Path
import re
import signal
import shutil
import struct
import subprocess
import tempfile
from urllib.parse import unquote, urlsplit
import uuid

from desktoptools import MAX_IMAGE, bounded_output, interrupted
from displayctl import ipc

TOKEN = re.compile(r"^[0-9a-f]{32}$")
PNG = b"\x89PNG\r\n\x1a\n"


def capabilities():
    available = bool(shutil.which("grim"))
    return {"ok": True, "available": available, "region": available and bool(shutil.which("slurp")),
            "copy": bool(shutil.which("wl-copy"))}


def cache_dir():
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    if not runtime or not Path(runtime).is_absolute():
        raise ValueError("The screenshot session is unavailable.")
    directory = Path(runtime) / "swiftshell-screenshots"
    directory.mkdir(mode=0o700, exist_ok=True)
    if directory.is_symlink() or directory.stat().st_uid != os.getuid():
        raise ValueError("The screenshot session is unavailable.")
    os.chmod(directory, 0o700)
    return directory


def image_path(token):
    if not isinstance(token, str) or not TOKEN.fullmatch(token):
        raise ValueError("Take a screenshot first.")
    return cache_dir() / (token + ".png")


def dimensions(image):
    if len(image) < 33 or not image.startswith(PNG) or image[12:16] != b"IHDR":
        raise ValueError("The screenshot could not be captured.")
    width, height = struct.unpack(">II", image[16:24])
    if not 0 < width <= 32768 or not 0 < height <= 32768:
        raise ValueError("The screenshot dimensions are unavailable.")
    return width, height


def read_image(token):
    descriptor = os.open(image_path(token), os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "rb") as source:
        image = source.read(MAX_IMAGE + 1)
    if len(image) > MAX_IMAGE:
        raise ValueError("The screenshot exceeds the safe size limit.")
    dimensions(image)
    return image


def capture(mode, output="", previous=""):
    argv = ["grim", "-t", "png"]
    if mode == "region":
        try:
            geometry = bounded_output(["slurp"], 256, 120).decode("ascii").strip()
        except ValueError:
            return {"ok": False, "cancelled": True, "message": "Screenshot cancelled."}
        if not re.fullmatch(r"-?\d+,-?\d+ [1-9]\d*x[1-9]\d*", geometry):
            raise ValueError("Screen selection was cancelled.")
        argv += ["-g", geometry]
    elif mode == "output":
        monitors = json.loads(ipc("j/monitors"))
        if output not in {monitor["name"] for monitor in monitors}:
            raise ValueError("That display is no longer connected.")
        argv += ["-o", output]
    else:
        raise ValueError("Choose an area or a display.")
    image = bounded_output(argv + ["-"], MAX_IMAGE, 20)
    width, height = dimensions(image)
    token = uuid.uuid4().hex
    path = image_path(token)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(descriptor, "wb") as destination:
            destination.write(image)
        if TOKEN.fullmatch(previous or ""):
            discard(previous)
    except BaseException:
        path.unlink(missing_ok=True)
        raise
    return {"ok": True, "token": token, "imageUrl": path.as_uri(), "width": width,
            "height": height, "message": "Screenshot ready."}


def copy(token):
    subprocess.run(["wl-copy", "--type", "image/png"], input=read_image(token),
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=10)
    return {"ok": True, "message": "PNG copied. Paste it into any app that accepts images."}


def save(token, destination):
    url = urlsplit(destination)
    if url.scheme != "file" or url.netloc not in ("", "localhost") or url.query or url.fragment:
        raise ValueError("Choose a local PNG file.")
    path = Path(unquote(url.path))
    if not path.is_absolute() or path.suffix.lower() != ".png" or "\x00" in str(path):
        raise ValueError("Choose a PNG filename.")
    if path.is_symlink() or not path.parent.is_dir():
        raise ValueError("Choose a writable local folder.")
    image = read_image(token)
    descriptor, temporary = tempfile.mkstemp(prefix=".swiftshell-screenshot-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as target:
            target.write(image)
            target.flush()
            os.fsync(target.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return {"ok": True, "message": "Screenshot saved as PNG."}


def discard(token):
    image_path(token).unlink(missing_ok=True)
    return {"ok": True, "message": "Screenshot discarded."}


def main():
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("capabilities", "capture", "copy", "save", "discard"))
    parser.add_argument("--mode", default="region")
    parser.add_argument("--output", default="")
    parser.add_argument("--token", default="")
    parser.add_argument("--destination", default="")
    args = parser.parse_args()
    try:
        if args.action == "capabilities":
            result = capabilities()
        elif args.action == "capture":
            result = capture(args.mode, args.output, args.token)
        elif args.action == "copy":
            result = copy(args.token)
        elif args.action == "save":
            result = save(args.token, args.destination)
        else:
            result = discard(args.token)
    except (OSError, ValueError, UnicodeError, subprocess.SubprocessError):
        result = {"ok": False, "message": "The screenshot operation could not finish. Try again."}
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
