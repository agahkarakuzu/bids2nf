#!/usr/bin/env bash

# Script to run bids2nf workflow tests on multiple BIDS example directories
# Usage: ./run_bids_tests.sh [--profile PROFILE] [directory1] [directory2] ...
# If no directories are provided, it will run on a default set of qMRI directories
# Profile defaults to 'arm64' if not specified

set -e  # Exit on any error

# Default profile
PROFILE="arm64_test"

# Default BIDS directories to test (qMRI focus)
DEFAULT_DIRS=(
    "qmri_vfa"
    "qmri_mpm"
    "qmri_irt1"
    "qmri_megre"
    "qmri_mese"
    "qmri_mp2rage"
    "qmri_mtsat"
    "qmri_qsm"
    "qmri_sa2rage"
    "qmri_tb1tfl"
)

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BIDS_EXAMPLES_DIR="$SCRIPT_DIR/data/bids-examples"

# Parse command line arguments
DIRS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        -p)
            PROFILE="$2"
            shift 2
            ;;
        *)
            DIRS+=("$1")
            shift
            ;;
    esac
done

# Use default directories if none provided
if [ ${#DIRS[@]} -eq 0 ]; then
    DIRS=("${DEFAULT_DIRS[@]}")
    echo "No directories provided. Using default qMRI directories:"
    printf '  %s\n' "${DIRS[@]}"
else
    echo "Testing provided directories:"
    printf '  %s\n' "${DIRS[@]}"
fi

echo "Using profile: $PROFILE"

echo
echo "Starting workflow tests..."
echo "================================"

# Track results
PASSED=0
FAILED=0
FAILED_DIRS=()

for dir in "${DIRS[@]}"; do
    BIDS_DIR="$BIDS_EXAMPLES_DIR/$dir"
    
    echo
    echo "Testing: $dir"
    echo "BIDS directory: $BIDS_DIR"
    
    # Check if directory exists
    if [ ! -d "$BIDS_DIR" ]; then
        echo "ERROR: Directory $BIDS_DIR does not exist"
        FAILED=$((FAILED + 1))
        FAILED_DIRS+=("$dir (directory not found)")
        continue
    fi
    
    echo "Running: nextflow run tests/integration/test_unified_bids2nf.nf --bids_dir $BIDS_DIR -profile $PROFILE"
    
    # Run the workflow
    if cd "$PROJECT_ROOT" && nextflow run tests/integration/test_unified_bids2nf.nf --bids_dir "$BIDS_DIR" -profile "$PROFILE"; then
        echo "✓ PASSED: $dir"
        PASSED=$((PASSED + 1))
    else
        echo "✗ FAILED: $dir"
        FAILED=$((FAILED + 1))
        FAILED_DIRS+=("$dir")
    fi
    
    echo "--------------------------------"
done

# Summary
echo
echo "Test Summary:"
echo "================================"
echo "Total directories tested: $((PASSED + FAILED))"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    echo
    echo "Failed directories:"
    printf '  %s\n' "${FAILED_DIRS[@]}"
    exit 1
else
    echo
    echo "All tests passed! 🎉"
    exit 0
fi