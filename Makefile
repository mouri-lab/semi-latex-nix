# Makefile for semi-latex-nix

# Configuration
LATEXMK = latexmk
# Use absolute path for .latexmkrc
ROOT_DIR := $(shell pwd)

# Temporary build directory (can be overridden)
BUILD_DIR := $(ROOT_DIR)/.build

# Environment variables for TeX search paths
# Add style directory to TEXINPUTS and BSTINPUTS
# // means search recursively. The trailing colon is important to include system paths.
export TEXINPUTS := .:$(ROOT_DIR)/style//:
export BSTINPUTS := .:$(ROOT_DIR)/style//:

# TeX Live variable directory (for font maps, etc.)
export TEXMFVAR := $(ROOT_DIR)/.texlive-var

LATEXMK_FLAGS = -r $(ROOT_DIR)/.latexmkrc -pdfdvi -shell-escape

# Font setup command (IPAex for compatibility with mouri-lab/semi-latex)
# This ensures font maps exist in TEXMFVAR before building
FONT_SETUP_CMD = if [ ! -f \"$(TEXMFVAR)/fonts/map/dvipdfmx/updmap/kanjix.map\" ]; then if ! kanji-config-updmap status 2>/dev/null | grep -q 'CURRENT family for ja: ipaex'; then echo 'Setting Japanese font to IPAex...'; kanji-config-updmap-user ipaex >/dev/null 2>&1 || true; else echo 'Regenerating font maps...'; updmap-user >/dev/null 2>&1 || true; fi; fi

# -----------------------------------------------------------------------------
# Execution Environment Detection
# -----------------------------------------------------------------------------
# Check if nix command is available
HAS_NIX := $(shell command -v nix 2> /dev/null)
# Check if latexmk is available
HAS_LATEXMK := $(shell command -v latexmk 2> /dev/null)
# Check if docker is available
HAS_DOCKER := $(shell command -v docker 2> /dev/null)

# Docker image for LaTeX builds
DOCKER_IMAGE := sakuramourilab/semi-latex-builder

# Docker run command with volume mounts
# Mount the entire project directory and set up environment variables
DOCKER_RUN := docker run --rm \
	-v "$(ROOT_DIR):$(ROOT_DIR)" \
	-w "$(ROOT_DIR)" \
	-e "TEXINPUTS=$(TEXINPUTS)" \
	-e "BSTINPUTS=$(BSTINPUTS)" \
	-e "TEXMFVAR=$(TEXMFVAR)" \
	-e "SEMI_LATEX_ENV=docker" \
	$(DOCKER_IMAGE)

ifdef SEMI_LATEX_ENV
    # Case 1: Inside Nix shell or Docker container (SEMI_LATEX_ENV is set)
    EXEC_CMD := bash -c
else ifneq ($(HAS_NIX),)
    # Case 2: Nix is available but not in shell -> Use nix develop
    EXEC_CMD := nix develop --command bash -c
else ifneq ($(HAS_DOCKER),)
    # Case 3: No Nix, but Docker is available -> Use Docker
    EXEC_CMD := $(DOCKER_RUN) bash -c
else ifneq ($(HAS_LATEXMK),)
    # Case 4: No Nix/Docker, but latexmk exists (Host with tools) -> Run directly
    EXEC_CMD := bash -c
else
    # Case 5 (Error): No Nix, Docker, or latexmk
    $(error "No 'nix', 'docker', or 'latexmk' found. Please install Nix, Docker, or a LaTeX environment.")
endif

# Default target
.PHONY: all
all: help

# -----------------------------------------------------------------------------
# Smart Build Logic
# -----------------------------------------------------------------------------
# Builds in a temporary directory and copies back only the PDF and log files.
# This keeps the source directory clean.

# Files to exclude when syncing to build directory (LaTeX intermediate files)
RSYNC_EXCLUDE := --exclude='*.aux' --exclude='*.bbl' --exclude='*.blg' \
	--exclude='*.dvi' --exclude='*.fdb_latexmk' --exclude='*.fls' \
	--exclude='*.log' --exclude='*.out' --exclude='*.toc' --exclude='*.lof' \
	--exclude='*.lot' --exclude='*.synctex' --exclude='*.synctex.gz' \
	--exclude='*.nav' --exclude='*.snm' --exclude='*.vrb' \
	--exclude='.svg-inkscape'

define build_smart
	@echo "========================================"
	@echo "Building project in: $(1)"
	@echo "========================================"
	@# Ensure font maps are set up
	@$(EXEC_CMD) "$(FONT_SETUP_CMD)"
	@# Create temp build directory
	@mkdir -p "$(BUILD_DIR)/$(1)"
	@# Copy source files to build directory (excluding intermediate files)
	@rsync -a --delete $(RSYNC_EXCLUDE) "$(1)/" "$(BUILD_DIR)/$(1)/"
	@$(EXEC_CMD) "cd $(BUILD_DIR)/$(1) && \
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
	$(LATEXMK) $(LATEXMK_FLAGS) \"\$$TARGET_TEX\" && \
	TARGET_BASE=\$$(echo \"\$$TARGET_TEX\" | sed 's/\.tex\$$//') && \
	cp -f \"\$$TARGET_BASE.pdf\" '$(ROOT_DIR)/$(1)/' && \
	{ cp -f \"\$$TARGET_BASE.log\" '$(ROOT_DIR)/$(1)/' 2>/dev/null || true; } && \
	{ cp -f \"\$$TARGET_BASE.blg\" '$(ROOT_DIR)/$(1)/' 2>/dev/null || true; }"
	@echo "----------------------------------------"
	@echo "Build complete. Artifacts copied to $(1)"
endef

define clean_smart
	@echo "Cleaning in: $(1)"
	@# Remove build directory for this project
	@rm -rf "$(BUILD_DIR)/$(1)"
	@echo "Cleaned build directory for $(1)"
endef

# Clean intermediate files from source directory (for migration from old build system)
define clean_source_smart
	@echo "Cleaning intermediate files in source: $(1)"
	@rm -f $(1)/*.aux $(1)/*.bbl $(1)/*.blg $(1)/*.dvi $(1)/*.fdb_latexmk \
		$(1)/*.fls $(1)/*.out $(1)/*.toc $(1)/*.lof $(1)/*.lot \
		$(1)/*.synctex $(1)/*.synctex.gz $(1)/*.nav $(1)/*.snm $(1)/*.vrb $(1)/*.w18
	@rm -rf $(1)/.svg-inkscape
	@echo "Cleaned intermediate files in $(1)"
endef

define watch_smart
	@echo "Watching in: $(1)"
	@echo "========================================"
	@# Ensure font maps are set up
	@$(EXEC_CMD) "$(FONT_SETUP_CMD)"
	@# Create temp build directory
	@mkdir -p "$(BUILD_DIR)/$(1)"
	@# Initial copy of source files (excluding intermediate files)
	@rsync -a --delete $(RSYNC_EXCLUDE) "$(1)/" "$(BUILD_DIR)/$(1)/"
	@# Initial build and detect target file
	@$(EXEC_CMD) "cd $(BUILD_DIR)/$(1) && \
	TARGET_TEX=\$$(grep -l '\\\\documentclass' *.tex 2>/dev/null | head -n 1); \
	if [ -z \"\$$TARGET_TEX\" ]; then \
		TARGET_TEX=\$$(ls *.tex 2>/dev/null | head -n 1); \
	fi; \
	if [ -z \"\$$TARGET_TEX\" ]; then \
		echo 'Error: No .tex files found in $(1)'; \
		exit 1; \
	fi; \
	echo \"Detected main file: \$$TARGET_TEX\"; \
	echo \"\$$TARGET_TEX\" > .target_tex; \
	TARGET_BASE=\$$(echo \"\$$TARGET_TEX\" | sed 's/\.tex\$$//'); \
	$(LATEXMK) $(LATEXMK_FLAGS) \"\$$TARGET_TEX\" && \
	cp -f "\$$TARGET_BASE.pdf" '$(ROOT_DIR)/$(1)/' && \
	{ cp -f "\$$TARGET_BASE.log" '$(ROOT_DIR)/$(1)/' 2>/dev/null || true; } && \
	{ cp -f "\$$TARGET_BASE.blg" '$(ROOT_DIR)/$(1)/' 2>/dev/null || true; }"
	@# Open PDF after initial build
	@TARGET_BASE=$$(cat "$(BUILD_DIR)/$(1)/.target_tex" | sed 's/\.tex$$//'); \
	if command -v open >/dev/null 2>&1; then \
		open "$(1)/$$TARGET_BASE.pdf" 2>/dev/null || true; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open "$(1)/$$TARGET_BASE.pdf" 2>/dev/null || true; \
	fi
	@# Get target basename for excluding output files
	@TARGET_BASE=$$(cat "$(BUILD_DIR)/$(1)/.target_tex" | sed 's/\.tex$$//'); \
	echo "========================================"; \
	echo "Watching for changes in: $(1)"; \
	echo "Excluding: $$TARGET_BASE*.pdf, $$TARGET_BASE*.log, $$TARGET_BASE*.blg"; \
	echo "Press Ctrl+C to stop."; \
	echo "========================================"; \
	fswatch --event Created --event Updated --event Removed --event Renamed --event MovedFrom --event MovedTo \
		-e "$$TARGET_BASE.*\.pdf$$" \
		-e "$$TARGET_BASE.*\.log$$" \
		-e "$$TARGET_BASE.*\.blg$$" \
		"$(1)" | while read CHANGED_FILE; do \
		echo ""; \
		echo "Change detected: $$CHANGED_FILE"; \
		echo "Rebuilding..."; \
		rsync -a --delete $(RSYNC_EXCLUDE) --exclude='.target_tex' "$(1)/" "$(BUILD_DIR)/$(1)/"; \
		$(EXEC_CMD) "cd $(BUILD_DIR)/$(1) && \
			TARGET_TEX=\$$(cat .target_tex) && \
			TARGET_BASE=\$$(echo \"\$$TARGET_TEX\" | sed 's/\\.tex\$$//') && \
			$(LATEXMK) $(LATEXMK_FLAGS) \"\$$TARGET_TEX\" && \
			cp -f "\$$TARGET_BASE.pdf" '$(ROOT_DIR)/$(1)/' && \
			{ cp -f "\$$TARGET_BASE.log" '$(ROOT_DIR)/$(1)/' 2>/dev/null || true; } && \
			{ cp -f "\$$TARGET_BASE.blg" '$(ROOT_DIR)/$(1)/' 2>/dev/null || true; }"; \
		echo "========================================"; \
		echo "Waiting for changes..."; \
	done
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
SUPPORTED_COMMANDS := build clean clean-source watch
ifneq ($(filter $(firstword $(MAKECMDGOALS)),$(SUPPORTED_COMMANDS)),)
    # Extract the directory argument (everything after the command)
    DIR_ARG := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
    # Turn the directory argument into a no-op target to prevent make from complaining
    $(eval $(DIR_ARG):;@:)
endif

.PHONY: build clean clean-source watch clean-all

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

clean-source:
	@if [ -z "$(DIR_ARG)" ]; then \
		echo "Error: Directory not specified."; \
		echo "Usage: make clean-source <directory>"; \
		exit 1; \
	fi
	@if [ ! -d "$(DIR_ARG)" ]; then \
		echo "Error: Directory '$(DIR_ARG)' does not exist."; \
		exit 1; \
	fi
	$(call clean_source_smart,$(DIR_ARG))

clean-all:
	@echo "Cleaning all build artifacts..."
	@rm -rf "$(BUILD_DIR)"
	@echo "Removed $(BUILD_DIR)"

# -----------------------------------------------------------------------------
# Docker Image Management
# -----------------------------------------------------------------------------
.PHONY: docker-pull

docker-pull:
ifneq ($(HAS_DOCKER),)
	@echo "Pulling latest Docker image: $(DOCKER_IMAGE)"
	@docker pull $(DOCKER_IMAGE):latest
else
	@echo "Error: Docker is not available."
	@exit 1
endif

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
	@# Optimization: If Nix or Docker is available but we are not in the environment,
	@# enter the environment once for the entire test suite.
ifneq ($(HAS_NIX),)
ifndef SEMI_LATEX_ENV
	@echo "Entering Nix environment for test suite..."
	@nix develop --command $(MAKE) _test_run
else
	@$(MAKE) _test_run
endif
else ifneq ($(HAS_DOCKER),)
ifndef SEMI_LATEX_ENV
	@echo "Entering Docker environment for test suite..."
	@$(DOCKER_RUN) $(MAKE) _test_run
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
	@echo "  make clean <path>          Clean build directory for <path>"
	@echo "  make clean-source <path>   Clean intermediate files from source <path>"
	@echo "  make clean-all             Clean all build artifacts (.build directory)"
	@echo "  make watch <path>          Watch project in <path>"
	@echo "  make docker-pull           Pull latest Docker image (Docker environment only)"
	@echo ""
	@echo "Build artifacts are stored in: $(BUILD_DIR)"
	@echo "Only PDF and log files are copied back to source directory."
	@echo ""
	@echo "Execution Environment (auto-detected):"
	@echo "  1. Nix (nix develop)       - if 'nix' command is available"
	@echo "  2. Docker                  - if 'docker' is available (uses $(DOCKER_IMAGE))"
	@echo "  3. Host LaTeX              - if 'latexmk' is in PATH"
	@echo ""
	@echo "Examples:"
	@echo "  make build sample/semi-sample"
	@echo "  make build my-seminar-paper"
	@echo "  make clean sample/semi-sample"
	@echo "  make clean-source semi/20251205   # Remove old intermediate files"
	@echo "  make clean-all"
