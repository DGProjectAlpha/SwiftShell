#!/usr/bin/env python3
"""Read-only Linux hardware sampler. No process names, paths or history are emitted."""
import argparse
import csv
import json
import math
from pathlib import Path
import shutil
import subprocess
import time


def number(value, minimum=0, maximum=None):
    try:
        result = float(value)
        if not math.isfinite(result) or result < minimum or (maximum is not None and result > maximum):
            return None
        return result
    except (TypeError, ValueError):
        return None


def read(path):
    try:
        return Path(path).read_text().strip()
    except (OSError, UnicodeError):
        return ""


def cpu_counters(text):
    for line in text.splitlines():
        fields = line.split()
        if fields and fields[0] == "cpu":
            values = [number(value) for value in fields[1:9]]
            if len(values) < 4 or any(value is None for value in values):
                return None
            # guest/guest_nice are already included in user/nice. Never double-count.
            idle = values[3] + (values[4] if len(values) > 4 else 0)
            return sum(values), idle
    return None


def cpu_usage(previous, current):
    if previous is None or current is None:
        return None
    elapsed, idle = current[0] - previous[0], current[1] - previous[1]
    if elapsed <= 0 or idle < 0:
        return None
    return round(max(0, min(100, 100 * (elapsed - idle) / elapsed)), 1)


def memory(text):
    values = {}
    for line in text.splitlines():
        fields = line.split()
        if len(fields) >= 2:
            values[fields[0].rstrip(":")] = number(fields[1])
    total, available = values.get("MemTotal"), values.get("MemAvailable")
    if not total or available is None or available > total:
        return {"usage": None, "usedBytes": None, "totalBytes": None}
    used = total - available
    return {"usage": round(100 * used / total, 1), "usedBytes": int(used * 1024), "totalBytes": int(total * 1024)}


def temperatures(hwmon):
    cpu, ram = [], []
    for device in Path(hwmon).glob("hwmon*"):
        name = read(device / "name")
        target = cpu if name in ("coretemp", "k10temp", "zenpower", "cpu_thermal") else ram if name in ("jc42", "spd5118", "spd5") else None
        if target is None:
            continue
        for sensor in device.glob("temp*_input"):
            value = number(read(sensor), minimum=-40000, maximum=150000)
            if value is not None:
                target.append(value / 1000)
    return {"cpu": max(cpu) if cpu else None, "ram": max(ram) if ram else None}


def nvidia_rows(text):
    devices = []
    for fields in csv.reader(text.splitlines()):
        if len(fields) != 5:
            continue
        name, usage, used, total, temperature = (field.strip() for field in fields)
        used, total = number(used), number(total)
        devices.append({"name": name[:120], "usage": number(usage, maximum=100),
                        "usedBytes": int(used * 1048576) if used is not None else None,
                        "totalBytes": int(total * 1048576) if total else None,
                        "temperature": number(temperature, minimum=-40, maximum=150)})
    return devices


def gpu_snapshot(drm="/sys/class/drm", nvidia=None):
    if nvidia:
        try:
            result = subprocess.run([nvidia, "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu", "--format=csv,noheader,nounits"],
                                    capture_output=True, text=True, timeout=1.5, check=False)
            if result.returncode == 0:
                rows = nvidia_rows(result.stdout)
                if rows:
                    return rows
        except (OSError, subprocess.TimeoutExpired):
            pass
    devices = []
    for card in Path(drm).glob("card[0-9]*"):
        if "-" in card.name:
            continue
        path = card / "device"
        usage = number(read(path / "gpu_busy_percent"), maximum=100)
        if usage is None:
            continue
        used, total = number(read(path / "mem_info_vram_used")), number(read(path / "mem_info_vram_total"))
        temps = [number(read(sensor), minimum=-40000, maximum=150000) for sensor in path.glob("hwmon/hwmon*/temp1_input")]
        temps = [value / 1000 for value in temps if value is not None]
        devices.append({"name": "AMD GPU" if read(path / "vendor") == "0x1002" else "GPU", "usage": usage,
                        "usedBytes": int(used) if used is not None else None, "totalBytes": int(total) if total else None,
                        "temperature": max(temps) if temps else None})
    return devices


class Sampler:
    def __init__(self, proc="/proc", hwmon="/sys/class/hwmon", drm="/sys/class/drm", nvidia=None):
        self.proc, self.hwmon, self.drm, self.nvidia = Path(proc), hwmon, drm, nvidia
        self.previous = None

    def sample(self):
        counters = cpu_counters(read(self.proc / "stat"))
        usage = cpu_usage(self.previous, counters)
        self.previous = counters
        temperature = temperatures(self.hwmon)
        ram = memory(read(self.proc / "meminfo"))
        ram["temperature"] = temperature["ram"]
        return {"ok": True, "cpu": {"usage": usage, "temperature": temperature["cpu"]},
                "memory": ram, "gpus": gpu_snapshot(self.drm, self.nvidia)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--watch", action="store_true")
    parser.add_argument("--interval", type=float, default=2)
    args = parser.parse_args()
    if not math.isfinite(args.interval) or not 1 <= args.interval <= 60:
        parser.error("interval must be between 1 and 60 seconds")
    sampler = Sampler(nvidia=shutil.which("nvidia-smi"))
    try:
        while True:
            started = time.monotonic()
            print(json.dumps(sampler.sample(), separators=(",", ":"), allow_nan=False), flush=True)
            if not args.watch:
                break
            time.sleep(max(0.05, args.interval - (time.monotonic() - started)))
    except (BrokenPipeError, KeyboardInterrupt):
        pass


if __name__ == "__main__":
    main()
