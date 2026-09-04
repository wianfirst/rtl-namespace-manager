#!/usr/bin/env bash
# WSL Ubuntu environment check for RTL Namespace P1
set +e
echo "== python =="
python3 --version 2>&1
command -v python3
echo "== pyyaml =="
python3 -c 'import yaml; print("pyyaml", yaml.__version__)' 2>&1
echo "== pip =="
python3 -m pip --version 2>&1 | head -1
echo "== simulator / lint tools =="
command -v iverilog && iverilog -V 2>&1 | head -1
command -v verilator
command -v vcs
command -v xrun
echo "== git =="
git --version 2>&1
echo "== os =="
. /etc/os-release && echo "$PRETTY_NAME"
echo "== uid =="
id -un
echo "DONE"
