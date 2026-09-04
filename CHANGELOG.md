# Changelog

All notable changes to **rtl-namespace-manager** are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/).
Versioning: [SemVer](https://semver.org/). Tags: `v<version>`.

## [1.1.0] - 2026-09-04

### Added
- Single shared RTL source tree model: `src/rtl/` is the one copy of truth,
  and every project in `config/namespace.yaml` compiles it into its own
  `<PROJECT>__<module>` namespaced tree (`source: [src]` for both projects).
- Global `common_modules` list in the config (`common_modules:`):
  - applies to ALL projects;
  - listed modules are NOT renamed (module declaration **and** every
    instantiation keep the original name);
  - their source files are emitted once under `<out>/common/` so the ALL
    build holds a single shared copy.
- `--src DIR` CLI option (+ repeatable / comma or space separated) that
  overrides the config `source:` dirs for every project, and matching
  `RTL_SRC=` variable in the Makefile
  (`make namespace RTL_SRC=rtlA,rtlB`).
- Validation for the common policy:
  - unknown `common_modules` entry → error;
  - common module declared in several files → error;
  - file mixing common and non-common module declarations → error;
  - common file instantiating a non-common module → warning.
- Generated-file hygiene: the output directory is wiped before each
  generation, so modules that became common / renamed / removed never leave
  stale copies behind.

### Changed
- Generated RTL is now a plain rewrite of the source: the "GENERATED FILE"
  header comment is no longer prepended by default (opt back in with
  `--header`).
- `module_map.json` gains a `COMMON` block for shared modules
  (`new_name == original`, `common: true`) and per-entry `generated` paths.
- Acceptance scripts scale with the real RTL set:
  - `scripts/verify_p1.py`: filelist assertions are count-independent
    (demo entries + every listed file must exist);
  - `scripts/run_p1.sh`: new STEP 6b asserting the common-module policy,
    and the iverilog compile smoke test uses a demo subset file list.
- Demo layout migrated from per-project `src/PROJA|PROJB/rtl/` to the single
  shared `src/rtl/` directory.

## [1.0.0] - 2026-07-28

### Added
- Initial P1 release of the RTL namespace generator (`tools/rtl_namespace.py`):
  - token/syntax-based (never naive string replace) rewriting of
    module declarations, plain / parameterized / array instantiations;
  - comments, strings, signal names, instance names, parameters and
    `` `define `` bodies preserved byte-for-byte;
  - per-project namespaces `<PROJECT>__<module>` from
    `config/namespace.yaml`;
  - duplicate / namespace-collision / config validation;
  - outputs: namespaced RTL under `build/all/`, `module_map.json`,
    `filelist.f`;
  - modes: `--dry-run`, `--check`, `--diff`, optional `--header`;
  - immutable sources verified by sha256 (`scripts/run_p1.sh`),
    acceptance assertions (`scripts/verify_p1.py`), Makefile targets,
    and an iverilog compile smoke test.
- Repository scaffold: README, MIT `LICENSE`, `.gitignore`, Makefile,
  demo RTL fixtures, and the design documents
  (`RTL_Namespace_Manager_方案设计计划.md`,
  `RTL_Namespace_Manager_P1执行文档.md`).
