#!/usr/bin/env bash
# 02_extract_secrets.sh - Step 3: Extract secrets, configs, passwords, hashes
# Usage: bash 02_extract_secrets.sh <target_dir> <output_dir>

set -euo pipefail

TARGET_DIR="$1"
OUTPUT_DIR="$2"
SECRETS_FILE="$OUTPUT_DIR/02_secrets_found.txt"
CONFIG_FILE="$OUTPUT_DIR/02_configs_found.txt"
HASH_FILE="$OUTPUT_DIR/02_hashes_found.txt"

: > "$SECRETS_FILE"
: > "$CONFIG_FILE"
: > "$HASH_FILE"

echo "=== Secret, Config and Hash Extraction ===" | tee -a "$SECRETS_FILE"

# --- 1. Search current working tree for secrets ---
# Use 'git grep' to search only tracked files (fast and accurate)
SECRET_PATTERNS='(password|passwd|secret|api_key|apikey|token|credential|private_key|BEGIN RSA|AKIA|sk_live|ghp_|xox[bp]-)'

echo "" >> "$SECRETS_FILE"
echo "--- Current files (git grep) ---" >> "$SECRETS_FILE"
git -C "$TARGET_DIR" grep -n -i -E "$SECRET_PATTERNS" -- . 2>/dev/null >> "$SECRETS_FILE" || true

# --- 2. Search entire commit history (including deleted content) ---
# 'git log -p' shows the full diff of every commit.
# Piping through grep finds secrets even if the file was later deleted.
echo "" >> "$SECRETS_FILE"
echo "--- Historical commits (git log -p) ---" >> "$SECRETS_FILE"
git -C "$TARGET_DIR" log -p --all 2>/dev/null | grep -i -E "$SECRET_PATTERNS" >> "$SECRETS_FILE" || true

# --- 3. Find configuration files in history ---
# Common config files often contain hardcoded credentials.
CONFIG_PATTERNS='(\.env$|config\.(php|py|js|json|yml|yaml|xml|ini)|\.(npmrc|pypirc|htpasswd|netrc|pgpass)$|wp-config\.php|database\.yml|settings\.py)'

echo "" > "$CONFIG_FILE"
echo "--- Config files mentioned in history ---" >> "$CONFIG_FILE"
git -C "$TARGET_DIR" log --all --name-only --pretty=format: 2>/dev/null \
    | sort -u \
    | grep -i -E "$CONFIG_PATTERNS" >> "$CONFIG_FILE" || true

# Also try to show the content of the most interesting config files from HEAD
echo "" >> "$CONFIG_FILE"
echo "--- Content of config files at HEAD ---" >> "$CONFIG_FILE"
while IFS= read -r cfg; do
    [[ -z "$cfg" ]] && continue
    echo "### $cfg" >> "$CONFIG_FILE"
    git -C "$TARGET_DIR" show "HEAD:$cfg" 2>/dev/null >> "$CONFIG_FILE" || true
    echo "" >> "$CONFIG_FILE"
done < <(git -C "$TARGET_DIR" ls-tree -r --name-only HEAD 2>/dev/null | grep -i -E "$CONFIG_PATTERNS" || true)

# --- 4. Extract hashes ---
# Hash-like strings are often password hashes (MD5, SHA1, SHA256, bcrypt).
HASH_PATTERNS='(\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}|[a-f0-9]{32}|[a-f0-9]{40}|[a-f0-9]{64})'

echo "" > "$HASH_FILE"
echo "--- Potential hashes in current files ---" >> "$HASH_FILE"
git -C "$TARGET_DIR" grep -n -E "$HASH_PATTERNS" -- . 2>/dev/null >> "$HASH_FILE" || true

echo "" >> "$HASH_FILE"
echo "--- Potential hashes in history ---" >> "$HASH_FILE"
git -C "$TARGET_DIR" log -p --all 2>/dev/null | grep -E "$HASH_PATTERNS" >> "$HASH_FILE" || true

# --- Summary ---
SECRET_COUNT=$(grep -c -v -E '^(===|---|$)' "$SECRETS_FILE" 2>/dev/null || echo 0)
CONFIG_COUNT=$(grep -c -v -E '^(===|---|###|$)' "$CONFIG_FILE" 2>/dev/null || echo 0)
HASH_COUNT=$(grep -c -v -E '^(===|---|$)' "$HASH_FILE" 2>/dev/null || echo 0)

echo ""
echo "[RESULT] Secrets/credentials lines : $SECRET_COUNT"
echo "[RESULT] Config file references    : $CONFIG_COUNT"
echo "[RESULT] Hash-like strings         : $HASH_COUNT"
echo "Files saved: $SECRETS_FILE, $CONFIG_FILE, $HASH_FILE"
