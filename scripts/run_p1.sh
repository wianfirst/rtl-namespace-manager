#!/usr/bin/env bash
# P1 driver: dry-run -> generate -> check -> verify -> compile (iverilog).
# Intended to run inside WSL Ubuntu against /mnt/d/ds_harness (this repo).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
echo "== workdir: $(pwd) =="

echo
echo "########## STEP 0: hash original RTL (must stay untouched) ##########"
find src -type f \( -name '*.sv' -o -name '*.v' \) | sort | xargs sha256sum > /tmp/p1_src_before.sha
cat /tmp/p1_src_before.sha

echo
echo "########## STEP 1: DRY RUN ##########"
python3 tools/rtl_namespace.py --config config/namespace.yaml --out build/all --dry-run
rc=$?
echo "[dry-run exit=$rc]"
[ $rc -ne 0 ] && echo "DRY-RUN FAILED" && exit 1

echo
echo "########## STEP 2: GENERATE ##########"
python3 tools/rtl_namespace.py --config config/namespace.yaml --out build/all
rc=$?
echo "[generate exit=$rc]"
[ $rc -ne 0 ] && echo "GENERATE FAILED" && exit 1

echo
echo "########## STEP 3: generated tree ##########"
find build/all -type f | sort

echo
echo "########## STEP 4: spot-check generated RTL ##########"
echo "--- build/all/PROJA/PROJA__ctrl.sv ---"
cat build/all/PROJA/PROJA__ctrl.sv
echo "--- build/all/PROJB/PROJB__fifo.sv (head) ---"
head -n 8 build/all/PROJB/PROJB__fifo.sv

echo
echo "########## STEP 5: CHECK MODE ##########"
python3 tools/rtl_namespace.py --config config/namespace.yaml --out build/all --check
rc=$?
echo "[check exit=$rc]"
[ $rc -ne 0 ] && echo "CHECK FAILED" && exit 1

echo
echo "########## STEP 6: ACCEPTANCE ASSERTIONS (Test 1-6) ##########"
python3 scripts/verify_p1.py
rc=$?
[ $rc -ne 0 ] && echo "VERIFY FAILED" && exit 1

echo
echo "########## STEP 6b: common-module policy checks ##########"
COMMON_SRC="src/rtl/AOU_RX_CORE.sv"
COMMON_OUT="build/all/common/rtl/AOU_RX_CORE.sv"
COMMON_NAME="AOU_RX_CORE"
[ -f "$COMMON_OUT" ] && echo "[OK] common copy emitted once: $COMMON_OUT" \
    || { echo "[FAIL] common copy missing"; exit 1; }
head -n 2 "$COMMON_OUT" > /dev/null
grep -q "^module $COMMON_NAME" "$COMMON_OUT" \
    && echo "[OK] common module declaration NOT renamed" \
    || { echo "[FAIL] common module declaration was renamed"; exit 1; }
if ls build/all/PROJA/PROJA__AOU_RX_CORE.sv build/all/PROJB/PROJB__AOU_RX_CORE.sv \
       build/all/PROJA/AOU_RX_CORE.sv build/all/PROJB/AOU_RX_CORE.sv 2>/dev/null; then
    echo "[FAIL] stale/duplicate AOU_RX_CORE copy present in project trees"
    exit 1
else
    echo "[OK] no AOU_RX_CORE copy inside PROJA/PROJB trees (single shared copy)"
fi
if grep -rEq "PROJA__AOU_RX_CORE([^A-Za-z0-9_]|$)|PROJB__AOU_RX_CORE([^A-Za-z0-9_]|$)" \
       build/all/PROJA build/all/PROJB; then
    echo "[FAIL] common module instantiation was namespaced somewhere"
    exit 1
else
    echo "[OK] instantiations of common module keep the bare name everywhere"
fi
[ "$(grep -c 'common/rtl/AOU_RX_CORE.sv' build/all/filelist.f)" = "1" ] \
    && echo "[OK] filelist.f lists the common copy exactly once" \
    || { echo "[FAIL] filelist.f common entry count != 1"; exit 1; }

echo
echo "########## STEP 7: Test 7 - original RTL untouched ##########"
find src -type f \( -name '*.sv' -o -name '*.v' \) | sort | xargs sha256sum > /tmp/p1_src_after.sha
if diff -q /tmp/p1_src_before.sha /tmp/p1_src_after.sha > /dev/null; then
    echo "[OK]   original RTL byte-identical (nothing modified in src/)"
else
    echo "[FAIL] original RTL changed!"
    diff /tmp/p1_src_before.sha /tmp/p1_src_after.sha
    exit 1
fi

echo
echo "########## STEP 8: Test 8 - compile demo subset with iverilog (-g2012) ##########"
echo "--- filelist.f (head) ---"
head -n 4 build/all/filelist.f
echo "  ... (total $(wc -l < build/all/filelist.f) files)"
# Demo compile list = the demo fifo/ctrl files only, so the compile test does
# not depend on the real PROJA design's external packages (e.g. packet_def_pkg).
DEMO_FL=/tmp/p1_demo.fl
printf '%s\n' \
    build/all/PROJA/PROJA__ctrl.sv \
    build/all/PROJA/PROJA__fifo.sv \
    build/all/PROJB/PROJB__ctrl.sv \
    build/all/PROJB/PROJB__fifo.sv > "$DEMO_FL"
echo "--- elaborate PROJA__ctrl (needs PROJA__fifo) ---"
iverilog -g2012 -Wall -s PROJA__ctrl -o /tmp/p1_proja.vvp -f "$DEMO_FL" \
    && echo "[OK]   iverilog elaborated PROJA__ctrl -> PROJA__fifo" \
    || { echo "[FAIL] PROJA compile failed"; exit 1; }
echo "--- elaborate PROJB__ctrl (needs PROJB__fifo) ---"
iverilog -g2012 -Wall -s PROJB__ctrl -o /tmp/p1_projb.vvp -f "$DEMO_FL" \
    && echo "[OK]   iverilog elaborated PROJB__ctrl -> PROJB__fifo" \
    || { echo "[FAIL] PROJB compile failed"; exit 1; }

echo
echo "========== ALL P1 STEPS PASSED =========="
