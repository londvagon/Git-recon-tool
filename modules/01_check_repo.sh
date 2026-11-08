#!/usr/bin/env bash
# 01_check_repo.sh - Step 1 & 2: Check for Git repo and verify initialization
# Usage: bash 01_check_repo.sh <target_dir> <output_dir>

set -euo pipefail

TARGET_DIR="$1"
OUTPUT_DIR="$2"
REPORT="$OUTPUT_DIR/01_repo_check.txt"

{
    echo "=== Git Repository Check ==="
    echo "Target: $TARGET_DIR"
    echo "Date: $(date -Iseconds)"
    echo ""

    # --- Step 1: Check if any Git repository exists ---
    if [[ ! -d "$TARGET_DIR/.git" ]] && ! git -C "$TARGET_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        echo "[FAIL] No Git repository found in $TARGET_DIR"
        echo "       (Neither .git/ directory nor a Git work tree)"
        exit 0
    fi

    echo "[PASS] Git repository detected."

    # --- Step 2: Check if the repository is properly initialized ---
    # Use 'git rev-parse' to confirm the .git directory is valid
    if GIT_DIR=$(git -C "$TARGET_DIR" rev-parse --git-dir 2>/dev/null); then
        echo "[PASS] Git directory is valid: $GIT_DIR"
    else
        echo "[FAIL] .git exists but is not a valid Git directory."
        exit 0
    fi

    # Check if there is at least one commit (HEAD exists)
    if git -C "$TARGET_DIR" rev-parse --verify HEAD >/dev/null 2>&1; then
        echo "[PASS] Repository has at least one commit (HEAD is valid)."
        echo "       Current branch: $(git -C "$TARGET_DIR" branch --show-current 2>/dev/null || echo 'detached')"
        echo "       Total commits:  $(git -C "$TARGET_DIR" rev-list --count HEAD 2>/dev/null || echo '0')"
    else
        echo "[WARN] Repository exists but has no commits yet (unborn HEAD)."
        echo "       Secret extraction will return no results."
    fi

    # Check for remotes (useful OSINT: reveals origin URLs, sometimes with embedded credentials)
    echo ""
    echo "--- Remotes ---"
    git -C "$TARGET_DIR" remote -v 2>/dev/null || echo "(no remotes configured)"

    # Check for branches
    echo ""
    echo "--- Branches ---"
    git -C "$TARGET_DIR" branch -a 2>/dev/null || echo "(no branches)"

} | tee "$REPORT"

echo ""
echo "Report saved to: $REPORT"
