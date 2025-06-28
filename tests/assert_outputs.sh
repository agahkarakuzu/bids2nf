#!/usr/bin/env bash

# Usage: ./assert_outputs.sh <dir1> <dir2>
set -euo pipefail

DIR1="${1:-}"
DIR2="${2:-}"

if [[ -z "$DIR1" || -z "$DIR2" ]]; then
  echo "Usage: $0 <dir1> <dir2>"
  exit 1
fi

# Gather sorted lists of relative file paths
mapfile -t FILES1 < <(cd "$DIR1" && find . -type f | sort)
mapfile -t FILES2 < <(cd "$DIR2" && find . -type f | sort)

# Check file lists match
if ! diff <(printf "%s\n" "${FILES1[@]}") <(printf "%s\n" "${FILES2[@]}") > /dev/null; then
  echo "❌ File path mismatch between $DIR1 and $DIR2"
  echo "Differences:"
  diff <(printf "%s\n" "${FILES1[@]}") <(printf "%s\n" "${FILES2[@]}")
  exit 1
fi

# Compare file contents
for relpath in "${FILES1[@]}"; do
  if ! cmp -s "$DIR1/$relpath" "$DIR2/$relpath"; then
    echo "❌ Content mismatch in: $relpath"
    echo "---- $DIR1/$relpath ----"
    cat "$DIR1/$relpath"
    echo "---- $DIR2/$relpath ----"
    cat "$DIR2/$relpath"
    exit 1
  fi
done

echo "✅ All files and their contents match between $DIR1 and $DIR2"
