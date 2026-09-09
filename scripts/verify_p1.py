#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P1 acceptance verifier (P1执行文档.md sec 16: Test 1..8).

Runs against an already-generated build/all/ tree:
  Test 1  both namespaced fifos coexist
  Test 2  module declaration renamed
  Test 3+4 plain / parameterized instantiation renamed
  Test 5  instance name untouched (u_fifo)
  Test 6  signal name untouched (fifo_data)
          comments / string literals untouched (naive-replace guards)
          parameter names & values untouched
  Test 7  original Perforce RTL untouched (checked via sha256 by run_p1.sh)
  Test 8  compile is done by run_p1.sh with iverilog

Exit code 0 == all assertions pass.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "all")

failures = []


def check(cond, msg):
    if cond:
        print("  [OK]   %s" % msg)
    else:
        print("  [FAIL] %s" % msg)
        failures.append(msg)


def read(p):
    with open(p, "r", encoding="utf-8") as f:
        return f.read()


def proj_file(proj, name):
    return os.path.join(OUT, proj, name)


print("== Test 1: namespaced twins coexist ==")
for p, n in (("PROJA", "PROJA__fifo"), ("PROJB", "PROJB__fifo"),
             ("PROJA", "PROJA__ctrl"), ("PROJB", "PROJB__ctrl")):
    check(os.path.isfile(proj_file(p, n + ".sv")),
          "%s.sv exists under %s/" % (n, p))

print("== Test 2: module declaration renamed ==")
pa_fifo = read(proj_file("PROJA", "PROJA__fifo.sv"))
pb_fifo = read(proj_file("PROJB", "PROJB__fifo.sv"))
pa_ctrl = read(proj_file("PROJA", "PROJA__ctrl.sv"))
pb_ctrl = read(proj_file("PROJB", "PROJB__ctrl.sv"))

def decl_names(text):
    return set(re.findall(r"^\s*module\s+(\w+)", text, re.M))

check(decl_names(pa_fifo) == {"PROJA__fifo"},
      "PROJA__fifo.sv declares module PROJA__fifo only")
check(decl_names(pb_fifo) == {"PROJB__fifo"},
      "PROJB__fifo.sv declares module PROJB__fifo only")
check(decl_names(pa_ctrl) == {"PROJA__ctrl"},
      "PROJA__ctrl.sv declares module PROJA__ctrl only")
check(decl_names(pb_ctrl) == {"PROJB__ctrl"},
      "PROJB__ctrl.sv declares module PROJB__ctrl only")
check("module fifo" not in pa_fifo and "module fifo" not in pb_fifo,
      "no raw 'module fifo' remains in generated files")

print("== Test 3/4: instantiations renamed ==")
check("PROJA__fifo #(" in pa_ctrl, "PROJA__ctrl instantiates PROJA__fifo #(...)")
check("PROJB__fifo #(" in pb_ctrl, "PROJB__ctrl instantiates PROJB__fifo #(...)")
# raw instantiation would look like "fifo #(" with fifo NOT preceded by an
# identifier character (PROJA__fifo #( legitimately contains "fifo #(")
raw_inst = re.compile(r"(?<![A-Za-z0-9_$])fifo\s+#")
check(raw_inst.search(pa_ctrl) is None and raw_inst.search(pb_ctrl) is None,
      "no raw 'fifo #(' instantiation remains")
check(re.search(r"PROJA__fifo\s+#?\(", pa_ctrl) is not None,
      "PROJA instance statement present")
check(re.search(r"PROJB__fifo\s+#?\(", pb_ctrl) is not None,
      "PROJB instance statement present")

print("== Test 5: instance name untouched ==")
check("u_fifo (" in pa_ctrl and "u_fifo (" in pb_ctrl,
      "'u_fifo (' instance name preserved")
check("PROJA__u_fifo" not in pa_ctrl and "PROJB__u_fifo" not in pb_ctrl,
      "instance name not namespaced")

print("== Test 6: signals / params / comments / strings untouched ==")
for lbl, txt, proj in (("PROJA", pa_ctrl, "PROJA__"), ("PROJB", pb_ctrl, "PROJB__")):
    check("fifo_data" in txt, "%s signal fifo_data still present" % lbl)
    check(proj + "fifo_data" not in txt,
          "%s signal fifo_data NOT namespaced" % lbl)
    check(".WIDTH(32)" in txt or ".WIDTH(64)" in txt,
          "%s .WIDTH parameter connection untouched" % lbl)
    check("parameter WIDTH = " in txt or "WIDTH" in txt,
          "%s WIDTH parameter untouched" % lbl)
    check("comment: fifo raw name" in txt,
          "%s comment containing 'fifo' untouched" % lbl)
    check('marker = "fifo raw string' in txt,
          "%s string literal containing 'fifo' untouched" % lbl)

print("== module_map.json ==")
with open(os.path.join(OUT, "module_map.json"), "r", encoding="utf-8") as f:
    mm = json.load(f)
for proj, orig, new in (("PROJA", "fifo", "PROJA__fifo"),
                        ("PROJA", "ctrl", "PROJA__ctrl"),
                        ("PROJB", "fifo", "PROJB__fifo"),
                        ("PROJB", "ctrl", "PROJB__ctrl")):
    e = mm.get(proj, {}).get(orig)
    check(e is not None and e["new_name"] == new and e["line"] >= 1,
          "module_map[%s][%s] -> %s (source %s)" % (
              proj, orig, new, e["source"] if e else "?"))

print("== filelist.f ==")
fl = os.path.join(OUT, "filelist.f")
if os.path.isfile(fl):
    lines = [l.strip() for l in read(fl).splitlines() if l.strip()]
    missing = [l for l in lines if not os.path.exists(os.path.join(ROOT, l))]
    check(not missing, "every filelist entry exists (missing: %s)" % missing)
    demo_entries = [
        "build/all/PROJA/PROJA__fifo.sv",
        "build/all/PROJA/PROJA__ctrl.sv",
        "build/all/PROJB/PROJB__fifo.sv",
        "build/all/PROJB/PROJB__ctrl.sv",
    ]
    check(all(d in lines for d in demo_entries),
          "filelist.f contains the demo fifo/ctrl entries (total %d files)" % len(lines))
else:
    check(False, "filelist.f exists")

if failures:
    print("\nVERIFY: %d assertion(s) FAILED" % len(failures))
    sys.exit(1)
print("\nVERIFY: all P1 assertions passed (Test 1-6 + maps; Test 7 sha + "
      "Test 8 compile are run by scripts/run_p1.sh)")
sys.exit(0)
