#!/usr/bin/env bash
# main.sh - Main controller for Git reconnaissance
# Usage: ./main.sh /path/to/repository

set -euo pipefail

# --- Configuration ---
TARGET_DIR="${1:-.}"
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/modules"
OUTPUT_DIR="${PWD}/recon_output"

# --- Helper functions ---
log_info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
log_ok()    { echo -e "\033[1;32m[OK]\033[0m    $*"; }
log_warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# --- Sanity check ---
if [[ ! -d "$TARGET_DIR" ]]; then
    log_error "Directory '$TARGET_DIR' does not exist."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
log_info "Starting Git reconnaissance on: $TARGET_DIR"
log_info "Output directory: $OUTPUT_DIR"

# --- Run modules in order ---
run_module() {
    local script="$1"
    local name
    name=$(basename "$script" .sh)
    log_info "Running module: $name"
    bash "$MODULE_DIR/$script" "$TARGET_DIR" "$OUTPUT_DIR" || {
        log_warn "Module $name finished with non-zero exit code. Continuing..."
    }
}

run_module "01_check_repo.sh"
run_module "02_extract_secrets.sh"
run_module "03_recover_lost.sh"
run_module "04_check_permissions.sh"
run_module "05_extract_emails.sh"

log_ok "Reconnaissance finished. Check results in: $OUTPUT_DIR"
