# Makefile for semi-latex-nix

# Configuration
LATEXMK = latexmk
# Use absolute path for .latexmkrc
ROOT_DIR := $(shell pwd)

# Environment variables for TeX search paths
# Add style directory to TEXINPUTS and BSTINPUTS
# // means search recursively. The trailing colon is important to include system paths.
export TEXINPUTS := .:$(ROOT_DIR)/style//:
export BSTINPUTS := .:$(ROOT_DIR)/style//:

LATEXMK_FLAGS = -r $(ROOT_DIR)/.latexmkrc -pdfdvi -shell-escape

# -----------------------------------------------------------------------------
# Execution Environment Detection
# -----------------------------------------------------------------------------
# Check if nix command is available
HAS_NIX := $(shell command -v nix 2> /dev/null)
# Check if latexmk is available
HAS_LATEXMK := $(shell command -v latexmk 2> /dev/null)

ifdef SEMI_LATEX_ENV
    # Case 1: Inside Nix shell or Docker container (SEMI_LATEX_ENV is set)
    EXEC_CMD := bash -c
else ifneq ($(HAS_NIX),)
    # Case 2: Nix is available but not in shell -> Use nix develop
    EXEC_CMD := nix develop --command bash -c
else ifneq ($(HAS_LATEXMK),)
    # Case 3: No Nix, but latexmk exists (Host with tools) -> Run directly
    EXEC_CMD := bash -c
else
    # Case 4 (Error): No Nix and no latexmk
    $(error "No 'nix' command found and 'latexmk' is not in PATH. Please install Nix or LaTeX environment.")
endif

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
	@$(EXEC_CMD) "cd $(1) && \
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
	@$(EXEC_CMD) "cd $(1) && $(LATEXMK) -r $(ROOT_DIR)/.latexmkrc -C"
	rm -rf $(1)/.svg-inkscape
endef

define watch_smart
	@echo "Watching in: $(1)"
	@$(EXEC_CMD) "cd $(1) && \
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

# -----------------------------------------------------------------------------
# Explicit Directory Targets
# -----------------------------------------------------------------------------
# Support for `make build <dir>`, `make clean <dir>`, `make watch <dir>`
SUPPORTED_COMMANDS := build clean watch
ifneq ($(filter $(firstword $(MAKECMDGOALS)),$(SUPPORTED_COMMANDS)),)
    # Extract the directory argument (everything after the command)
    DIR_ARG := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
    # Turn the directory argument into a no-op target to prevent make from complaining
    $(eval $(DIR_ARG):;@:)
endif

.PHONY: build clean watch

build:
	@if [ -z "$(DIR_ARG)" ]; then \
		echo "Error: Directory not specified."; \
		echo "Usage: make build <directory>"; \
		exit 1; \
	fi
	@if [ ! -d "$(DIR_ARG)" ]; then \
		echo "Error: Directory '$(DIR_ARG)' does not exist."; \
		exit 1; \
	fi
	$(call build_smart,$(DIR_ARG))

clean:
	@if [ -z "$(DIR_ARG)" ]; then \
		echo "Error: Directory not specified."; \
		echo "Usage: make clean <directory>"; \
		exit 1; \
	fi
	@if [ ! -d "$(DIR_ARG)" ]; then \
		echo "Error: Directory '$(DIR_ARG)' does not exist."; \
		exit 1; \
	fi
	$(call clean_smart,$(DIR_ARG))

watch:
	@if [ -z "$(DIR_ARG)" ]; then \
		echo "Error: Directory not specified."; \
		echo "Usage: make watch <directory>"; \
		exit 1; \
	fi
	@if [ ! -d "$(DIR_ARG)" ]; then \
		echo "Error: Directory '$(DIR_ARG)' does not exist."; \
		exit 1; \
	fi
	$(call watch_smart,$(DIR_ARG))

# -----------------------------------------------------------------------------
# Test
# -----------------------------------------------------------------------------
.PHONY: test _test_run

test:
	@# Optimization: If Nix is available but we are not in the environment,
	@# enter the environment once for the entire test suite.
ifneq ($(HAS_NIX),)
ifndef SEMI_LATEX_ENV
	@echo "Entering Nix environment for test suite..."
	@nix develop --command $(MAKE) _test_run
else
	@$(MAKE) _test_run
endif
else
	@$(MAKE) _test_run
endif

_test_run:
	@echo "========================================"
	@echo "TESTING ALL SAMPLE PROJECTS"
	@echo "========================================"
	@failed=0; \
	for dir in sample/*; do \
		if [ -d "$$dir" ]; then \
			echo ""; \
			$(MAKE) clean $$dir > /dev/null 2>&1; \
			if $(MAKE) build $$dir; then \
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
# Generic Rule (Must be last)
# -----------------------------------------------------------------------------
# Prevent make from trying to rebuild the Makefile itself
Makefile:;

# Helper targets for generic directory operations
.PHONY: _build_dir _clean_dir _watch_dir
_build_dir:
	$(call build_smart,$(TARGET_DIR))

_clean_dir:
	$(call clean_smart,$(TARGET_DIR))

_watch_dir:
	$(call watch_smart,$(TARGET_DIR))

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
help:
	@echo "Usage:"
	@echo "  make build <path>          Build project in <path>"
	@echo "  make clean <path>          Clean project in <path>"
	@echo "  make watch <path>          Watch project in <path>"
	@echo ""
	@echo "Examples:"
	@echo "  make build sample/semi-sample"
	@echo "  make build my-seminar-paper"
	@echo "  make clean sample/semi-sample"
