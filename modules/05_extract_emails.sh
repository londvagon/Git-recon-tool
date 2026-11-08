#!/usr/bin/env bash
# 05_extract_emails.sh - Step 4c: Extract clean email addresses from the whole repo
# Usage: bash 05_extract_emails.sh <target_dir> <output_dir>

set -euo pipefail

TARGET_DIR="$1"
OUTPUT_DIR="$2"
EMAIL_FILE="$OUTPUT_DIR/05_emails.txt"

: > "$EMAIL_FILE"

echo "=== Email Address Extraction ===" | tee -a "$EMAIL_FILE"

# --- 1. Extract author and committer emails from every commit ---
# '%aE' = author email, '%cE' = committer email.
# This catches all identities that ever interacted with the repository.
echo "" >> "$EMAIL_FILE"
echo "--- Emails from author/committer fields ---" >> "$EMAIL_FILE"
git -C "$TARGET_DIR" log --all --pretty=format:"%aE%n%cE" 2>/dev/null \
    | grep -E -o '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
    | sort -u >> "$EMAIL_FILE" || true

# --- 2. Extract emails from commit messages (trailers like Co-authored-by, Signed-off-by) ---
echo "" >> "$EMAIL_FILE"
echo "--- Emails from commit messages ---" >> "$EMAIL_FILE"
git -C "$TARGET_DIR" log --all --pretty=format:"%B" 2>/dev/null \
    | grep -E -o '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
    | sort -u >> "$EMAIL_FILE" || true

# --- 3. Extract emails from file content (tracked files + history) ---
echo "" >> "$EMAIL_FILE"
echo "--- Emails from file content (current and historical) ---" >> "$EMAIL_FILE"
{
    # Current files
    git -C "$TARGET_DIR" grep -h -I -E -o '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' -- . 2>/dev/null || true
    # Historical content
    git -C "$TARGET_DIR" log -p --all 2>/dev/null \
        | grep -E -o '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' || true
} | sort -u >> "$EMAIL_FILE"

# --- 4. Clean up and display final unique list ---
# Remove empty lines and the section headers we added
CLEAN_EMAILS=$(grep -v -E '^(===|---|$)' "$EMAIL_FILE" | sort -u)

{
    echo ""
    echo "=== FINAL UNIQUE EMAIL LIST ==="
    echo "$CLEAN_EMAILS"
    echo ""
    echo "Total unique emails: $(echo "$CLEAN_EMAILS" | grep -c '@' || echo 0)"
} > "${EMAIL_FILE}.final"

# Overwrite the main file with the clean final version
mv "${EMAIL_FILE}.final" "$EMAIL_FILE"

echo ""
echo "Unique emails found: $(grep -c '@' "$EMAIL_FILE" 2>/dev/null || echo 0)"
echo "Saved to: $EMAIL_FILE"
cat "$EMAIL_FILE"
