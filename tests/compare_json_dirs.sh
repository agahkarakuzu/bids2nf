#!/bin/bash

# Simple script to compare JSON files between expected and new output directories
# Usage: ./compare_json_dirs.sh <expected_dir> <new_dir>

if [ $# -ne 2 ]; then
    echo "Usage: $0 <expected_dir> <new_dir>"
    exit 1
fi

EXPECTED_DIR="$1"
NEW_DIR="$2"
ERROR_COUNT=0

echo "Comparing JSON files between:"
echo "  Expected: $EXPECTED_DIR"
echo "  New:      $NEW_DIR"
echo

# Find all JSON files in both directories
cd "$EXPECTED_DIR" && find . -name "*.json" | sort > /tmp/expected_files.txt
cd "$NEW_DIR" && find . -name "*.json" | sort > /tmp/new_files.txt

# Find missing files (in expected but not in new)
missing=$(comm -23 /tmp/expected_files.txt /tmp/new_files.txt)
if [ -n "$missing" ]; then
    echo "❌ MISSING files (in expected but not in new):"
    echo "$missing" | sed 's/^/  /'
    echo
    ERROR_COUNT=$((ERROR_COUNT + $(echo "$missing" | wc -l)))
fi

# Find extra files (in new but not in expected)
extra=$(comm -13 /tmp/expected_files.txt /tmp/new_files.txt)
if [ -n "$extra" ]; then
    echo "⚠️  EXTRA files (in new but not in expected):"
    echo "$extra" | sed 's/^/  /'
    echo
    ERROR_COUNT=$((ERROR_COUNT + $(echo "$extra" | wc -l)))
fi

# Compare matching files
echo "📋 Comparing matching JSON files:"
comm -12 /tmp/expected_files.txt /tmp/new_files.txt | while read -r file; do
    if cmp -s "$EXPECTED_DIR/$file" "$NEW_DIR/$file"; then
        echo "  ✅ $file: identical"
    else
        echo "  ❌ $file: differs"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        # Optionally show diff
        # diff "$EXPECTED_DIR/$file" "$NEW_DIR/$file" | head -10
    fi
done

# Cleanup
rm -f /tmp/expected_files.txt /tmp/new_files.txt

# Exit with error if any issues found
if [ $ERROR_COUNT -gt 0 ]; then
    echo
    echo "❌ Found $ERROR_COUNT issues. Exiting with error."
    exit 1
else
    echo
    echo "✅ All JSON files match perfectly!"
    exit 0
fi