#!/usr/bin/env python3
"""Regression test for recursive source trees and existing project RTL."""
import json
import os
import subprocess
import sys
import tempfile


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(ROOT, "tools", "rtl_namespace.py")
CONFIG = os.path.join(ROOT, "tests", "override_namespace.yaml")
FIXTURE = os.path.join(ROOT, "tests", "override_fixture", "src", "ip", "nested")


def read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def require(condition, message):
    if not condition:
        raise AssertionError(message)
    print("[OK] " + message)


with tempfile.TemporaryDirectory(prefix="rtl-ns-override-") as temp:
    out = os.path.join(temp, "out")
    subprocess.run([sys.executable, TOOL, "--config", CONFIG, "--out", out],
                   cwd=ROOT, check=True)

    pa_dir = os.path.join(out, "PROJA", "ip", "nested")
    pb_dir = os.path.join(out, "PROJB", "ip", "nested")
    pa_existing = os.path.join(pa_dir, "PROJA_fifo.v")
    pa_ctrl = os.path.join(pa_dir, "PROJA__ctrl.v")
    pb_fifo = os.path.join(pb_dir, "PROJB__fifo.v")
    pb_ctrl = os.path.join(pb_dir, "PROJB__ctrl.v")

    require(read(pa_existing) == read(os.path.join(FIXTURE, "PROJA_fifo.v")),
            "PROJA_fifo.v is copied unchanged from a nested source directory")
    require(not os.path.exists(os.path.join(pa_dir, "PROJA__fifo.v")),
            "PROJA does not generate a second fifo implementation")
    require("module PROJA__ctrl" in read(pa_ctrl) and "PROJA_fifo u_fifo" in read(pa_ctrl),
            "PROJA control RTL binds fifo references to the existing module")
    require("module PROJB__fifo" in read(pb_fifo),
            "PROJB still generates its fifo from the generic source RTL")
    require("module PROJB__ctrl" in read(pb_ctrl) and "PROJB__fifo u_fifo" in read(pb_ctrl),
            "PROJB control RTL binds to its generated fifo")
    require(not os.path.exists(os.path.join(pb_dir, "PROJA_fifo.v")),
            "PROJA-specific RTL is not copied into PROJB")

    with open(os.path.join(out, "module_map.json"), encoding="utf-8") as f:
        module_map = json.load(f)
    require(module_map["PROJA"]["fifo"]["new_name"] == "PROJA_fifo",
            "module map records the PROJA existing-module override")
    require(module_map["PROJB"]["fifo"]["new_name"] == "PROJB__fifo",
            "module map records PROJB's generated module")

print("override regression: passed")
