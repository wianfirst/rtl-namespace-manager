#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RTL Namespace Generator - P1
============================

Multi-project RTL integration tool (see RTL_Namespace_Manager_方案设计计划.md
and RTL_Namespace_Manager_P1执行文档.md).

Original Perforce RTL is NEVER modified. Generated, namespaced copies are
written under the --out directory, e.g.

    src/PROJA/rtl/fifo.sv   --module fifo-->   build/all/PROJA/rtl/PROJA__fifo.sv

Rewriting is token/syntax based (NOT naive text.replace): module declarations
and module instantiation statements are identified from the token stream, so
comments, strings, signals (fifo_data), instance names (u_fifo), parameters
and macro bodies are left untouched.

P1 scope (from P1执行文档.md sec 2):
  supported    : module declaration / plain / parameterized / array instance
                 rename, project namespace, duplicate + collision checks,
                 module_map.json, filelist.f, dry-run, check, diff
  not yet (P2) : interface / package / bind / complex macro / generate
                 semantics / full AST / cross-project dependency policy

Usage:
    python3 tools/rtl_namespace.py --config config/namespace.yaml --out build/all
    python3 tools/rtl_namespace.py --config ... --out ... --dry-run
    python3 tools/rtl_namespace.py --config ... --out ... --check
    python3 tools/rtl_namespace.py --config ... --out ... --diff
    python3 tools/rtl_namespace.py --config ... --out ... --src <rtl_dir>  # override 'source:' for all projects
"""

import argparse
import json
import os
import re
import shutil
import sys

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None

TOOL_VERSION = "1.2.0"
GENERATED_HEADER = (  # only used with --header (off by default)
    "// ------------------------------------------------------------------\n"
    "// GENERATED FILE - DO NOT EDIT / DO NOT COMMIT TO PERFORCE\n"
    "// RTL Namespace Manager v{v} (P1)\n"
    "// original : {src}\n"
    "// project  : {project}  namespace: {ns}\n"
    "// ------------------------------------------------------------------\n"
)

RTL_EXTS = (".sv", ".svh", ".v", ".vh")
KEYWORDS_MODULE = ("module", "macromodule")

# ---------------------------------------------------------------------------
# Tokenizer
# ---------------------------------------------------------------------------

class Tok:
    __slots__ = ("text", "kind", "start", "end", "line", "col")

    def __init__(self, text, kind, start, end, line, col):
        self.text = text
        self.kind = kind          # id | num | punct | string | directive | ws | comment
        self.start = start
        self.end = end
        self.line = line          # 1-based
        self.col = col            # 1-based column of first char

    def __repr__(self):  # pragma: no cover
        return "Tok(%r,%r,%d:%d)" % (self.kind, self.text, self.line, self.col)


def _is_id_start(c):
    return c.isalpha() or c == "_"


def _is_id_char(c):
    return c.isalnum() or c in "_$"


def tokenize(text):
    """Return a list of Tok spanning the whole text.

    Comments and strings are emitted as single opaque tokens so later stages
    can never rewrite text inside them. `` `define ... `` bodies (including
    backslash-continuation lines) are swallowed into one opaque directive
    token: macro bodies are P2 territory and must not be touched here.
    """
    toks = []
    n = len(text)
    i = 0
    line = 1
    linestart = 0

    def emit(kind, s, e):
        col = s - linestart + 1
        toks.append(Tok(text[s:e], kind, s, e, line, col))

    while i < n:
        c = text[i]

        # whitespace
        if c in " \t\r\n\f\v":
            j = i
            while j < n and text[j] in " \t\r\n\f\v":
                if text[j] == "\n":
                    line += 1
                    linestart = j + 1
                j += 1
            emit("ws", i, j)
            i = j
            continue

        # line comment
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            if j < 0:
                j = n
            emit("comment", i, j)
            i = j
            continue

        # block comment
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            if j < 0:
                j = n
            else:
                j += 2
            seg = text[i:j]
            line += seg.count("\n")
            linestart = j - seg.rfind("\n") - 1 if "\n" in seg else linestart
            emit("comment", i, j)
            i = j
            continue

        # string literal
        if c == '"':
            j = i + 1
            while j < n:
                ch = text[j]
                if ch == "\\":
                    j += 2
                    continue
                if ch == "\n":
                    line += 1
                    linestart = j + 1
                    j += 1
                    continue
                if ch == '"':
                    j += 1
                    break
                j += 1
            emit("string", i, j)
            i = j
            continue

        # compiler directive / macro
        if c == "`":
            j = i + 1
            while j < n and _is_id_char(text[j]):
                j += 1
            word = text[i + 1:j]
            if word == "define":
                # swallow macro definition body to end of line, honouring
                # backslash line continuations
                while j < n:
                    nl = text.find("\n", j)
                    if nl < 0:
                        j = n
                        break
                    # backslash directly before newline -> continuation
                    k = nl - 1
                    while k >= j and text[k] in " \t\r":
                        k -= 1
                    cont = k >= j and text[k] == "\\"
                    j = nl + 1
                    line += 1
                    linestart = j
                    if not cont:
                        break
                emit("directive", i, j)
                i = j
                continue
            if word == "":
                j = i + 1  # stray backtick
            emit("directive", i, j)
            i = j
            continue

        # escaped identifier \name
        if c == "\\":
            j = i + 1
            while j < n and text[j] not in " \t\r\n":
                j += 1
            emit("id", i, j)
            i = j
            continue

        # identifier
        if _is_id_start(c):
            j = i + 1
            while j < n and _is_id_char(text[j]):
                j += 1
            emit("id", i, j)
            i = j
            continue

        # number literal
        if c.isdigit() or (c == "'" and i + 1 < n and text[i + 1] in "0123456789"):
            j = i + 1
            if c == "'":
                j = i + 2
                while j < n and text[j] not in " \t\r\n;,()[]{}#":
                    j += 1
            else:
                while j < n and (text[j].isalnum() or text[j] in "_'?.xXzZ"):
                    j += 1
            emit("num", i, j)
            i = j
            continue

        # single-char token (punctuation/operator handled as 'punct' or 'other')
        j = i + 1
        kind = "punct"
        if text[i:i + 2] in ("//", "/*", "::", "==", "!=", "<=", ">=", "&&",
                             "||", "**", "<<", ">>", "<<<", ">>>", "+=", "-=",
                             ".*", "=>"):
            j = i + 2
            kind = "punct"
        emit(kind, i, j)
        i = j

    return toks


# ---------------------------------------------------------------------------
# Small SV lexical helpers over the token stream
# ---------------------------------------------------------------------------

def _sig_stream(toks):
    """Indices of significant tokens (drop ws/comment only)."""
    return [t for t in range(len(toks)) if toks[t].kind not in ("ws", "comment")]


def _find_matching(toks, open_idx, open_ch, close_ch):
    """Return index (in toks) of matching close_ch given toks[open_idx]==open_ch."""
    depth = 0
    for k in range(open_idx, len(toks)):
        if toks[k].kind != "punct":
            continue
        if toks[k].text == open_ch:
            depth += 1
        elif toks[k].text == close_ch:
            depth -= 1
            if depth == 0:
                return k
    return None


# ---------------------------------------------------------------------------
# Scan / rename planning
# ---------------------------------------------------------------------------

def _is_instance_candidate(stream, pos, toks, module_names):
    """pos points at an id token equal to a known module name.  Return True
    when the surrounding tokens form a module instantiation statement:

        module_name [ #(params) | #number ] instance_name [ [range] ] (ports) | ;

    The instance name token is required between the module name and the
    port list, which distinguishes instantiations from function calls
    (``fifo(args)`` has no extra identifier) and from net references.
    """
    def sig_after(idx):
        return idx + 1

    def next_sig(idx):
        j = idx + 1
        while j < len(stream) and toks[stream[j]].kind in ("ws", "comment"):
            j += 1
        return j if j < len(stream) else None

    j = next_sig(pos)

    # optional parameter value assignment: #(...) or #<number>
    if j is not None and toks[stream[j]].text == "#":
        jj = next_sig(j)
        if jj is None:
            return False
        if toks[stream[jj]].text == "(":
            close = _find_matching(toks, stream[jj], "(", ")")
            if close is None:
                return False
            # advance stream index past the closing paren
            ci = stream.index(close)  # stream position of ')' token
            j = next_sig(ci)
        else:
            j = next_sig(jj)  # #<number>
    elif j is not None and toks[stream[j]].text == "(":
        # module_name ( ... ) directly -> function-call like; NOT an instance
        # (a real instance always carries an instance name first)
        return False

    if j is None or toks[stream[j]].kind != "id":
        return False
    # instance name may itself be a known module name -> still an instance;
    # renaming is only ever applied to the *module-type* token.

    # optional array range [ ... ]
    jj = next_sig(j)
    if jj is not None and toks[stream[jj]].text == "[":
        close = _find_matching(toks, stream[jj], "[", "]")
        if close is None:
            return False
        ci = stream.index(close)
        jj = next_sig(ci)

    if jj is None:
        return False
    return toks[stream[jj]].text in ("(", ";")


def plan_renames(text, module_names):
    """Return dict token_index -> new_text and list of (line,col,old,new)
    describing every rewrite needed for this file.

    module_names : set/mapping of module names (original) that belong to the
                   owning project and therefore must be namespaced.
    """
    toks = tokenize(text)
    stream = _sig_stream(toks)
    edits = {}                # token index -> (new_text, kind)
    changes = []              # (line, col, old, new, kind)

    for p, ti in enumerate(stream):
        t = toks[ti]
        if t.kind != "id":
            continue

        # --- module declaration: keyword module/macromodule followed by name
        if t.text in KEYWORDS_MODULE:
            if p + 1 < len(stream):
                nt = toks[stream[p + 1]]
                if nt.kind == "id" and nt.text in module_names:
                    new = module_names[nt.text]
                    edits[stream[p + 1]] = (new, "declaration")
                    changes.append((nt.line, nt.col, nt.text, new, "declaration"))
            continue

        # skip '.'/':'/'::' qualified identifiers (a.b, pkg::x)
        if p > 0:
            prev = toks[stream[p - 1]]
            if prev.kind == "punct" and prev.text in (".", ":"):
                continue

        if t.text in module_names:
            if _is_instance_candidate(stream, p, toks, module_names):
                new = module_names[t.text]
                edits[ti] = (new, "instantiation")
                changes.append((t.line, t.col, t.text, new, "instantiation"))

    return toks, edits, changes


def apply_edits(text, edits):
    """edits: token index -> (new_text, kind). Rebuild text preserving everything
    except renamed token spans (applied via offsets, so comments/strings/ws are
    byte-identical)."""
    if not edits:
        return text
    toks = tokenize(text)
    spans = sorted(((toks[i].start, toks[i].end, new) for i, (new, _k) in edits.items()),
                   key=lambda x: x[0])
    out = []
    pos = 0
    for s, e, new in spans:
        out.append(text[pos:s])
        out.append(new)
        pos = e
    out.append(text[pos:])
    return "".join(out)


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

def load_config(path):
    if yaml is None:
        die("PyYAML is required:  python3 -m pip install pyyaml")
    with open(path, "r", encoding="utf-8") as f:
        raw = yaml.safe_load(f)
    if not isinstance(raw, dict) or "projects" not in raw:
        die("config %s: missing top-level 'projects' section" % path)

    projects = {}
    for pname, p in raw["projects"].items():
        if not isinstance(p, dict):
            die("config %s: project '%s' must be a mapping" % (path, pname))
        sources = p.get("source")
        if not sources:
            die("config %s: project '%s' has no 'source' dirs" % (path, pname))
        if isinstance(sources, str):
            sources = [sources]
        ns = p.get("namespace", pname)
        if not ns:
            die("config %s: project '%s' has empty namespace" % (path, pname))
        rename = p.get("rename") or {}
        projects[pname] = {
            "namespace": str(ns),
            "sources": [str(s) for s in sources],
            "exclude": [str(x) for x in (p.get("exclude") or [])],
            "rename_module": bool(rename.get("module", True)),
        }
    if not projects:
        die("config %s: no projects defined" % path)

    namespaces = [pr["namespace"] for pr in projects.values()]
    if len(namespaces) != len(set(namespaces)):
        die("config %s: duplicate namespace across projects (each project needs "
            "a unique namespace)" % path)

    # Global common-module list: these module names keep their original name in
    # EVERY project (module declaration AND every instantiation stay bare) and
    # their source files are emitted once under <out>/common/.
    raw_common = raw.get("common_modules") or []
    if isinstance(raw_common, str):
        raw_common = [raw_common]
    common = [str(m).strip() for m in raw_common if str(m).strip()]
    return projects, common


def die(msg):
    print("[ERROR] %s" % msg)
    sys.exit(1)


# ---------------------------------------------------------------------------
# File collection + module database
# ---------------------------------------------------------------------------

def _norm(p):
    return p.replace(os.sep, "/")


def collect_project_files(proj, cfg):
    files = []
    for srcroot in proj["sources"]:
        if not os.path.isdir(srcroot):
            die("project '%s': source dir not found: %s" % (cfg, srcroot))
        for dirpath, dirnames, filenames in os.walk(srcroot):
            dirnames[:] = [d for d in dirnames
                           if not d.startswith(".") and d not in ("build",)]
            for fn in sorted(filenames):
                if fn.endswith(RTL_EXTS):
                    full = _norm(os.path.join(dirpath, fn))
                    if not _excluded(full, proj["exclude"], srcroot):
                        files.append((full, srcroot))
    return files


def collect_project_inputs(proj, cfg, all_namespaces):
    """Split a project's recursive source tree into generated and passthrough
    inputs.

    A file named ``<PROJECT>_<module>.v`` or
    ``<PROJECT>__<module>.sv`` is an already namespaced project override.  It
    is copied unchanged for that project only.  A generic sibling with the
    same module stem is suppressed for that project, while every other project
    still consumes and namespaces the generic RTL normally.

    The override key includes its source root and relative directory.  This
    keeps unrelated modules with the same basename in separate nested source
    trees from silently shadowing one another.
    """
    normal = []
    overrides = {}

    def existing_namespace(stem):
        # Check the double-underscore spelling first: it must not be consumed
        # by the single-underscore fallback.
        for ns in sorted(all_namespaces, key=len, reverse=True):
            for prefix in (ns + "__", ns + "_"):
                if stem.startswith(prefix) and len(stem) > len(prefix):
                    return ns, stem[len(prefix):]
        return None, None

    for full, srcroot in collect_project_files(proj, cfg):
        stem = os.path.splitext(os.path.basename(full))[0]
        owner, orig = existing_namespace(stem)
        rel_dir = _norm(os.path.relpath(os.path.dirname(full), srcroot))
        if rel_dir == ".":
            rel_dir = ""
        key = (_norm(srcroot), rel_dir, orig)
        if owner is None:
            normal.append((full, srcroot))
            continue
        if owner != proj["namespace"]:
            # A pre-namespaced file is private to its owning project.  Do not
            # copy it into the other projects' generated trees.
            continue
        if key in overrides:
            die("project '%s': multiple existing namespace overrides for '%s' "
                "under %s" % (cfg, orig, os.path.join(srcroot, rel_dir)))
        overrides[key] = {"source": full, "srcroot": srcroot,
                          "orig": orig, "actual": stem, "rel_dir": rel_dir}

    selected = []
    for full, srcroot in normal:
        stem = os.path.splitext(os.path.basename(full))[0]
        rel_dir = _norm(os.path.relpath(os.path.dirname(full), srcroot))
        if rel_dir == ".":
            rel_dir = ""
        if (_norm(srcroot), rel_dir, stem) in overrides:
            # The existing project-specific module is authoritative for this
            # project.  Other projects have independent input selections.
            continue
        selected.append((full, srcroot))

    return selected, [overrides[k] for k in sorted(overrides)]


def _excluded(full, patterns, srcroot):
    rel = _norm(os.path.relpath(full, srcroot))
    for pat in patterns:
        if pat.endswith("/**"):
            head = pat[:-3]
            if rel.startswith(head) or rel == head:
                return True
        elif re.match("^%s$" % re.escape(pat), rel) or rel.startswith(pat):
            return True
    return False


def scan_modules(files):
    """files: list of (path, srcroot). Return decls: dict orig -> list of
    dict(source, line, project_owner_key) plus per-file declaration info."""
    decls = {}   # orig name -> [ {source, line} ]
    per_file = {}  # source -> [orig names declared]
    for full, _root in files:
        try:
            with open(full, "r", encoding="utf-8", errors="replace") as f:
                text = f.read()
        except OSError as e:
            die("cannot read %s: %s" % (full, e))
        names = []
        toks = tokenize(text)
        stream = _sig_stream(toks)
        for p, ti in enumerate(stream):
            if toks[ti].kind == "id" and toks[ti].text in KEYWORDS_MODULE:
                if p + 1 < len(stream):
                    nt = toks[stream[p + 1]]
                    if nt.kind == "id":
                        orig = nt.text
                        decls.setdefault(orig, []).append(
                            {"source": _norm(full), "line": nt.line})
                        names.append(orig)
        if names:
            per_file[_norm(full)] = names
    return decls, per_file


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------

def gen_name(ns, orig):
    return "%s__%s" % (ns, orig)


def main():
    ap = argparse.ArgumentParser(
        description="RTL Namespace Generator (P1) - v%s" % TOOL_VERSION)
    ap.add_argument("--config", required=True, help="path to namespace.yaml")
    ap.add_argument("--out", default="build/all", help="output root dir")
    ap.add_argument("--dry-run", action="store_true",
                    help="only report what would change; write nothing")
    ap.add_argument("--check", action="store_true",
                    help="validation only (duplicate/collision/config); no writes")
    ap.add_argument("--diff", action="store_true",
                    help="report changed/unchanged generated files vs previous run")
    ap.add_argument("--header", action="store_true",
                    help="prepend a 'GENERATED FILE' comment header to each "
                         "generated file (off by default)")
    ap.add_argument("--src", action="append", metavar="DIR",
                    help="override the RTL source directory(ies) from the "
                         "config ('source:') for EVERY project. Repeatable and "
                         "comma/space separated, e.g. --src rtlA,rtlB")
    args = ap.parse_args()

    projects, common_modules = load_config(args.config)
    common_set = set(common_modules)
    out_root = _norm(args.out)

    # --src overrides the per-project 'source' dirs from the config
    if args.src:
        src_dirs = []
        for chunk in args.src:
            for piece in re.split(r"[,\s]+", chunk):
                if piece:
                    src_dirs.append(_norm(piece))
        if not src_dirs:
            print("[ERROR] --src given but no directory found in: %s" % args.src)
            sys.exit(1)
        for pr in projects.values():
            pr["sources"] = list(src_dirs)
        print("[INFO] RTL source overridden by --src: %s"
              % ", ".join(src_dirs))

    print("[INFO] Projects:")
    for pname, pr in projects.items():
        for s in pr["sources"]:
            print("    %s: %s  (namespace=%s)" % (pname, s, pr["namespace"]))

    # Select inputs before scanning.  This prevents an existing
    # PROJA_fifo.v from being treated as a generic module and renamed again.
    all_namespaces = {pr["namespace"] for pr in projects.values()}
    project_files = {}
    project_overrides = {}
    for pname, pr in projects.items():
        files, overrides = collect_project_inputs(pr, pname, all_namespaces)
        project_files[pname] = files
        project_overrides[pname] = overrides
        for ov in overrides:
            print("[INFO] %s: existing namespace override %s -> %s "
                  "(copied unchanged)" % (pname, ov["orig"], ov["actual"]))

    print("\n[INFO] Scanning RTL...")
    module_decls = {}      # project -> orig -> [decl dicts]
    decl_by_name = {}      # orig -> first {source, line} (across all projects)
    file_declared = {}     # source -> set(orig names declared in that file)
    file_srcroot = {}      # source -> source root used to reach it
    for pname, pr in projects.items():
        files = project_files[pname]
        decls, per_file = scan_modules(files)
        module_decls[pname] = decls
        for orig, dlist in decls.items():
            if orig not in decl_by_name and dlist:
                decl_by_name[orig] = dict(dlist[0])
        for src, names in per_file.items():
            file_declared.setdefault(src, set()).update(names)
    # remember which source root reaches each generated file (used to mirror
    # nested source directories in the output tree)
    for pname in projects:
        for full, srcroot in project_files[pname]:
            file_srcroot.setdefault(full, srcroot)

    all_orig = set(decl_by_name)
    print("[INFO] Found %d module declaration(s) (unique names: %d) across %d "
          "project(s)" % (sum(len(d) for d in module_decls.values()),
                          len(all_orig), len(projects)))

    # ---- common-module config sanity
    unknown_common = common_set - all_orig
    if unknown_common:
        print("[FAIL] Validation failed:")
        for m in sorted(unknown_common):
            print("    [ERROR] common_modules entry '%s' is not declared by any "
                  "scanned RTL file" % m)
        sys.exit(1)

    # files that declare >=1 common module are emitted ONCE under <out>/common
    common_files = sorted(s for s, names in file_declared.items()
                          if names & common_set)
    for src in common_files:
        names = file_declared[src]
        if names - common_set:
            print("[FAIL] Validation failed:")
            print("    [ERROR] %s declares both common (%s) and non-common (%s) "
                  "modules; split the file so each file is either fully common "
                  "or fully namespaced" % (
                      src, ", ".join(sorted(names & common_set)),
                      ", ".join(sorted(names - common_set))))
            sys.exit(1)
    for orig in sorted(common_set):
        seen_src = {d["source"] for p in projects
                    for d in module_decls[p].get(orig, [])}
        if len(seen_src) > 1:
            print("[FAIL] Validation failed:")
            print("    [ERROR] common module '%s' is declared in multiple "
                  "files: %s" % (orig, ", ".join(sorted(seen_src))))
            sys.exit(1)

    # ---- rename maps: project -> orig -> new  (common modules excluded)
    rename_maps = {}
    for pname, decls in module_decls.items():
        ns = projects[pname]["namespace"]
        rename_maps[pname] = {o: gen_name(ns, o) for o in decls
                              if o not in common_set}
        for ov in project_overrides[pname]:
            if ov["orig"] in common_set:
                die("project '%s': existing namespace override '%s' conflicts "
                    "with common_modules; common modules cannot be project "
                    "specific" % (pname, ov["orig"]))
            if ov["orig"] in rename_maps[pname]:
                die("project '%s': existing namespace override '%s' conflicts "
                    "with a generic module declared in another directory; "
                    "keep the override beside the generic RTL or make the "
                    "source modules unique" % (pname, ov["orig"]))
            # Other RTL in this project still refers to the generic name.
            # Point those instantiations at the pre-namespaced implementation.
            rename_maps[pname][ov["orig"]] = ov["actual"]

    print("\n[INFO] Module namespace (renamed per project):")
    for pname, decls in sorted(module_decls.items()):
        for orig in sorted(decls):
            if orig in common_set:
                print("    %s: %s -> %s  (COMMON: keep name)"
                      % (pname, orig, orig))
            else:
                print("    %s: %s -> %s" % (pname, orig,
                                            rename_maps[pname][orig]))

    if common_set:
        print("\n[INFO] Common modules (global list, NOT renamed, emitted once "
              "under %s/common/):" % out_root)
        for orig in sorted(common_set):
            print("    %s" % orig)

    # ---- validation (always runs before any write)
    errors = validate(module_decls, rename_maps, common_set)
    if errors:
        print("\n[FAIL] Validation failed:")
        for e in errors:
            print("    [ERROR] %s" % e)
        sys.exit(1)
    print("[PASS] Validation: no duplicate module / namespace collision / "
          "config errors.")

    # ---- plan every file rewrite
    plan = []          # per-project (namespaced) outputs
    common_plan = []   # single shared outputs (copied as-is)
    nchanges = 0

    def make_item(pname, ns, full, srcroot, edits, changes, module_info,
                  out_file):
        return {"project": pname, "ns": ns, "source": _norm(full),
                "srcroot": srcroot, "out": out_file, "edits": edits,
                "changes": changes, "module_info": module_info}

    for pname, pr in projects.items():
        ns = projects[pname]["namespace"]
        rm = rename_maps[pname]
        for full, srcroot in project_files[pname]:
            if full in common_files:
                continue  # handled once, below
            with open(full, "r", encoding="utf-8", errors="replace") as f:
                text = f.read()
            _toks, edits, changes = plan_renames(text, rm)
            file_mods = sorted(file_declared[full] & set(rm))
            renamed_in_file = [o for o in file_mods if o in rm]
            if len(renamed_in_file) == 1:
                base = rm[renamed_in_file[0]] + os.path.splitext(full)[1]
            else:
                base = os.path.basename(full)
            rel_dir = _norm(os.path.relpath(os.path.dirname(full), srcroot))
            if rel_dir == ".":
                rel_dir = ""
            rel_out = _norm(os.path.join(ns, rel_dir, base)) if rel_dir else \
                _norm(os.path.join(ns, base))
            out_file = _norm(os.path.join(out_root, rel_out))
            module_info = {o: dict(decl_by_name[o]) for o in file_mods}
            plan.append(make_item(pname, ns, full, srcroot, edits, changes,
                                  module_info, out_file))
            nchanges += len(changes)

        # Existing <PROJECT>_<module> / <PROJECT>__<module> RTL already owns
        # its namespace.  Preserve it byte-for-byte and keep both its filename
        # and relative nested directory in the generated project tree.
        for ov in project_overrides[pname]:
            out_file = _norm(os.path.join(
                out_root, ns, ov["rel_dir"], os.path.basename(ov["source"])))
            override_decls, _ = scan_modules([(ov["source"], ov["srcroot"])])
            dlist = override_decls.get(ov["actual"], [])
            if not dlist:
                die("project '%s': existing namespace override %s must declare "
                    "module %s" % (pname, ov["source"], ov["actual"]))
            module_info = {ov["orig"]: dict(dlist[0])}
            item = make_item(pname, ns, ov["source"], ov["srcroot"], {}, [],
                             module_info, out_file)
            item["passthrough"] = True
            plan.append(item)

    # common files: emit once, as-is (no rename edits at all)
    for full in common_files:
        srcroot = file_srcroot[full]
        with open(full, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
        rel_dir = _norm(os.path.relpath(os.path.dirname(full), srcroot))
        if rel_dir == ".":
            rel_dir = ""
        base = os.path.basename(full)
        rel_out = _norm(os.path.join("common", rel_dir, base)) if rel_dir else \
            _norm(os.path.join("common", base))
        out_file = _norm(os.path.join(out_root, rel_out))
        module_info = {o: dict(decl_by_name[o])
                       for o in sorted(file_declared[full] & common_set)}
        common_plan.append(make_item("COMMON", "common", full, srcroot,
                                     {}, [], module_info, out_file))

    # ---- warning pass
    # (a) per-project: instantiated module-type names not managed by this
    #     project's rename map and not common (real cross-project refs).
    other_declared = all_orig - common_set
    for item in plan:
        known_this = set(rename_maps[item["project"]].keys())
        foreign = other_declared - known_this
        if not foreign:
            continue
        with open(item["source"], "r", encoding="utf-8",
                  errors="replace") as f:
            text = f.read()
        toks = tokenize(text)
        stream = _sig_stream(toks)
        for p, ti in enumerate(stream):
            t = toks[ti]
            if t.kind != "id" or t.text not in foreign:
                continue
            if p > 0 and toks[stream[p - 1]].kind == "punct" and \
                    toks[stream[p - 1]].text in (".", ":"):
                continue
            if _is_instance_candidate(stream, p, toks, foreign):
                where = "declared only in project(s): %s" % ", ".join(sorted(
                    pn for pn in projects if t.text in module_decls[pn]))
                print("[WARN] %s:%d: '%s' instantiated but %s -> left as-is "
                      "(cross-project dependency is P2)"
                      % (item["source"], t.line, t.text, where))
    # (b) common files must not reference namespaced (non-common) modules,
    #     otherwise the single shared copy cannot bind to the per-project names.
    for item in common_plan:
        with open(item["source"], "r", encoding="utf-8",
                  errors="replace") as f:
            text = f.read()
        toks = tokenize(text)
        stream = _sig_stream(toks)
        for p, ti in enumerate(stream):
            t = toks[ti]
            if t.kind != "id" or t.text not in other_declared:
                continue
            if p > 0 and toks[stream[p - 1]].kind == "punct" and \
                    toks[stream[p - 1]].text in (".", ":"):
                continue
            if _is_instance_candidate(stream, p, toks, other_declared):
                print("[WARN] %s:%d: common file references non-common module "
                      "'%s' with its bare name; the shared copy can only bind "
                      "to other common/external modules - add '%s' to "
                      "'common_modules' if it is shared, or keep this module "
                      "per-project" % (item["source"], t.line, t.text, t.text))

    # ---- reporting per requested mode
    if args.dry_run:
        print("\n[DRY-RUN] Planned changes (%d):" % nchanges)
        for item in plan:
            for ln, col, old, new, kind in item["changes"]:
                print("    %s:%d:%d  [%s] %s -> %s"
                      % (item["source"], ln, col, kind, old, new))
        for item in common_plan:
            print("    (common, copied as-is) %s -> %s"
                  % (item["source"], item["out"]))
        print("\n[DRY-RUN] Would generate %d namespaced + %d common file(s) "
              "under %s/" % (len(plan), len(common_plan), out_root))
        print("[DRY-RUN] OK - nothing was written.")
        sys.exit(0)

    if args.check:
        print("\n[PASS] RTL namespace check passed.")
        sys.exit(0)

    # ---- generate
    print("\n[INFO] Generating RTL under %s/ ..." % out_root)
    # the out dir is fully derived output: wipe it so modules that became
    # common / renamed / removed never leave stale copies behind
    if os.path.exists(out_root):
        shutil.rmtree(out_root)
    os.makedirs(out_root, exist_ok=True)
    module_map = {}
    generated = []
    all_items = plan + common_plan
    for item in all_items:
        with open(item["source"], "r", encoding="utf-8",
                  errors="replace") as f:
            text = f.read()
        rewritten = text if item.get("passthrough") else apply_edits(text, item["edits"])
        if args.header and not item.get("passthrough"):
            header = GENERATED_HEADER.format(v=TOOL_VERSION,
                                             src=item["source"],
                                             project=item["project"],
                                             ns=item["ns"])
            rewritten = header + rewritten
        os.makedirs(os.path.dirname(item["out"]) or ".", exist_ok=True)
        with open(item["out"], "w", encoding="utf-8") as f:
            f.write(rewritten)
        generated.append(item["out"])

        pm = module_map.setdefault(item["project"], {})
        for orig, d in item["module_info"].items():
            pm[orig] = {
                "new_name": orig if item["project"] == "COMMON"
                else rename_maps[item["project"]].get(
                    orig, gen_name(item["ns"], orig)),
                "source": d["source"],
                "line": d["line"],
                "generated": _norm(os.path.relpath(item["out"])),
                "namespace": item["ns"],
                "common": item["project"] == "COMMON",
            }

    # module_map.json
    mm_path = _norm(os.path.join(out_root, "module_map.json"))
    os.makedirs(os.path.dirname(mm_path) or ".", exist_ok=True)
    with open(mm_path, "w", encoding="utf-8") as f:
        json.dump(module_map, f, indent=2, sort_keys=True)
        f.write("\n")

    # filelist.f (paths relative to the tool invocation cwd)
    fl_path = _norm(os.path.join(out_root, "filelist.f"))
    with open(fl_path, "w", encoding="utf-8") as f:
        for g in sorted(generated):
            f.write(_norm(os.path.relpath(g)) + "\n")

    print("[INFO] Generated %d namespaced + %d common file(s) (total %d)."
          % (len(plan), len(common_plan), len(generated)))
    print("[INFO] module_map.json -> %s" % mm_path)
    print("[INFO] filelist.f      -> %s" % fl_path)
    print("[INFO] Done.")


def validate(module_decls, rename_maps, common_set):
    """Return list of error strings (empty == clean)."""
    errors = []

    # duplicate module within one project (two files declare same name)
    for pname, decls in module_decls.items():
        for orig, dlist in decls.items():
            if len(dlist) > 1:
                files = ", ".join("%s:%d" % (d["source"], d["line"])
                                  for d in dlist)
                if orig in common_set:
                    errors.append("Duplicate common module '%s' declared in "
                                  "multiple files: %s" % (orig, files))
                else:
                    errors.append("Duplicate module '%s' in project %s "
                                  "(would both map to '%s'): %s"
                                  % (orig, pname, rename_maps[pname][orig],
                                     files))

    # generated-name collision across everything (common names are bare and
    # unique by the earlier checks, so only namespaced names are compared)
    seen = {}
    for pname, decls in module_decls.items():
        for orig in decls:
            if orig in common_set:
                continue
            new = rename_maps[pname][orig]
            if new in seen and seen[new] != (pname, orig):
                errors.append("Namespace collision: '%s' produced by both "
                              "%s:%s and %s:%s"
                              % (new, seen[new][0], seen[new][1], pname, orig))
            seen.setdefault(new, (pname, orig))

    return errors


if __name__ == "__main__":
    main()
