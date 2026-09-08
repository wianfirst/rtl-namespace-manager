# RTL Namespace Manager - P1 (see P1执行文档.md sec 15)
# Every path is overrideable, for example:
#   make namespace RTL_SRC=rtl,ip/rtl NAMESPACE_OUT=out/namespace
NAMESPACE_CONFIG ?= config/namespace.yaml
NAMESPACE_OUT    ?= build/all
NAMESPACE_TOOL   ?= tools/rtl_namespace.py

# Root directory (or comma-separated roots) recursively scanned for RTL.
# This overrides each project's 'source:' setting in NAMESPACE_CONFIG.
RTL_SRC ?= src
SRC_ARG = $(if $(strip $(RTL_SRC)),--src $(RTL_SRC))

.PHONY: namespace namespace_check namespace_dryrun namespace_diff verify verify_overrides sim clean

namespace:
	python3 $(NAMESPACE_TOOL) --config $(NAMESPACE_CONFIG) --out $(NAMESPACE_OUT) $(SRC_ARG)

namespace_check:
	python3 $(NAMESPACE_TOOL) --config $(NAMESPACE_CONFIG) --out $(NAMESPACE_OUT) --check $(SRC_ARG)

namespace_dryrun:
	python3 $(NAMESPACE_TOOL) --config $(NAMESPACE_CONFIG) --out $(NAMESPACE_OUT) --dry-run $(SRC_ARG)

namespace_diff:
	python3 $(NAMESPACE_TOOL) --config $(NAMESPACE_CONFIG) --out $(NAMESPACE_OUT) --diff $(SRC_ARG)

verify:
	python3 scripts/verify_p1.py

verify_overrides:
	python3 scripts/verify_overrides.py

sim: namespace
	vcs -f $(NAMESPACE_OUT)/filelist.f

clean:
	rm -rf $(NAMESPACE_OUT)
