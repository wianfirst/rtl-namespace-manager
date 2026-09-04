# RTL Namespace Manager - P1 (see P1执行文档.md sec 15)
NAMESPACE_CONFIG := config/namespace.yaml
NAMESPACE_OUT    := build/all
NAMESPACE_TOOL   := tools/rtl_namespace.py

.PHONY: namespace namespace_check namespace_dryrun sim clean verify

namespace:
	python3 $(NAMESPACE_TOOL) --config $(NAMESPACE_CONFIG) --out $(NAMESPACE_OUT)

namespace_check:
	python3 $(NAMESPACE_TOOL) --config $(NAMESPACE_CONFIG) --out $(NAMESPACE_OUT) --check

namespace_dryrun:
	python3 $(NAMESPACE_TOOL) --config $(NAMESPACE_CONFIG) --out $(NAMESPACE_OUT) --dry-run

namespace_diff:
	python3 $(NAMESPACE_TOOL) --config $(NAMESPACE_CONFIG) --out $(NAMESPACE_OUT) --diff

verify:
	python3 scripts/verify_p1.py

sim: namespace
	vcs -f $(NAMESPACE_OUT)/filelist.f

clean:
	rm -rf $(NAMESPACE_OUT)
