import importlib.util
import os
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parents[1] / "shell/helpers"))
spec = importlib.util.spec_from_file_location("screenshotctl", Path(__file__).parents[1] / "shell/helpers/screenshotctl.py")
tools = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tools)
PNG = tools.PNG + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", 40, 30) + b"\x08\x02\x00\x00\x00" + b"\0" * 4


class Screenshots(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix="swiftshell-png-unit-")
        self.env = patch.dict(os.environ, XDG_RUNTIME_DIR=self.folder.name)
        self.env.start()

    def tearDown(self):
        self.env.stop()
        self.folder.cleanup()

    def captured(self):
        with patch.object(tools, "bounded_output", side_effect=[b"-10,20 40x30\n", PNG]):
            return tools.capture("region")

    def test_capture_is_private_png_and_does_not_change_clipboard(self):
        with patch.object(tools.subprocess, "run") as external:
            result = self.captured()
        self.assertTrue(result["ok"])
        self.assertEqual((result["width"], result["height"]), (40, 30))
        self.assertEqual(tools.read_image(result["token"]), PNG)
        self.assertEqual(tools.image_path(result["token"]).stat().st_mode & 0o777, 0o600)
        self.assertEqual(tools.cache_dir().stat().st_mode & 0o777, 0o700)
        external.assert_not_called()

    def test_copy_explicitly_sends_png(self):
        result = self.captured()
        with patch.object(tools.subprocess, "run") as copy:
            self.assertTrue(tools.copy(result["token"])["ok"])
        self.assertEqual(copy.call_args.args[0], ["wl-copy", "--type", "image/png"])
        self.assertEqual(copy.call_args.kwargs["input"], PNG)

    def test_save_preserves_png_at_literal_selected_name_atomically(self):
        result = self.captured()
        path = Path(self.folder.name) / "Shot $literal `name` & spaces.png"
        self.assertTrue(tools.save(result["token"], path.as_uri())["ok"])
        self.assertEqual(path.read_bytes(), PNG)
        self.assertEqual(list(path.parent.glob(".swiftshell-screenshot-*")), [])
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_nonlocal_and_non_png_destinations_are_refused(self):
        token = self.captured()["token"]
        for url in ("https://example.test/shot.png", "file://remote/shot.png", "file:///tmp/shot.jpeg", "file:///tmp/shot.png?x=1"):
            with self.subTest(url=url), self.assertRaises(ValueError):
                tools.save(token, url)

    def test_symlinks_and_token_traversal_are_refused(self):
        token = self.captured()["token"]
        target = Path(self.folder.name) / "real.png"
        target.write_bytes(b"untouched")
        link = Path(self.folder.name) / "link.png"
        link.symlink_to(target)
        with self.assertRaises(ValueError):
            tools.save(token, link.as_uri())
        self.assertEqual(target.read_bytes(), b"untouched")
        with self.assertRaises(ValueError):
            tools.read_image("../real")
        cache_file = tools.image_path(token)
        cache_file.unlink()
        cache_file.symlink_to(target)
        with self.assertRaises(OSError):
            tools.read_image(token)

    def test_recapture_discards_only_previous_owned_image(self):
        first = self.captured()
        with patch.object(tools, "bounded_output", side_effect=[b"-10,20 40x30\n", PNG]):
            second = tools.capture("region", previous=first["token"])
        self.assertFalse(tools.image_path(first["token"]).exists())
        self.assertTrue(tools.image_path(second["token"]).exists())
        tools.discard(second["token"])
        self.assertFalse(tools.image_path(second["token"]).exists())

    def test_cancel_keeps_previous_preview_without_capture(self):
        token = self.captured()["token"]
        with patch.object(tools, "bounded_output", side_effect=ValueError("cancelled")) as read:
            result = tools.capture("region", previous=token)
        self.assertTrue(result["cancelled"])
        self.assertEqual(read.call_count, 1)
        self.assertEqual(tools.read_image(token), PNG)

    def test_output_requires_connected_monitor_and_uses_typed_args(self):
        with patch.object(tools, "ipc", return_value='[{"name":"DP-1"}]'), patch.object(tools, "bounded_output", return_value=PNG) as read:
            result = tools.capture("output", "DP-1")
            self.assertTrue(result["ok"])
            self.assertEqual(read.call_args.args[0], ["grim", "-t", "png", "-o", "DP-1", "-"])
            with self.assertRaises(ValueError):
                tools.capture("output", "disconnected")

    def test_invalid_geometry_and_png_are_refused(self):
        with patch.object(tools, "bounded_output", return_value=b"1,2 30x40; bad") as read:
            with self.assertRaises(ValueError):
                tools.capture("region")
            self.assertEqual(read.call_count, 1)
        for image in (b"not png", tools.PNG, PNG[:16] + struct.pack(">II", 0, 30) + PNG[24:]):
            with self.subTest(image=image), self.assertRaises(ValueError):
                tools.dimensions(image)


if __name__ == "__main__":
    unittest.main()
