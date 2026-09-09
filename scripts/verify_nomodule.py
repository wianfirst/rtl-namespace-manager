#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Regression: .v files that contain only `define text (no module declaration,
content like a .vh header) must NOT make the generator fail; they are copied
byte-for-byte into each project tree.

Run:  python3 scripts/verify_nomodule.py
Exit 0 == all assertions pass.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIXTURE = os.path.join(ROOT, "tests", "nomodule_fixture")
CFG = os.path.join(FIXTURE, "namespace.yaml")
SRC = os.path.join(FIXTURE, "src", "rtl")
TOOL = os.path.join(ROOT, "tools", "rtl_namespace.py")

failures = []


def check(cond, msg):
    print(("  [OK]   " if cond else "  [FAIL] ") + msg)
    if not cond:
        failures.append(msg)


tmp = tempfile.mkdtemp(prefix="rtl-ns-nomodule-")
out = os.path.join(tmp, "out")
try:
    print("== run generator on no-module fixture ==")
    # config 'source:' paths are relative to the invocation cwd, so run the
    # tool with the fixture dir as cwd (like scripts/verify_overrides.py)
    r = subprocess.run([sys.executable, TOOL, "--config", CFG, "--out", out],
                       capture_output=True, text=True, cwd=FIXTURE)
    print("exit=%d" % r.returncode)
    if r.returncode != 0:
        print(r.stdout[-3000:])
        print(r.stderr[-3000:])
    check(r.returncode == 0, "generator exits 0 (no KeyError/traceback)")

    def rd(p):
        with open(p, "r", encoding="utf-8") as f:
            return f.read()

    print("== namespaced modules still generated ==")
    for proj in ("PROJA", "PROJB"):
        ff = os.path.join(out, proj, "%s__fifo.v" % proj)
        tt = os.path.join(out, proj, "%s__top.v" % proj)
        check(os.path.isfile(ff) and "module %s__fifo" % proj in rd(ff),
              "%s fifo namespaced" % proj)
        check(os.path.isfile(tt) and "%s__fifo #(" % proj in rd(tt),
              "%s top references namespaced fifo" % proj)

    print("== header .v (define-only) handled ==")
    orig = rd(os.path.join(SRC, "rtl_defs.v"))
    for proj in ("PROJA", "PROJB"):
        p = os.path.join(out, proj, "rtl_defs.v")
        check(os.path.isfile(p), "%s keeps rtl_defs.v passthrough copy" % proj)
        check(os.path.isfile(p) and rd(p) == orig,
              "%s rtl_defs.v byte-identical (defines intact)" % proj)

    print("== module_map.json has no entry for header file ==")
    mm = json.load(open(os.path.join(out, "module_map.json")))
    leaked = [proj for proj in ("PROJA", "PROJB")
              if any("rtl_defs" in e.get("generated", "") or
                     "rtl_defs" in e.get("source", "")
                     for e in mm.get(proj, {}).values())]
    check(not leaked, "header file absent from module_map (leaked=%s)" % leaked)

    print("== filelist.f includes header copies once per project ==")
    fl = rd(os.path.join(out, "filelist.f"))
    for proj in ("PROJA", "PROJB"):
        check(fl.count("%s/rtl_defs.v" % proj) == 1,
              "filelist lists %s/rtl_defs.v exactly once" % proj)
finally:
    shutil.rmtree(tmp, ignore_errors=True)

if failures:
    print("\nVERIFY_NOMODULE: %d assertion(s) FAILED" % len(failures))
    sys.exit(1)
print("\nVERIFY_NOMODULE: passed")
sys.exit(0)
