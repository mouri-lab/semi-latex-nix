# Makefile for semi-latex-mk2

# Configuration
NIX_CMD = nix develop --command bash -c
LATEXMK = latexmk
# Use absolute path for .latexmkrc
ROOT_DIR := $(shell pwd)

# Environment variables for TeX search paths
# Add style directory to TEXINPUTS and BSTINPUTS
# // means search recursively. The trailing colon is important to include system paths.
export TEXINPUTS := .:$(ROOT_DIR)/style//:
export BSTINPUTS := .:$(ROOT_DIR)/style//:

LATEXMK_FLAGS = -r $(ROOT_DIR)/.latexmkrc -pdfdvi -shell-escape

# Default target
.PHONY: all
all: help

# -----------------------------------------------------------------------------
# Smart Build Logic
# -----------------------------------------------------------------------------
# Finds the first .tex file containing \documentclass and builds it.
# If none found, falls back to the first .tex file.
define build_smart
	@echo "========================================"
	@echo "Building project in: $(1)"
	@echo "========================================"
	@$(NIX_CMD) "cd $(1) && \
	TARGET_TEX=\$$(grep -l '\\\\documentclass' *.tex 2>/dev/null | head -n 1); \
	if [ -z \"\$$TARGET_TEX\" ]; then \
		echo 'Warning: No file with \\documentclass found. Falling back to first .tex file.'; \
		TARGET_TEX=\$$(ls *.tex 2>/dev/null | head -n 1); \
	fi; \
	if [ -z \"\$$TARGET_TEX\" ]; then \
		echo 'Error: No .tex files found in $(1)'; \
		exit 1; \
	fi; \
	echo \"Detected main file: \$$TARGET_TEX\"; \
	$(LATEXMK) $(LATEXMK_FLAGS) \"\$$TARGET_TEX\""
endef

define clean_smart
	@echo "Cleaning in: $(1)"
	@$(NIX_CMD) "cd $(1) && $(LATEXMK) -r $(ROOT_DIR)/.latexmkrc -C"
	rm -rf $(1)/.svg-inkscape
endef

define watch_smart
	@echo "Watching in: $(1)"
	@$(NIX_CMD) "cd $(1) && \
	TARGET_TEX=\$$(grep -l '\\\\documentclass' *.tex 2>/dev/null | head -n 1); \
	if [ -z \"\$$TARGET_TEX\" ]; then \
		TARGET_TEX=\$$(ls *.tex 2>/dev/null | head -n 1); \
	fi; \
	if [ -z \"\$$TARGET_TEX\" ]; then \
		echo 'Error: No .tex files found in $(1)'; \
		exit 1; \
	fi; \
	echo \"Detected main file: \$$TARGET_TEX\"; \
	$(LATEXMK) -pvc $(LATEXMK_FLAGS) \"\$$TARGET_TEX\""
endef

# -----------------------------------------------------------------------------
# Pattern Rules
# -----------------------------------------------------------------------------
# Force execution of pattern rules even if directory exists
.PHONY: force
force: ;

# Build any directory in sample/ (e.g., make sample/my-project)
sample/%: force
	$(call build_smart,$@)

# Clean any directory (e.g., make clean-sample/my-project)
clean-sample/%: force
	$(call clean_smart,sample/$*)

# Watch any directory (e.g., make watch-sample/my-project)
watch-sample/%: force
	$(call watch_smart,sample/$*)

# -----------------------------------------------------------------------------
# Shortcuts
# -----------------------------------------------------------------------------
.PHONY: semi graduation new-graduation master ipsj scis css

semi: sample/semi-sample
graduation: sample/graduation-thesis
new-graduation: sample/newGraduation
master: sample/master-thesis
ipsj: sample/ipsj-report
scis: sample/SCIS_2024
css: sample/css2024_style_unix

# Clean shortcuts
.PHONY: clean-semi clean-graduation clean-new-graduation clean-master clean-ipsj clean-scis clean-css

clean-semi: clean-sample/semi-sample
clean-graduation: clean-sample/graduation-thesis
clean-new-graduation: clean-sample/newGraduation
clean-master: clean-sample/master-thesis
clean-ipsj: clean-sample/ipsj-report
clean-scis: clean-sample/SCIS_2024
clean-css: clean-sample/css2024_style_unix

# Watch shortcuts
.PHONY: watch-semi watch-graduation watch-new-graduation watch-master watch-ipsj watch-scis watch-css

watch-semi: watch-sample/semi-sample
watch-graduation: watch-sample/graduation-thesis
watch-new-graduation: watch-sample/newGraduation
watch-master: watch-sample/master-thesis
watch-ipsj: watch-sample/ipsj-report
watch-scis: watch-sample/SCIS_2024
watch-css: watch-sample/css2024_style_unix

# -----------------------------------------------------------------------------
# Test
# -----------------------------------------------------------------------------
.PHONY: test
test:
	@echo "========================================"
	@echo "TESTING ALL SAMPLE PROJECTS"
	@echo "========================================"
	@failed=0; \
	for dir in sample/*; do \
		if [ -d "$$dir" ]; then \
			echo ""; \
			$(MAKE) clean-sample/$${dir#sample/} > /dev/null 2>&1; \
			if $(MAKE) sample/$${dir#sample/}; then \
				echo "PASS: $$dir"; \
			else \
				echo "FAIL: $$dir"; \
				failed=1; \
			fi; \
		fi; \
	done; \
	echo ""; \
	if [ $$failed -eq 0 ]; then \
		echo "========================================"; \
		echo "ALL TESTS PASSED"; \
		echo "========================================"; \
		exit 0; \
	else \
		echo "========================================"; \
		echo "SOME TESTS FAILED"; \
		echo "========================================"; \
		exit 1; \
	fi

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
help:
	@echo "Usage:"
	@echo "  make <project-name>        Build a specific project (shortcut)"
	@echo "  make sample/<dir-name>     Build any project in sample/ directory"
	@echo "  make clean-<project>       Clean build artifacts"
	@echo "  make watch-<project>       Watch for changes and rebuild"
	@echo ""
	@echo "Projects:"
	@echo "  semi, graduation, new-graduation, master, ipsj, scis, css"
	@echo ""
	@echo "Examples:"
	@echo "  make semi"
	@echo "  make sample/my-new-project"
	@echo "  make clean-semi"
