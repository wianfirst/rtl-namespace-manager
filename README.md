# rtl-namespace-manager

**Multi-project RTL namespace integration for ALL builds — without touching original Perforce RTL.**

多 Project RTL 同名冲突的 ALL/Integration 集成工具：保留 Perforce 原始 RTL 不变，在构建阶段自动生成带 Project namespace 的 RTL，并同步改写模块实例化引用，使多个 Project 可在同一 VCS / Xcelium / Lint 编译环境中共存。

> Perforce 负责"代码来自哪里"，Namespace Manager 负责"代码进入 ALL 后叫什么"。

## Problem

Different projects can ship RTL with identical module names:

```text
PROJA/rtl/fifo.sv   ->  module fifo
PROJB/rtl/fifo.sv   ->  module fifo
```

Each project compiles fine alone, but an ALL/Integration build that consumes
several projects at once hits duplicate-module compilation errors.

## Solution

Generated, namespaced copies are produced into a build directory; sources are
never modified:

```text
PROJA: fifo -> PROJA__fifo   ctrl -> PROJA__ctrl
PROJB: fifo -> PROJB__fifo   ctrl -> PROJB__ctrl

PROJA__ctrl references PROJA__fifo
PROJB__ctrl references PROJB__fifo
```

Rewriting is **token/syntax based** (never naive `text.replace`), so comments,
strings, signal names (`fifo_data`), instance names (`u_fifo`), parameters and
macro bodies are preserved byte-for-byte.

## Quick start

```bash
# 1. config
config/namespace.yaml          # projects: source dirs + namespace per project

# 2. dry run  (nothing written)
python3 tools/rtl_namespace.py --config config/namespace.yaml --out build/all --dry-run

# 3. generate
python3 tools/rtl_namespace.py --config config/namespace.yaml --out build/all

# 4. validate-only mode
python3 tools/rtl_namespace.py --config config/namespace.yaml --out build/all --check

# or via make
make namespace_dryrun
make namespace_check
make namespace

# 5. acceptance + compile smoke test (uses iverilog on this repo's demo RTL)
make verify
bash scripts/run_p1.sh
```

### Output

```text
build/all/
├── PROJA/rtl/PROJA__fifo.sv      module PROJA__fifo
├── PROJA/rtl/PROJA__ctrl.sv      instantiates PROJA__fifo
├── PROJB/rtl/PROJB__fifo.sv      module PROJB__fifo
├── PROJB/rtl/PROJB__ctrl.sv      instantiates PROJB__fifo
├── module_map.json               original -> generated traceability
└── filelist.f                    ready for vcs -f / xrun -f / iverilog -f
```

## Repository layout

```text
├── config/namespace.yaml         project / source / namespace config
├── src/PROJA|PROJB/rtl/          demo RTL (treated as immutable Perforce sources)
├── tools/rtl_namespace.py        P1 core tool (single file, stdlib + PyYAML)
├── scripts/
│   ├── run_p1.sh                 full P1 flow driver (dry-run→generate→check→verify→compile)
│   └── verify_p1.py              P1 acceptance assertions (Test 1-8)
├── Makefile                      namespace / namespace_check / namespace_dryrun / verify / sim
├── build/                        generated output (git-ignored)
├── RTL_Namespace_Manager_方案设计计划.md   full design plan (P1-P4)
└── RTL_Namespace_Manager_P1执行文档.md     P1 execution spec & acceptance criteria
```

## P1 scope & status

**Implemented (P1)** — module declaration rename, plain / parameterized /
array instantiation rename, project namespace, duplicate & collision checks,
`module_map.json`, `filelist.f`, `--dry-run / --check / --diff`, immutable
sources (verified by sha256 in `run_p1.sh`), compile smoke test.

**Not yet (P2+)** — interface / package / bind / checker namespace, complex
macro & `generate` semantics, full SystemVerilog AST, dependency graph &
cross-project policy, Perforce changelist pinning, ALL-LATEST / ALL-RELEASE,
cache & parallel generation. See the design docs above.

## Requirements

- Python >= 3.9, [PyYAML](https://pyyaml.org/)
- For the compile smoke test: Icarus Verilog (`iverilog -g2012`); real flows use
  VCS / Xcelium with `vcs -f build/all/filelist.f`.

## License

[MIT](LICENSE)
