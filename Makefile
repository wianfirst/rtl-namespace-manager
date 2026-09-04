# RTL Namespace Manager - P1 (see P1执行文档.md sec 15)
NAMESPACE_CONFIG := config/namespace.yaml
NAMESPACE_OUT    := build/all
NAMESPACE_TOOL   := tools/rtl_namespace.py

# RTL source directory override: when set (make namespace RTL_SRC=rtlA,rtlB)
# it is passed as --src and replaces the 'source:' dirs from the config for
# every project. When empty, the config's source dirs are used as-is.
RTL_SRC ?=

ifeq ($(strip $(RTL_SRC)),)
SRC_ARG :=
else
SRC_ARG := --src $(RTL_SRC)
endif

.PHONY: namespace namespace_check namespace_dryrun namespace_diff verify sim clean

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

sim: namespace
	vcs -f $(NAMESPACE_OUT)/filelist.f

clean:
	rm -rf $(NAMESPACE_OUT)
