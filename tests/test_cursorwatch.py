#!/usr/bin/env python3
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'shell/helpers'))
import cursorwatch


class CursorWatchTests(unittest.TestCase):
    def test_real_logical_coordinate_shape_is_bounded(self):
        self.assertEqual(cursorwatch.point('{"x":2700,"y":721}'),{'x':2700,'y':721})
        self.assertEqual(cursorwatch.point('{"x":-100,"y":-20}'),{'x':-100,'y':-20})

    def test_invalid_coordinates_do_not_reach_the_peek_model(self):
        for value in [{},[],{'x':True,'y':0},{'x':'0','y':0},{'x':float('nan'),'y':0},{'x':1000001,'y':0}]:
            with self.assertRaises(ValueError):cursorwatch.point(json.dumps(value))

    def test_parent_exit_stops_sampling_without_waiting_for_cursor_motion(self):
        with patch.object(cursorwatch.os,'getppid',side_effect=[42,42,1]),patch.object(cursorwatch,'ipc',return_value='{"x":0,"y":0}') as ipc,patch.object(cursorwatch.time,'sleep'),patch('builtins.print'):
            self.assertEqual(cursorwatch.main(),0)
            ipc.assert_called_once_with('j/cursorpos')


if __name__=='__main__':unittest.main()
