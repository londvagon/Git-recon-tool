#!/usr/bin/env bash
# 04_check_permissions.sh - Step 4b: Check read/write/execute permissions
# Usage: bash 04_check_permissions.sh <target_dir> <output_dir>

set -euo pipefail

TARGET_DIR="$1"
OUTPUT_DIR="$2"
REPORT="$OUTPUT_DIR/04_permissions.txt"

{
    echo "=== File Permission Check ==="
    echo "Target: $TARGET_DIR"
    echo "User:   $(whoami)"
    echo ""

    # --- 1. Check permissions on the .git directory itself ---
    echo "--- .git directory permissions ---"
    if [[ -e "$TARGET_DIR/.git" ]]; then
        ls -ld "$TARGET_DIR/.git"
        echo ""
        echo "Symbolic mode: $(stat -c '%A' "$TARGET_DIR/.git" 2>/dev/null)"
        echo "Numeric mode:  $(stat -c '%a' "$TARGET_DIR/.git" 2>/dev/null)"
        echo ""
        # Test access using test operators (work with the current user's identity)
        [[ -r "$TARGET_DIR/.git" ]] && echo "[YES] .git is READABLE"   || echo "[NO]  .git is NOT readable"
        [[ -w "$TARGET_DIR/.git" ]] && echo "[YES] .git is WRITABLE"   || echo "[NO]  .git is NOT writable"
        [[ -x "$TARGET_DIR/.git" ]] && echo "[YES] .git is EXECUTABLE" || echo "[NO]  .git is NOT executable"
    else
        echo "(.git not found)"
    fi

    # --- 2. Check permissions on all tracked files in HEAD ---
    # 'git ls-tree' shows the mode bits stored in the Git index.
    echo ""
    echo "--- Permissions of tracked files (from Git index) ---"
    echo "Format: <mode> <type> <hash> <path>"
    echo ""
    git -C "$TARGET_DIR" ls-tree -r HEAD 2>/dev/null || echo "(no HEAD)"

    # --- 3. Check actual filesystem permissions for tracked files ---
    echo ""
    echo "--- Actual filesystem permissions for tracked files ---"
    echo "Format: <perms> <user> <group> <path>"
    echo ""
    # Iterate over files in the working tree (if it exists)
    if [[ -d "$TARGET_DIR" ]]; then
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            full_path="$TARGET_DIR/$file"
            if [[ -e "$full_path" ]]; then
                perms=$(stat -c '%A %U %G' "$full_path" 2>/dev/null || echo "???")
                # Test read/write/execute for the current user
                r="r"; w="w"; x="x"
                [[ -r "$full_path" ]] || r="-"
                [[ -w "$full_path" ]] || w="-"
                [[ -x "$full_path" ]] || x="-"
                echo "$perms [$r$w$x] $file"
            fi
        done < <(git -C "$TARGET_DIR" ls-tree -r --name-only HEAD 2>/dev/null || true)
    fi

    # --- 4. Highlight world-writable files (potential privilege escalation) ---
    echo ""
    echo "--- World-writable tracked files (security risk) ---"
    if [[ -d "$TARGET_DIR" ]]; then
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            full_path="$TARGET_DIR/$file"
            if [[ -e "$full_path" ]]; then
                # Check if 'others' have write permission (last triad bit)
                if [[ $(stat -c '%a' "$full_path" 2>/dev/null) =~ [2367]$ ]]; then
                    echo "[WARN] World-writable: $file"
                fi
            fi
        done < <(git -C "$TARGET_DIR" ls-tree -r --name-only HEAD 2>/dev/null || true)
    fi

} | tee "$REPORT"

echo ""
echo "Report saved to: $REPORT"
