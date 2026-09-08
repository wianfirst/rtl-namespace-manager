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
# 1. config: every project points at the SAME shared source tree; optional
#    global 'common_modules' list keeps selected modules un-namespaced
config/namespace.yaml

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

# 5. acceptance + compile smoke test (uses iverilog on the demo subset)
make verify
make verify_overrides  # recursive directories + existing project RTL
bash scripts/run_p1.sh
```

### config model

One shared source tree is compiled into a namespaced copy per project:

```yaml
projects:
  PROJA:  { source: [src], namespace: PROJA }   # -> PROJA__<module>
  PROJB:  { source: [src], namespace: PROJB }   # -> PROJB__<module>

# Global list: these modules are shared by ALL projects. Their module
# declaration AND every instantiation keep the original name, and the source
# file is emitted once under build/all/common/ (never duplicated per project).
common_modules:
  - AOU_RX_CORE
```

The common list applies to every project. A file that declares a common module
must not also declare non-common modules (validation rejects mixed files);
a common file that instantiates a non-common module produces a `[WARN]`.

### Existing project-specific RTL

Sources are scanned recursively. When a nested source directory contains an
already namespaced file named `<PROJECT>_<module>.v` (or the existing
`<PROJECT>__<module>.sv` spelling), it is treated as that project's override:

- it is copied unchanged only into that project's output tree;
- a same-directory generic `<module>.v` is not generated for that project;
- references to `<module>` from that project's other RTL are rewritten to the
  existing module name; and
- other projects continue to generate their own namespaced version from the
  generic RTL.

For example, given `src/ip/fifo.v` and `src/ip/PROJA_fifo.v`, PROJA receives
the unchanged `PROJA_fifo.v`, while PROJB still receives `PROJB__fifo.v`.
This preserves the current double-underscore generated-name convention; both
single- and double-underscore existing override filenames are accepted.

### Overriding the RTL source directory

The `source:` dirs from the config can be overridden on the command line /
Makefile without editing the YAML:

```bash
# direct CLI: overrides 'source:' for every project (repeatable / comma separated)
python3 tools/rtl_namespace.py --config config/namespace.yaml --out build/all \
    --src src,src/extra

# via Makefile. RTL_SRC is the recursively scanned root (or comma-separated
# roots), and NAMESPACE_OUT is the generated-output root.
make namespace RTL_SRC=src,src/extra NAMESPACE_OUT=out/rtl_namespace
make namespace_dryrun RTL_SRC=/path/to/other/rtl
# use a project-specific namespace configuration when needed
make namespace NAMESPACE_CONFIG=config/my_namespace.yaml
```

The Makefile defaults are `RTL_SRC=src` and `NAMESPACE_OUT=build/all`. All
three Makefile paths (`RTL_SRC`, `NAMESPACE_OUT`, `NAMESPACE_CONFIG`) are
overrideable on the command line, so the tool can be used from an existing
project without editing the copied Makefile.

### Output

```text
build/all/
├── PROJA/rtl/PROJA__fifo.sv      module PROJA__fifo     (per-project copy)
├── PROJA/rtl/PROJA__ctrl.sv      instantiates PROJA__fifo
├── PROJB/rtl/PROJB__fifo.sv      module PROJB__fifo
├── PROJB/rtl/PROJB__ctrl.sv      instantiates PROJB__fifo
├── common/rtl/AOU_RX_CORE.sv     module AOU_RX_CORE     (single shared copy)
├── module_map.json               original -> generated traceability
└── filelist.f                    ready for vcs -f / xrun -f / iverilog -f
```

Generated files are plain rewrites of the original source (no header comment;
pass `--header` if you want a provenance header).

## Repository layout

```text
├── config/namespace.yaml         project / source / namespace / common config
├── src/rtl/                      single shared RTL tree (immutable "Perforce" sources)
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

**Implemented (P1)** — shared single source tree compiled per project, module
declaration rename, plain / parameterized / array instantiation rename,
global `common_modules` policy (kept bare & emitted once under `common/`),
duplicate & collision checks, `module_map.json`, `filelist.f`,
`--dry-run / --check / --diff`, immutable sources (verified by sha256 in
`run_p1.sh`), compile smoke test.

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
