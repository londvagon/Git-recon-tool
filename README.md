# git-recon

Modular Bash toolkit for Git repository reconnaissance.
Built for red-team and OSINT assessments on repositories you are authorized to test.

---

## What it does

`git-recon` inspects a local Git repository and produces a structured report covering:

1. **Repository check** — verifies that a Git repository exists and is properly initialized (valid `.git`, at least one commit, branches, remotes).
2. **Secret extraction** — searches current files *and the full commit history* for passwords, API keys, tokens, private keys, config files, and password hashes.
3. **Lost file recovery** — finds deleted files and dangling Git objects, then restores their content.
4. **Permission audit** — checks read/write/execute rights on `.git/` and on tracked files, and flags world-writable files.
5. **Email extraction** — collects unique email addresses from commit metadata, commit messages, and file content.

All logic uses **only built-in Git commands** and standard Linux utilities. No external dependencies.

---

## Why it matters

Git stores every change forever. A developer who deletes a file with a secret does **not** remove it from history — it stays in old commits and in dangling objects. `git-recon` systematically walks that history and surfaces what was left behind.

---

## ⚠️ Legal and ethical notice

Use this tool **only** on repositories you own or have **written permission** to test.

Running it against third-party repositories without authorization may violate:
- Computer misuse laws (e.g. CFAA in the US, Computer Misuse Act in the UK)
- GitHub Terms of Service
- Privacy and data protection regulations

The authors are not responsible for misuse. This is a defensive and educational tool.

---

## Requirements

| Dependency | Version | Purpose |
|------------|---------|---------|
| Bash | 4.0+ | Script runtime |
| Git | 2.x+ | Repository access |
| coreutils | any | `grep`, `awk`, `stat`, `find`, `sort` |

Tested on Linux. macOS should work with minor adjustments (`stat` flags differ).

---

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/git-recon.git
cd git-recon
chmod +x main.sh modules/*.sh

Usage:
./main.sh /path/to/target-repository

Example:
./main.sh ~/labs/leaky-repo


How each module works
01_check_repo.sh — repository verification

    Confirms .git/ exists and is a valid Git directory (git rev-parse --git-dir).

    Checks that HEAD points to at least one commit.

    Lists branches and remote URLs (remotes may contain embedded credentials).

    Output: 01_repo_check.txt

02_extract_secrets.sh — secret and config extraction

    git grep over tracked files for keywords: password, secret, token, api_key, AKIA, BEGIN RSA, ghp_, xox[bp]-.

    git log -p --all over every commit to catch secrets that were later deleted.

    Enumerates config files (.env, wp-config.php, config.*, .npmrc, …) and dumps their content.

    Detects hash-like strings: MD5 (32 hex), SHA1 (40 hex), SHA256 (64 hex), bcrypt ($2a$…).

    Output: 02_secrets_found.txt, 02_configs_found.txt, 02_hashes_found.txt

03_recover_lost.sh — lost file recovery

    git fsck --full --unreachable --dangling — finds objects no longer referenced by any branch (result of amend, rebase, deleted branches).

    git log --all --diff-filter=D — lists files deleted in history.

    git show <commit>^:<file> — restores each deleted file from the commit before deletion.

    git reflog — shows recent HEAD movements, useful for finding lost commits.

    Output: 03_recovery_report.txt, recovered_files/

04_check_permissions.sh — permission audit

    stat + -r/-w/-x tests on .git/ for the current user.

    git ls-tree -r HEAD — shows permission bits stored in the Git index.

    Filesystem stat on every tracked file: owner, group, mode, effective rights.

    Flags world-writable files (potential privilege-escalation vector).

    Output: 04_permissions.txt

05_extract_emails.sh — email enumeration

    git log --pretty=format:"%aE%n%cE" — author and committer emails from every commit.

    Commit message bodies — catches Co-authored-by:, Signed-off-by: trailers.

    File content, current and historical.

    Deduplicated and validated against a strict email regex.

    Output: 05_emails.txt

Output reference

All results go to ./recon_output/:
File	Description
01_repo_check.txt	Repository status, branches, remotes
02_secrets_found.txt	Secrets found in current files and history
02_configs_found.txt	Config file list and content
02_hashes_found.txt	MD5 / SHA1 / SHA256 / bcrypt hashes
03_recovery_report.txt	Recovery log and dangling objects
recovered_files/	Restored files, prefixed by commit hash
04_permissions.txt	Permission audit + world-writable warnings
05_emails.txt	Unique email addresses
