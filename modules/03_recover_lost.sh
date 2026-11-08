#!/usr/bin/env bash
# 03_recover_lost.sh - Step 4a: Recover deleted or dangling files
# Usage: bash 03_recover_lost.sh <target_dir> <output_dir>

set -euo pipefail

TARGET_DIR="$1"
OUTPUT_DIR="$2"
RECOVER_DIR="$OUTPUT_DIR/recovered_files"
REPORT="$OUTPUT_DIR/03_recovery_report.txt"

mkdir -p "$RECOVER_DIR"
: > "$REPORT"

echo "=== Lost / Deleted File Recovery ===" | tee -a "$REPORT"

# --- 1. Use 'git fsck' to find dangling commits and blobs ---
# Dangling objects are files or commits that are no longer reachable from any branch.
# They remain in .git/objects until garbage collection.
echo "" | tee -a "$REPORT"
echo "--- Dangling objects (git fsck) ---" | tee -a "$REPORT"

DANGLING_OUTPUT=$(git -C "$TARGET_DIR" fsck --full --unreachable --dangling 2>/dev/null || true)
echo "$DANGLING_OUTPUT" | tee -a "$REPORT"

# Extract dangling commit hashes
DANGLING_COMMITS=$(echo "$DANGLING_OUTPUT" | grep 'dangling commit' | awk '{print $3}' || true)
if [[ -n "$DANGLING_COMMITS" ]]; then
    echo "" | tee -a "$REPORT"
    echo "--- Recovering files from dangling commits ---" | tee -a "$REPORT"

    while IFS= read -r commit; do
        echo "Processing dangling commit: $commit" | tee -a "$REPORT"

        # List files in the dangling commit
        git -C "$TARGET_DIR" ls-tree -r --name-only "$commit" 2>/dev/null | while IFS= read -r file; do

            # Sanitize filename for local storage
            safe_name=$(echo "$file" | tr '/' '_')
            out_path="$RECOVER_DIR/${commit:0:8}_${safe_name}"
            git -C "$TARGET_DIR" show "$commit:$file" > "$out_path" 2>/dev/null || true
            if [[ -s "$out_path" ]]; then
                echo "  Recovered: $file -> $out_path" | tee -a "$REPORT"
            fi
        done
    done <<< "$DANGLING_COMMITS"
fi

# --- 2. Recover explicitly deleted files from history ---
# 'git log --diff-filter=D' shows commits where files were deleted.
echo "" | tee -a "$REPORT"
echo "--- Files deleted in history (git log --diff-filter=D) ---" | tee -a "$REPORT"

git -C "$TARGET_DIR" log --all --diff-filter=D --name-only --pretty=format:"%h %s" 2>/dev/null | tee -a "$REPORT"

# --- 3. Attempt to restore deleted files from the commit BEFORE deletion ---
echo "" | tee -a "$REPORT"
echo "--- Restoring deleted files from parent commit ---" | tee -a "$REPORT"

# Collect unique file paths that were deleted
DELETED_FILES=$(git -C "$TARGET_DIR" log --all --diff-filter=D --name-only --pretty=format: 2>/dev/null | sort -u | grep -v '^$' || true)
if [[ -n "$DELETED_FILES" ]]; then
    while IFS= read -r file; do
        # Find the last commit that touched this file and get its parent
        parent_commit=$(git -C "$TARGET_DIR" log --all --diff-filter=D --pretty=format:"%H" -- "$file" 2>/dev/null | head -n1)
        if [[ -n "$parent_commit" ]]; then
            safe_name=$(echo "$file" | tr '/' '_')
            out_path="$RECOVER_DIR/deleted_${parent_commit:0:8}_${safe_name}"
            # The file exists in the parent of the deletion commit
            if git -C "$TARGET_DIR" show "${parent_commit}^:${file}" > "$out_path" 2>/dev/null && [[ -s "$out_path" ]]; then
                echo "  Restored: $file -> $out_path" | tee -a "$REPORT"
            fi
        fi
    done <<< "$DELETED_FILES"
else
    echo "  (no deleted files found in history)" | tee -a "$REPORT"
fi

# --- 4. Check reflog for lost commits (if reflog exists) ---
echo "" | tee -a "$REPORT"
echo "--- Reflog entries (lost commits) ---" | tee -a "$REPORT"
git -C "$TARGET_DIR" reflog --date=iso 2>/dev/null | tee -a "$REPORT" || echo "(no reflog available)" | tee -a "$REPORT"

echo ""
echo "Recovered files are in: $RECOVER_DIR"
echo "Full report: $REPORT"
