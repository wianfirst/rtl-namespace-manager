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
echo "--- build/all/PROJA/rtl/PROJA__ctrl.sv ---"
cat build/all/PROJA/rtl/PROJA__ctrl.sv
echo "--- build/all/PROJB/rtl/PROJB__fifo.sv (head) ---"
head -n 8 build/all/PROJB/rtl/PROJB__fifo.sv

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
echo "########## STEP 8: Test 8 - compile with iverilog (-g2012) ##########"
echo "--- filelist.f ---"
cat build/all/filelist.f
echo "--- elaborate PROJA__ctrl (needs PROJA__fifo) ---"
iverilog -g2012 -Wall -s PROJA__ctrl -o /tmp/p1_proja.vvp -f build/all/filelist.f \
    && echo "[OK]   iverilog elaborated PROJA__ctrl -> PROJA__fifo" \
    || { echo "[FAIL] PROJA compile failed"; exit 1; }
echo "--- elaborate PROJB__ctrl (needs PROJB__fifo) ---"
iverilog -g2012 -Wall -s PROJB__ctrl -o /tmp/p1_projb.vvp -f build/all/filelist.f \
    && echo "[OK]   iverilog elaborated PROJB__ctrl -> PROJB__fifo" \
    || { echo "[FAIL] PROJB compile failed"; exit 1; }

echo
echo "========== ALL P1 STEPS PASSED =========="
