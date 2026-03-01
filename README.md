# Browser Cleanup Tools

A collection of Bash scripts to clean cache, temporary data, sessions, and other cruft from popular Linux browsers and email clients. Supports **native** (apt/dnf/pacman), **Flatpak**, and **Snap** installations.

## What's New in v2.0

- **6 new browsers**: LibreWolf, Waterfox, Zen, Vivaldi, Opera, and improved Tor Browser support
- **Betterfox integration**: Privacy and performance settings sourced from [yokoffing/Betterfox](https://github.com/yokoffing/Betterfox) — Securefox, Fastfox, Smoothfox, and Peskyfox
- **NVIDIA/GPU acceleration**: GPU-tuned WebRender compositor, VA-API, DMA-BUF, EGL, and refresh rate auto-detection from [nvidia-display-layout](https://github.com/ChiefGyk3D/nvidia-display-layout)
- **Chromium hardening**: JSON policy-based privacy hardening for Chromium, Brave, Chrome, Vivaldi, and Opera
- **Unified profile manager**: Single `profile-manager.sh` replacing separate Firefox/Floorp scripts, with GPG-encrypted backups
- **Modular library system**: Shared `lib/` modules for paths, profiles, configuration, and logging
- **Scroll presets**: Smoothfox-derived scroll profiles (sharpen, instant, smooth, natural) for different display refresh rates
- **Centralized config**: `~/.config/browser-cleanup-tools/config` for persistent defaults

## Features

- **Cache & data cleaning** for 11 browsers/apps across native, Flatpak, and Snap
- **Dry-run mode** — preview what would be removed without deleting anything
- **Disk usage reports** — see exactly how much space each browser uses (with JSON export)
- **Profile management** — list, backup (GPG-encrypted), create, delete, reset, and restore profiles for all Mozilla browsers
- **Profile migration** — migrate profiles between Firefox and Floorp
- **Scheduled cleaning** — set up automatic periodic cleanup via systemd timers or cron
- **Extension auditing** — list all installed extensions across every browser and profile
- **Privacy hardening** — Betterfox-powered `user.js` settings for Mozilla browsers + JSON policies for Chromium browsers (3 levels)
- **Performance optimization** — GPU-accelerated, Betterfox-tuned speed profiles with scroll presets
- **Session export** — save open tabs to text/JSON/HTML/Markdown and restore them later
- **Duplicate detection** — find redundant profiles, duplicate extensions, and wasted space
- **Safe defaults** — bookmarks, passwords, extensions, and settings are always preserved

## Supported Applications

| Application | Cache Clean | Deep Clean | Profile Manager | Privacy Harden | Perf Tune | Native | Flatpak | Snap |
|-------------|:-----------:|:----------:|:---------------:|:--------------:|:---------:|:------:|:-------:|:----:|
| Thunderbird | ✅ | ✅ (+ OAuth) | — | — | — | ✅ | ✅ | ✅ |
| Firefox     | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Floorp      | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| LibreWolf   | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| Waterfox    | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | — |
| Zen         | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| Chromium    | ✅ | ✅ | — | ✅ (policy) | — | ✅ | ✅ | ✅ |
| Brave       | ✅ | ✅ | — | ✅ (policy) | — | ✅ | ✅ | ✅ |
| Chrome      | ✅ | ✅ | — | ✅ (policy) | — | ✅ | N/A | — |
| Vivaldi     | ✅ | ✅ | — | ✅ (policy) | — | ✅ | — | — |
| Opera       | ✅ | ✅ | — | ✅ (policy) | — | ✅ | — | — |

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
| `clean-librewolf.sh` | Clean LibreWolf (native + Flatpak) |
| `clean-waterfox.sh` | Clean Waterfox (native) |
| `clean-zen.sh` | Clean Zen Browser (native + Flatpak) |
| `clean-chromium.sh` | Clean Chromium (native + Flatpak + Snap) |
| `clean-brave.sh` | Clean Brave Browser (native + Flatpak + Snap) |
| `clean-chrome.sh` | Clean Google Chrome (native only) |
| `clean-vivaldi.sh` | Clean Vivaldi (native) |
| `clean-opera.sh` | Clean Opera (native) |

### Profile Managers

| Script | Description |
|--------|-------------|
| `profile-manager.sh` | Unified profile manager for all Mozilla browsers |
| `firefox-profile-manager.sh` | Firefox-specific profile manager (legacy) |
| `floorp-profile-manager.sh` | Floorp-specific profile manager (legacy) |

Profile manager commands:
- **list** — List all profiles with sizes
- **info** — Detailed breakdown of a profile (sizes per category)
- **backup** — Create a timestamped `.tar.gz` backup (GPG encryption available)
- **create** — Create a new named profile
- **delete** — Delete a profile (auto-backup first)
- **reset** — Reset a profile: removes cache/cookies/sessions but keeps bookmarks, passwords, extensions, and preferences
- **restore** — Restore a profile from a previous backup archive

```bash
# Use for any Mozilla browser
./profile-manager.sh --browser firefox list
./profile-manager.sh --browser librewolf backup
./profile-manager.sh --browser zen info default-release
```

### Privacy Hardening

| Script | Description |
|--------|-------------|
| `harden-privacy.sh` | Betterfox-powered `user.js` hardening for Mozilla browsers |
| `harden-chromium.sh` | JSON policy hardening for Chromium-based browsers |

### Additional Tools

| Script | Description |
|--------|-------------|
| `optimize-performance.sh` | GPU/Betterfox performance tuning with scroll presets |
| `disk-report.sh` | Show disk usage breakdown for all browsers (supports `--json`) |
| `migrate-profile.sh` | Migrate profiles between Firefox and Floorp |
| `schedule-cleanup.sh` | Set up automatic scheduled cleaning (systemd timer or cron) |
| `audit-extensions.sh` | List all installed extensions across all browsers |
| `export-sessions.sh` | Export and restore open browser tabs |
| `detect-duplicates.sh` | Find duplicate extensions and redundant profiles |

## Usage Examples

### Privacy Hardening (Mozilla — Betterfox)

Privacy settings are sourced from [Betterfox](https://github.com/yokoffing/Betterfox) (Securefox, Peskyfox) and applied via `user.js`:

```bash
# Preview standard privacy settings
./harden-privacy.sh show

# Apply to all detected Mozilla browsers
./harden-privacy.sh apply

# Apply strict level (may break some sites)
./harden-privacy.sh apply --strict

# Apply paranoid level (max protection)
./harden-privacy.sh apply --paranoid

# Target a specific browser
./harden-privacy.sh apply --strict --browser librewolf

# Check status
./harden-privacy.sh status

# Revert changes
./harden-privacy.sh revert
```

Hardening levels — all include Betterfox Securefox + Peskyfox prefs:
- **Standard** — GPC, CRLite, HTTPS-Only, DoH, tracking protection, Punycode IDN, disk avoidance, telemetry off, UI cleanup
- **Strict** — Adds ECH, SameSite cookies, SOCKS proxy DNS, AI/Relay controls disabled
- **Paranoid** — Adds fingerprint resistance, WASM/JIT disable, window size limits, device permissions blocked, shutdown sanitization v2

### Privacy Hardening (Chromium — Policies)

For Chromium, Brave, Chrome, Vivaldi, and Opera — applies JSON managed policies:

```bash
# Apply standard hardening to all Chromium browsers
./harden-chromium.sh apply

# Apply strict to Brave only
./harden-chromium.sh apply --strict --browser brave

# Show current policies
./harden-chromium.sh show

# Apply to user dir only (no sudo needed)
./harden-chromium.sh apply --user-only

# Revert
./harden-chromium.sh revert
```

### Performance Optimization (Betterfox + NVIDIA GPU)

Settings sourced from [Betterfox Fastfox/Smoothfox](https://github.com/yokoffing/Betterfox) and [nvidia-capture-card](https://github.com/chiefgyk3d/nvidia-capture-card):

```bash
# Apply balanced optimization with GPU acceleration
./optimize-performance.sh apply --gpu-tweaks

# Apply aggressive + natural scrolling (120Hz+)
./optimize-performance.sh apply --aggressive --gpu-tweaks --scroll-natural

# Optimize for low-RAM (≤ 4 GB)
./optimize-performance.sh apply --low-ram

# Show GPU and display info
./optimize-performance.sh gpu-info

# Get env vars for GPU-accelerated browser launch
./optimize-performance.sh launch-env
# Source them: eval "$(./optimize-performance.sh launch-env)"

# Quick system & browser benchmark
./optimize-performance.sh benchmark

# Target a specific browser
./optimize-performance.sh apply --aggressive --browser waterfox
```

Optimization levels — all include Betterfox Fastfox prefs:
- **Balanced** — GPU acceleration, HTTP/3, VA-API, shader precaching, DNS/TLS cache boost
- **Aggressive** — Higher connection limits, larger caches, Skia font cache, tab unloading
- **Low-RAM** — Fewer processes, smaller caches, aggressive GC, stripped UI features

Scroll presets (from Betterfox Smoothfox):
- **`--scroll-sharpen`** — Crisp, minimal inertia (any display)
- **`--scroll-instant`** — Fast, simple scrolling (60Hz+)
- **`--scroll-smooth`** — msdPhysics enabled (90Hz+)
- **`--scroll-natural`** — Chrome-like feel with spring constants (120Hz+)

GPU tweaks (from nvidia-capture-card):
- WebRender compositor (force-enabled), DMA-BUF, EGL, shader precaching
- Auto-detected refresh rate → `gfx.display.max-frame-rate`
- NVIDIA: env vars for VA-API NVDEC, RDD sandbox bypass, VSync control
- AMD/Intel: appropriate LIBVA_DRIVER_NAME and EGL settings

### Thunderbird (Office 365 fix)

```bash
# Basic cache clean
./clean-thunderbird.sh

# Clear OAuth tokens (forces re-authentication)
./clean-thunderbird.sh --oauth

# Nuclear: deep clean + OAuth reset
./clean-thunderbird.sh --deep -y
```

### Session Export

```bash
# Export tabs from all browsers
./export-sessions.sh export

# Export as interactive HTML page
./export-sessions.sh export --format html

# Export as JSON
./export-sessions.sh export --format json --browser firefox

# Restore tabs
./export-sessions.sh restore latest
```

### Scheduled Cleaning

```bash
# Install weekly cleanup (systemd timer)
./schedule-cleanup.sh install

# Install daily with deep clean
./schedule-cleanup.sh install --interval daily --deep

# Use cron instead
./schedule-cleanup.sh install --use-cron

# Check status / trigger now / uninstall
./schedule-cleanup.sh status
./schedule-cleanup.sh run-now
./schedule-cleanup.sh uninstall
```

### Extension Auditing

```bash
# Audit all browsers
./audit-extensions.sh

# Detailed permissions
./audit-extensions.sh --details

# JSON or CSV export
./audit-extensions.sh --json
./audit-extensions.sh --csv
```

## Common Options

All scripts support:

| Flag | Description |
|------|-------------|
| `-V`, `--version` | Show version |
| `-y`, `--yes` | Skip all confirmation prompts |
| `-n`, `--dry-run` | Preview changes without deleting anything |
| `--native-only` | Only target native installations |
| `--flatpak-only` | Only target Flatpak installations |
| `--snap-only` | Only target Snap installations |
| `-h`, `--help` | Show help message |

Additional flags for specific scripts:

| Flag | Script(s) | Description |
|------|-----------|-------------|
| `--deep` | Cleaners | Remove cookies, site storage, form history |
| `--oauth` | Thunderbird | Clear OAuth2 tokens (forces re-login) |
| `--max-age DAYS` | New cleaners | Only clean items older than N days |
| `--min-size MB` | New cleaners | Only clean dirs larger than N MB |
| `--browser NAME` | Most tools | Target a specific browser |
| `--profile NAME` | Most tools | Target a specific profile |
| `--standard/--strict/--paranoid` | harden-privacy, harden-chromium | Hardening level |
| `--balanced/--aggressive/--low-ram` | optimize-performance | Performance level |
| `--gpu-tweaks/--no-gpu-tweaks` | optimize-performance | Enable/disable GPU tuning |
| `--scroll-sharpen/instant/smooth/natural` | optimize-performance | Betterfox scroll preset |
| `--user-only` | harden-chromium | Apply to user policy dir only |
| `--json/--csv` | disk-report, audit-extensions, detect-duplicates | Output format |
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

## Configuration

Persistent settings are stored in `~/.config/browser-cleanup-tools/config`:

```ini
# Default levels
DEFAULT_CLEAN_LEVEL=standard
DEFAULT_PRIVACY_LEVEL=standard
DEFAULT_PERF_LEVEL=balanced

# Thresholds
MAX_CACHE_AGE_DAYS=30
MIN_CACHE_SIZE_MB=100

# GPU
ENABLE_GPU_TWEAKS=auto
DISPLAY_REFRESH_RATE=auto
SCROLL_STYLE=

# Security
ENCRYPT_BACKUPS=false

# Exclusions
EXCLUDED_BROWSERS=

# Logging
LOG_ENABLED=true
```

## File Structure

```
Browser_Cleanup_Tools/
├── VERSION                       # Version number (2.0.0)
├── clean-all.sh                  # Master script — runs all cleaners
├── clean-thunderbird.sh          # Thunderbird cleaner
├── clean-firefox.sh              # Firefox cleaner
├── clean-floorp.sh               # Floorp cleaner
├── clean-librewolf.sh            # LibreWolf cleaner (new)
├── clean-waterfox.sh             # Waterfox cleaner (new)
├── clean-zen.sh                  # Zen Browser cleaner (new)
├── clean-chromium.sh             # Chromium cleaner
├── clean-brave.sh                # Brave cleaner
├── clean-chrome.sh               # Chrome cleaner
├── clean-vivaldi.sh              # Vivaldi cleaner (new)
├── clean-opera.sh                # Opera cleaner (new)
├── profile-manager.sh            # Unified Mozilla profile manager (new)
├── firefox-profile-manager.sh    # Firefox profile management (legacy)
├── floorp-profile-manager.sh     # Floorp profile management (legacy)
├── harden-privacy.sh             # Betterfox privacy hardening (rewritten)
├── harden-chromium.sh            # Chromium policy hardening (new)
├── optimize-performance.sh       # GPU/Betterfox performance tuning (rewritten)
├── disk-report.sh                # Disk usage report
├── migrate-profile.sh            # Firefox ↔ Floorp profile migration
├── schedule-cleanup.sh           # Scheduled cleaning setup
├── audit-extensions.sh           # Extension auditor
├── export-sessions.sh            # Tab session export/restore
├── detect-duplicates.sh          # Duplicate/redundancy finder
├── lib/
│   ├── common.sh                 # Shared functions and utilities
│   ├── paths.sh                  # Centralized browser path definitions (new)
│   ├── profiles.sh               # Unified profile discovery + GPG backup (new)
│   └── config.sh                 # Persistent configuration + GPU detection (new)
├── LICENSE
└── README.md
```

## Requirements

- **Bash 4.0+** (uses associative arrays)
- **Linux** (paths are Linux-specific)
- Standard tools: `find`, `du`, `tar`, `grep`, `pgrep`, `bc`
- Flatpak (optional, for Flatpak app support)
- Snap (optional, for Snap app support)
- systemd (optional, for scheduled cleaning timers)
- python3 (optional, for extension auditing, session export, JSON output)
- jq (optional, alternative to python3 for JSON parsing)
- gpg (optional, for encrypted profile backups)
- vainfo (optional, for VA-API hardware decode detection)
- nvidia-settings / xrandr (optional, for refresh rate auto-detection)

## Acknowledgements

- **[Betterfox](https://github.com/yokoffing/Betterfox)** by yokoffing — Securefox, Fastfox, Smoothfox, and Peskyfox `user.js` settings
- **[nvidia-capture-card](https://github.com/chiefgyk3d/nvidia-capture-card)** — GPU acceleration, WebRender compositor, VA-API NVDEC pipeline, and display refresh rate detection

## Safety

- All scripts check if the target application is running and refuse to proceed if so
- Destructive operations prompt for confirmation by default (use `-y` to skip)
- Profile delete and reset operations create automatic backups first
- The `--deep` flag is required for anything beyond cache cleaning
- `safe_clean_dir()` validates canonical paths must be under `$HOME`

## License

MIT License — see [LICENSE](LICENSE) for details.
