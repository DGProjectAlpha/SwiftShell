#!/usr/bin/env python3
"""Demand-only, read-only cursor coordinates for an explicitly enabled fullscreen bar peek."""
import json
import math
import os
import sys
import time
from displayctl import ipc


def point(reply):
    value = json.loads(reply)
    if not isinstance(value, dict):
        raise ValueError("Cursor position is unavailable.")
    result = {}
    for axis in ("x", "y"):
        number = value.get(axis)
        if isinstance(number, bool) or not isinstance(number, (int, float)) or not math.isfinite(number) or abs(number) > 1000000:
            raise ValueError("Cursor position is unavailable.")
        result[axis] = number
    return result


def main():
    previous = None
    owner = os.getppid()
    try:
        while os.getppid() == owner:
            current = point(ipc("j/cursorpos"))
            if current != previous:
                print(json.dumps(current, separators=(",", ":")), flush=True)
                previous = current
            time.sleep(.1)
        return 0
    except (BrokenPipeError, KeyboardInterrupt):
        return 0
    except Exception:
        # Never forward compositor errors or private socket paths to the shell log.
        return 1


if __name__ == "__main__":
    sys.exit(main())
