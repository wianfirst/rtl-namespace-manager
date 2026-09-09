#!/usr/bin/env python3
"""Regression checks for flat output and multi-module filenames."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1] / "tools" / "rtl_namespace.py"


class FlatOutputTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="rtl-flat-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "config.json").write_text(json.dumps({"projects": {
            p: {"source": ["src"], "namespace": p}
            for p in ("PROJA", "PROJB")}}))

    def source(self, path, content):
        target = self.root / "src" / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)

    def run_tool(self, *args):
        return subprocess.run([sys.executable, str(TOOL), "--config",
                               "config.json", "--out", "out", *args],
                              cwd=self.root, capture_output=True, text=True)

    def test_nested_multi_module_and_metadata(self):
        self.source("ip/deep/bundle.v",
                    "module first; second u_second(); endmodule\n"
                    "module second; endmodule\n")
        self.source("other/top.v", "module top; first u_first(); endmodule\n")
        before = {p: p.read_bytes() for p in (self.root / "src").rglob("*.v")}
        for mode in ("--check", "--dry-run"):
            result = self.run_tool(mode)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertFalse((self.root / "out").exists())
        result = self.run_tool()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        mapping = json.loads((self.root / "out/module_map.json").read_text())
        entries = (self.root / "out/filelist.f").read_text().splitlines()
        self.assertEqual(len(entries), 4)
        self.assertEqual(len(set(entries)), 4)
        for proj in ("PROJA", "PROJB"):
            directory = self.root / "out" / proj
            self.assertEqual({p.name for p in directory.iterdir()},
                             {proj + "__bundle.v", proj + "__top.v"})
            bundle = directory / (proj + "__bundle.v")
            self.assertIn("module " + proj + "__first;", bundle.read_text())
            self.assertIn("module " + proj + "__second;", bundle.read_text())
            self.assertIn(proj + "__second u_second", bundle.read_text())
            for module in ("first", "second"):
                entry = mapping[proj][module]
                self.assertEqual(entry["generated"], "out/" + proj + "/" + bundle.name)
                self.assertEqual(entry["new_name"], proj + "__" + module)
                self.assertIn(entry["generated"], entries)
            compiler = shutil.which("iverilog")
            if compiler:
                subprocess.run([compiler, "-g2012", "-s", proj + "__top",
                                "-o", str(self.root / (proj + ".vvp")),
                                "-f", "out/filelist.f"], cwd=self.root, check=True)
        self.assertEqual(before, {p: p.read_bytes() for p in before})

    def test_collision_rejected_before_previous_output_removed(self):
        # Distinct modules still collide if the multi-module filename matches
        # the generated filename of a single-module file in another directory.
        self.source("a/bundle.v", "module first; endmodule\nmodule second; endmodule\n")
        self.source("b/unique.v", "module bundle; endmodule\n")
        out = self.root / "out"
        out.mkdir()
        marker = out / "previous.txt"
        marker.write_text("keep previous output")
        for args in ((), ("--check",), ("--dry-run",)):
            result = self.run_tool(*args)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Output path collision", result.stdout)
            self.assertIn("src/a/bundle.v", result.stdout)
            self.assertIn("src/b/unique.v", result.stdout)
            self.assertEqual(marker.read_text(), "keep previous output")

    def test_header_filename_collision(self):
        self.source("a/defs.vh", "`define A 1\n")
        self.source("b/defs.vh", "`define B 2\n")
        result = self.run_tool()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Output path collision", result.stdout)
        self.assertFalse((self.root / "out").exists())


if __name__ == "__main__":
    unittest.main()
