# Browser Cleanup Tools

A collection of Bash scripts to clean cache, temporary data, sessions, and other cruft from popular Linux browsers and email clients. Supports **native** (apt/dnf/pacman), **Flatpak**, and **Snap** installations.

## Features

- **Cache & data cleaning** for 6 browsers/apps across native, Flatpak, and Snap
- **Dry-run mode** — preview what would be removed without deleting anything
- **Disk usage reports** — see exactly how much space each browser uses (with JSON export)
- **Profile management** — list, backup, create, delete, reset, and restore Firefox/Floorp profiles
- **Profile migration** — migrate profiles between Firefox and Floorp
- **Scheduled cleaning** — set up automatic periodic cleanup via systemd timers or cron
- **Extension auditing** — list all installed extensions across every browser and profile
- **Privacy hardening** — apply privacy-focused `user.js` settings to Firefox/Floorp (3 levels)
- **Session export** — save open tabs to text/JSON/HTML/Markdown and restore them later
- **Duplicate detection** — find redundant profiles, duplicate extensions, and wasted space
- **Safe defaults** — bookmarks, passwords, extensions, and settings are always preserved

## Supported Applications

| Application | Cache Clean | Deep Clean | Profile Manager | Native | Flatpak | Snap |
|-------------|:-----------:|:----------:|:---------------:|:------:|:-------:|:----:|
| Thunderbird | ✅ | ✅ (+ OAuth reset) | — | ✅ | ✅ | ✅ |
| Firefox     | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Floorp      | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| Chromium    | ✅ | — | — | ✅ | ✅ | ✅ |
| Brave       | ✅ | — | — | ✅ | ✅ | ✅ |
| Chrome      | ✅ | — | — | ✅ | N/A | — |

## Quick Start

```bash
# Clone the repo
git clone https://github.com/chiefgyk3d/Browser_Cleanup_Tools.git
cd Browser_Cleanup_Tools

# Make scripts executable
chmod +x *.sh lib/*.sh

# Preview what would be cleaned (dry-run)
./clean-all.sh --dry-run

# See disk usage for all browsers
./disk-report.sh

# Clean everything (with prompts)
./clean-all.sh

# Clean everything without prompts
./clean-all.sh -y

# Deep clean everything (removes cookies, site storage, etc.)
./clean-all.sh --deep -y
```

## Scripts

### Cache Cleaners

Each cleaner removes cache, temporary files, session data, shader caches, crash reports, and other non-essential data. Your bookmarks, passwords, extensions, and settings are **preserved**.

| Script | Description |
|--------|-------------|
| `clean-all.sh` | Run all cleaners at once |
| `clean-thunderbird.sh` | Clean Thunderbird (native + Flatpak + Snap) |
| `clean-firefox.sh` | Clean Firefox (native + Flatpak + Snap) |
| `clean-floorp.sh` | Clean Floorp (native + Flatpak) |
| `clean-chromium.sh` | Clean Chromium (native + Flatpak + Snap) |
| `clean-brave.sh` | Clean Brave Browser (native + Flatpak + Snap) |
| `clean-chrome.sh` | Clean Google Chrome (native only) |

### Profile Managers

Full profile management for Firefox and Floorp (Mozilla-based browsers):

| Script | Description |
|--------|-------------|
| `firefox-profile-manager.sh` | Manage Firefox profiles |
| `floorp-profile-manager.sh` | Manage Floorp profiles |

Profile manager commands:
- **list** — List all profiles with sizes
- **info** — Detailed breakdown of a profile (sizes per category)
- **backup** — Create a timestamped `.tar.gz` backup
- **create** — Create a new named profile
- **delete** — Delete a profile (auto-backup first)
- **reset** — Reset a profile: removes cache/cookies/sessions but keeps bookmarks, passwords, extensions, and preferences
- **restore** — Restore a profile from a previous backup archive

### Additional Tools

| Script | Description |
|--------|-------------|
| `disk-report.sh` | Show disk usage breakdown for all browsers (supports `--json`) |
| `migrate-profile.sh` | Migrate profiles between Firefox and Floorp |
| `schedule-cleanup.sh` | Set up automatic scheduled cleaning (systemd timer or cron) |
| `audit-extensions.sh` | List all installed extensions across all browsers |
| `harden-privacy.sh` | Apply privacy-hardened `user.js` settings to Firefox/Floorp |
| `export-sessions.sh` | Export and restore open browser tabs |
| `detect-duplicates.sh` | Find duplicate extensions and redundant profiles |

## Usage Examples

### Thunderbird (Office 365 fix)

If Thunderbird is having trouble pulling Office 365/Exchange emails:

```bash
# Basic cache clean
./clean-thunderbird.sh

# Clear OAuth tokens too (forces re-authentication)
./clean-thunderbird.sh --oauth

# Nuclear option: deep clean + OAuth reset
./clean-thunderbird.sh --deep -y
```

After running, open Thunderbird and it will re-authenticate with Microsoft's OAuth2 flow.

### Dry-Run Mode

Preview what would be cleaned without actually removing anything:

```bash
# See what clean-all would remove
./clean-all.sh --dry-run

# Dry-run on a single browser
./clean-firefox.sh --dry-run

# Combine with other flags
./clean-thunderbird.sh --deep --oauth --dry-run
```

### Disk Usage Report

```bash
# Show disk usage for all browsers
./disk-report.sh

# Export as JSON (for scripts or monitoring)
./disk-report.sh --json
```

### Firefox / Floorp Profile Management

```bash
# List all Firefox profiles
./firefox-profile-manager.sh list

# Get detailed info on a profile
./firefox-profile-manager.sh info default-release

# Backup all profiles
./firefox-profile-manager.sh backup

# Restore a profile from backup
./firefox-profile-manager.sh restore default-release

# Create a new profile for work
./firefox-profile-manager.sh create work

# Reset a profile (keeps bookmarks + passwords, removes everything else)
./firefox-profile-manager.sh reset default-release

# Same commands work for Floorp
./floorp-profile-manager.sh list
./floorp-profile-manager.sh reset default-release
```

### Profile Migration

Migrate profiles between Firefox and Floorp:

```bash
# Interactive migration from Firefox to Floorp
./migrate-profile.sh firefox-to-floorp

# Migrate from Floorp to Firefox
./migrate-profile.sh floorp-to-firefox

# Specify which profile to migrate
./migrate-profile.sh firefox-to-floorp --source-profile default-release

# Migrate from a Flatpak install to a native install
./migrate-profile.sh firefox-to-floorp --source-type flatpak --target-type native
```

### Scheduled Cleaning

Set up automatic periodic cache cleanup:

```bash
# Install weekly cleanup (systemd timer)
./schedule-cleanup.sh install

# Install daily cleanup
./schedule-cleanup.sh install --interval daily

# Install with deep cleaning enabled
./schedule-cleanup.sh install --deep

# Use cron instead of systemd
./schedule-cleanup.sh install --use-cron

# Check timer status
./schedule-cleanup.sh status

# Trigger cleanup now
./schedule-cleanup.sh run-now

# Remove scheduled cleanup
./schedule-cleanup.sh uninstall
```

### Extension Auditing

List every extension installed across all browsers:

```bash
# Audit all browsers
./audit-extensions.sh

# Show detailed permissions info
./audit-extensions.sh --details

# JSON output (for scripts or CI)
./audit-extensions.sh --json

# Audit only Firefox
./audit-extensions.sh --browser firefox

# CSV export
./audit-extensions.sh --csv
```

### Privacy Hardening

Apply privacy-focused settings to Firefox and Floorp profiles:

```bash
# Preview standard privacy settings
./harden-privacy.sh show

# Apply standard privacy settings (minimal breakage)
./harden-privacy.sh apply

# Apply strict privacy (may break some sites)
./harden-privacy.sh apply --strict

# Apply paranoid privacy (max protection, significant breakage)
./harden-privacy.sh apply --paranoid

# Check current privacy status of your profiles
./harden-privacy.sh status

# Revert to original settings
./harden-privacy.sh revert

# Target a specific browser/profile
./harden-privacy.sh apply --strict --browser firefox --profile default-release
```

Hardening levels:
- **Standard** — Disables telemetry, enables tracking protection, HTTPS-only, DoH
- **Strict** — Adds cookie isolation, WebRTC protection, search privacy, shutdown clearing
- **Paranoid** — Adds fingerprint resistance, disables WebGL/WebRTC/JIT, strict referrer policy

### Session Export

Save and restore open browser tabs:

```bash
# Export tabs from all browsers
./export-sessions.sh export

# Export as interactive HTML page
./export-sessions.sh export --format html

# Export as JSON (for scripting)
./export-sessions.sh export --format json --browser firefox

# Export as Markdown
./export-sessions.sh export --format markdown

# List saved exports
./export-sessions.sh list

# Restore tabs from latest export
./export-sessions.sh restore latest

# Restore in a specific browser
./export-sessions.sh restore session.json --browser floorp
```

### Duplicate Detection

Find redundant profiles, duplicate extensions, and wasted space:

```bash
# Full scan
./detect-duplicates.sh

# Only check for duplicate extensions
./detect-duplicates.sh --extensions-only

# Only check for unused profiles
./detect-duplicates.sh --profiles-only

# JSON output
./detect-duplicates.sh --json

# Scan specific browser only
./detect-duplicates.sh --browser firefox
```

### Selective Cleaning

```bash
# Interactively pick which apps to clean
./clean-all.sh --select

# Only clean Flatpak versions
./clean-all.sh --flatpak-only -y

# Only clean Snap versions
./clean-all.sh --snap-only -y

# Only clean native versions
./clean-all.sh --native-only -y

# Clean just one browser
./clean-brave.sh -y
```

## Common Options

All cleaner scripts support these flags:

| Flag | Description |
|------|-------------|
| `-y`, `--yes` | Skip all confirmation prompts |
| `-n`, `--dry-run` | Preview changes without deleting anything |
| `--native-only` | Only clean native installations |
| `--flatpak-only` | Only clean Flatpak installations |
| `--snap-only` | Only clean Snap installations |
| `-h`, `--help` | Show help message |

Additional flags for specific scripts:

| Flag | Script | Description |
|------|--------|-------------|
| `--deep` | Firefox, Floorp, Thunderbird, clean-all | Remove cookies, site storage, form history |
| `--oauth` | Thunderbird | Clear OAuth2 tokens (forces re-login) |
| `--offline-cache` | Thunderbird | Clear IMAP offline cache |
| `--select` | clean-all | Interactively select apps to clean |
| `--json` | disk-report, audit-extensions, detect-duplicates | Output as JSON |
| `--csv` | audit-extensions | Output as CSV |
| `--details` | audit-extensions | Show extension permissions |
| `--standard/--strict/--paranoid` | harden-privacy | Privacy hardening level |
| `--format` | export-sessions | Export format (text/json/html/markdown) |

## What Gets Cleaned

### Standard Clean (default)
- Browser/app cache (`cache2/`, `Cache/`, `GPUCache/`, etc.)
- Startup cache
- Shader cache
- Session restore backups
- Crash reports and minidumps
- Temporary storage
- Log files

### Deep Clean (`--deep`)
Everything above, plus:
- Cookies
- Site storage and IndexedDB
- Form history
- Content preferences
- Web app storage
- Search index (Thunderbird)

### What Is Always Preserved
- Bookmarks
- Saved passwords and encryption keys
- Certificates
- Extensions and add-ons
- User preferences (`prefs.js`, `user.js`)
- Account settings

## File Structure

```
Browser_Cleanup_Tools/
├── clean-all.sh                  # Master script — runs all cleaners
├── clean-thunderbird.sh          # Thunderbird cleaner
├── clean-firefox.sh              # Firefox cleaner
├── clean-floorp.sh               # Floorp cleaner
├── clean-chromium.sh             # Chromium cleaner
├── clean-brave.sh                # Brave cleaner
├── clean-chrome.sh               # Chrome cleaner
├── firefox-profile-manager.sh    # Firefox profile management
├── floorp-profile-manager.sh     # Floorp profile management
├── disk-report.sh                # Disk usage report
├── migrate-profile.sh            # Firefox ↔ Floorp profile migration
├── schedule-cleanup.sh           # Scheduled cleaning setup
├── audit-extensions.sh           # Extension auditor
├── harden-privacy.sh             # Privacy hardening (user.js)
├── export-sessions.sh            # Tab session export/restore
├── detect-duplicates.sh          # Duplicate/redundancy finder
├── lib/
│   └── common.sh                 # Shared functions and utilities
├── LICENSE
└── README.md
```

## Requirements

- **Bash 4.0+** (uses associative arrays)
- **Linux** (paths are Linux-specific)
- Standard tools: `find`, `du`, `tar`, `grep`, `pgrep`
- Flatpak (optional, for Flatpak app support)
- Snap (optional, for Snap app support)
- systemd (optional, for scheduled cleaning timers)
- python3 (optional, for extension auditing, session export, JSON output)
- jq (optional, alternative to python3 for JSON parsing)

## Safety

- All scripts check if the target application is running and refuse to proceed if so
- Destructive operations prompt for confirmation by default (use `-y` to skip)
- Profile delete and reset operations create automatic backups first
- The `--deep` flag is required for anything beyond cache cleaning

## License

MIT License — see [LICENSE](LICENSE) for details.
