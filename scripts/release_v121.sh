#!/usr/bin/env bash
# Release v1.2.1: stage, commit, tag, push.
set -u
cd /mnt/d/ds_harness || exit 1
echo "== working tree =="
git status --short

echo "== stage all =="
git add -A

echo "== commit =="
git commit -m "fix: v1.2.1 - .v files with only \`define (no module) no longer crash

Header-like .v files (define-only, no module declaration) used to raise a
KeyError in the planning pass. They are now treated as passthrough files:
copied byte-for-byte into each project tree, excluded from module_map, and
listed once per project in filelist.f.

- tools/rtl_namespace.py: file_declared.get() + header/no-module reporting
- tests/nomodule_fixture + scripts/verify_nomodule.py: regression
- CHANGELOG: 1.2.1 entry" || exit 1

echo "== tag =="
git tag -a v1.2.1 -m "RTL Namespace Manager v1.2.1" || exit 1
git tag

echo "== push =="
GIT_TERMINAL_PROMPT=0 git push origin main 2>&1
RC1=$?
GIT_TERMINAL_PROMPT=0 git push origin v1.2.1 2>&1
RC2=$?
echo "push_main_rc=$RC1 push_tag_rc=$RC2"
if [ $RC1 -eq 0 ] && [ $RC2 -eq 0 ]; then
    echo "RELEASE_PUSH_OK"
else
    echo "RELEASE_PUSH_FAIL"
    exit 1
fi
git log --oneline -4
echo "== remote heads/tags =="
git ls-remote --heads --tags origin | tail -4
