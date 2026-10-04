import json
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time
import unittest

import panel


class PanelTest(unittest.TestCase):
    def test_each_output_and_invalid_state(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state"
            path.write_text("panel * 1 monocle 1.60\npanel DP-1 1 monocle 1.60\npanel HDMI-A-1 2 grid 0.80\n")
            self.assertEqual(panel.status(path, "DP-1")["text"], "Monocle")
            self.assertEqual(panel.status(path, "HDMI-A-1")["text"], "Grid 0.80:1")
            self.assertEqual(panel.status(path, "*")["text"], "Monocle")
            path.write_text("panel DP-1 1 grid nan\npanel DP-1 1 grid 999\npanel DP-1 1 garbage 1.60\n")
            self.assertEqual(panel.status(path, "DP-1")["text"], "Grid 1.20:1")

    def test_atomic_replacement_updates_without_polling(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "hypr-desktop-panel-test.state"
            path.write_text("panel DP-1 1 grid 1.60\npanel HDMI-A-1 2 monocle 1.60\n")
            env = dict(os.environ, XDG_RUNTIME_DIR=directory,
                       HYPRLAND_INSTANCE_SIGNATURE="panel-test", WAYBAR_OUTPUT_NAME="DP-1")
            process = subprocess.Popen([sys.executable, str(Path(panel.__file__))], env=env,
                                       stdout=subprocess.PIPE, text=True)
            try:
                self.assertTrue(select.select([process.stdout], [], [], 2)[0])
                self.assertEqual(json.loads(process.stdout.readline())["text"], "Grid 1.60:1")
                replacement = path.with_suffix(".tmp")
                replacement.write_text("panel DP-1 1 grid 1.60\npanel HDMI-A-1 2 tabbed 1.60\n")
                replacement.replace(path)
                self.assertFalse(select.select([process.stdout], [], [], 0.1)[0], "unrelated output must not refresh this label")
                replacement.write_text("panel DP-1 3 grid 1.20\npanel HDMI-A-1 2 tabbed 1.60\n")
                start = time.monotonic()
                replacement.replace(path)
                self.assertTrue(select.select([process.stdout], [], [], 0.5)[0], "update waited for polling")
                self.assertEqual(json.loads(process.stdout.readline())["text"], "Grid 1.20:1")
                self.assertLess(time.monotonic() - start, 0.5)
            finally:
                process.terminate()
                process.wait(timeout=2)
                process.stdout.close()


if __name__ == "__main__":
    unittest.main()
