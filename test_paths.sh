#!/bin/bash

ROOT_DIR="/home/runner/work/semi-latex-nix/semi-latex-nix"
BUILD_DIR="$ROOT_DIR/.build"

# Test function
test_path() {
    DIR_ARG="$1"
    echo "Testing: $DIR_ARG"
    
    # Convert to absolute path
    TARGET_ABS=$(cd "$DIR_ARG" 2>/dev/null && pwd)
    echo "  Absolute: $TARGET_ABS"
    
    # Check if inside ROOT_DIR
    case "$TARGET_ABS" in
        "$ROOT_DIR"*)
            echo "  Location: Internal"
            TARGET_REL=$(realpath --relative-to="$ROOT_DIR" "$TARGET_ABS")
            BUILD_PATH="$BUILD_DIR/$TARGET_REL"
            echo "  Relative: $TARGET_REL"
            ;;
        *)
            echo "  Location: External"
            BUILD_NAME=$(echo "$TARGET_ABS" | sed 's|^/|_external_|' | sed 's|/|_|g')
            BUILD_PATH="$BUILD_DIR/$BUILD_NAME"
            ;;
    esac
    echo "  Build path: $BUILD_PATH"
    echo ""
}

# Test cases
test_path "sample/semi-sample"
test_path "../external-project"
test_path "/home/runner/work/external-project"

