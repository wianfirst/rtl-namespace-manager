#!/usr/bin/env bash
# Release v1.1.0: stage everything, commit, tag, push.
set -u
cd /mnt/d/ds_harness || exit 1
echo "== stage all =="
git add -A
git status --short | head -8
echo "  ... (+$(git status --short | wc -l) changes total)"

echo "== commit =="
git commit -m "feat: v1.1.0 - shared source tree, common_modules policy, --src override

- single shared RTL source (src/rtl) compiled into per-project namespaces
- global common_modules: shared modules keep original name, emitted once
  under build/all/common/ (declarations AND instantiations untouched)
- generated files: no GENERATED header by default (--header opts back in)
- --src DIR / make RTL_SRC=... overrides config 'source:' dirs
- out dir wiped before generation (no stale generated files)
- common-policy validation + warnings; scale-aware acceptance scripts" || exit 1

echo "== tag =="
git tag -a v1.1.0 -m "RTL Namespace Manager v1.1.0" || exit 1
echo "tags:" && git tag

echo "== push =="
GIT_TERMINAL_PROMPT=0 git push origin main 2>&1
RC1=$?
GIT_TERMINAL_PROMPT=0 git push origin v1.1.0 2>&1
RC2=$?
echo "push_main_rc=$RC1 push_tag_rc=$RC2"
if [ $RC1 -eq 0 ] && [ $RC2 -eq 0 ]; then
    echo "RELEASE_PUSH_OK"
else
    echo "RELEASE_PUSH_FAIL"
    exit 1
fi
echo "== log =="
git log --oneline -3
echo "== verify remote head =="
git ls-remote --tags --heads origin | tail -4
