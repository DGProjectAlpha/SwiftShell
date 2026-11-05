#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("performancectl", Path(__file__).resolve().parents[1] / "shell/helpers/performancectl.py")
performance = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(performance)


class PerformanceTests(unittest.TestCase):
    def test_cpu_guest_not_counted_twice(self):
        self.assertEqual(performance.cpu_counters("cpu 100 20 30 400 10 5 2 3 80 10\ncpu0 1 2 3 4"), (570, 410))
        self.assertEqual(performance.cpu_usage((1000, 500), (1200, 650)), 25)

    def test_first_invalid_and_reset_cpu_are_unknown(self):
        self.assertIsNone(performance.cpu_usage(None, (100, 50)))
        self.assertIsNone(performance.cpu_usage((100, 50), (90, 40)))
        self.assertIsNone(performance.cpu_usage((100, 50), (110, 40)))
        self.assertIsNone(performance.cpu_counters("cpu 1 2 broken 4"))
        self.assertIsNone(performance.cpu_counters("cpu0 1 2 3 4"))

    def test_memory_uses_available_instead_of_free(self):
        result = performance.memory("MemTotal: 100000 kB\nMemFree: 1000 kB\nMemAvailable: 75000 kB\nCached: 74000 kB")
        self.assertEqual(result, {"usage": 25, "usedBytes": 25600000, "totalBytes": 102400000})
        self.assertIsNone(performance.memory("MemTotal: 1000 kB")["usage"])
        self.assertIsNone(performance.memory("MemTotal: 1000 kB\nMemAvailable: 2000 kB")["usage"])

    def test_only_cpu_and_memory_sensors_are_labeled(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for index, (name, values) in enumerate([("coretemp", [42000, 47000]), ("nvme", [61000]), ("jc42", [39000]), ("acpitz", [80000])]):
                device = root / ("hwmon" + str(index))
                device.mkdir()
                (device / "name").write_text(name)
                for sensor, value in enumerate(values, 1):
                    (device / ("temp" + str(sensor) + "_input")).write_text(str(value))
            self.assertEqual(performance.temperatures(root), {"cpu": 47, "ram": 39})
            (root / "hwmon0/temp2_input").write_text("9999999")
            self.assertEqual(performance.temperatures(root)["cpu"], 42)

    def test_observed_rtx4070_csv_and_unsupported_fields(self):
        rows = performance.nvidia_rows("NVIDIA GeForce RTX 4070, 22, 1255, 12282, 40\nOther GPU, [N/A], [N/A], [N/A], [N/A]")
        self.assertEqual(rows[0]["usage"], 22)
        self.assertEqual(rows[0]["temperature"], 40)
        self.assertEqual(rows[0]["usedBytes"], 1255 * 1048576)
        self.assertIsNone(rows[1]["usage"])
        self.assertIsNone(rows[1]["temperature"])
        self.assertEqual(performance.nvidia_rows("malformed"), [])

    def test_gpu_timeout_has_truthful_empty_fallback(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(performance.subprocess, "run", side_effect=subprocess.TimeoutExpired("nvidia-smi", 1.5)):
            self.assertEqual(performance.gpu_snapshot(directory, "nvidia-smi"), [])

    def test_amd_kernel_counters(self):
        with tempfile.TemporaryDirectory() as directory:
            device = Path(directory) / "card0/device"
            device.mkdir(parents=True)
            for name, value in {"gpu_busy_percent": "35", "mem_info_vram_used": "1024", "mem_info_vram_total": "4096", "vendor": "0x1002"}.items():
                (device / name).write_text(value)
            result = performance.gpu_snapshot(directory)
            self.assertEqual(result[0]["name"], "AMD GPU")
            self.assertEqual(result[0]["usage"], 35)
            self.assertEqual(result[0]["usedBytes"], 1024)
            self.assertIsNone(result[0]["temperature"])

    def test_absent_data_is_not_zero_usage(self):
        with tempfile.TemporaryDirectory() as directory:
            sampler = performance.Sampler(directory, directory, directory)
            result = sampler.sample()
            self.assertIsNone(result["cpu"]["usage"])
            self.assertIsNone(result["memory"]["usage"])
            self.assertEqual(result["gpus"], [])


if __name__ == "__main__":
    unittest.main()
