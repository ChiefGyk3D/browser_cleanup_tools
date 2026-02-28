# Browser Cleanup Tools

A collection of Bash scripts to clean cache, temporary data, sessions, and other cruft from popular Linux browsers and email clients. Supports both **native** (apt/dnf/pacman) and **Flatpak** installations.

## Supported Applications

| Application | Cache Clean | Deep Clean | Profile Manager | Native | Flatpak |
|-------------|:-----------:|:----------:|:---------------:|:------:|:-------:|
| Thunderbird | ✅ | ✅ (+ OAuth reset) | — | ✅ | ✅ |
| Firefox     | ✅ | ✅ | ✅ | ✅ | ✅ |
| Floorp      | ✅ | ✅ | ✅ | ✅ | ✅ |
| Chromium    | ✅ | — | — | ✅ | ✅ |
| Brave       | ✅ | — | — | ✅ | ✅ |
| Chrome      | ✅ | — | — | ✅ | N/A |

## Quick Start

```bash
# Clone the repo
git clone https://github.com/chiefgyk3d/Browser_Cleanup_Tools.git
cd Browser_Cleanup_Tools

# Make scripts executable
chmod +x *.sh lib/*.sh

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
| `clean-thunderbird.sh` | Clean Thunderbird (native + Flatpak) |
| `clean-firefox.sh` | Clean Firefox (native + Flatpak) |
| `clean-floorp.sh` | Clean Floorp (native + Flatpak) |
| `clean-chromium.sh` | Clean Chromium (native + Flatpak) |
| `clean-brave.sh` | Clean Brave Browser (native + Flatpak) |
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

### Firefox / Floorp Profile Management

```bash
# List all Firefox profiles
./firefox-profile-manager.sh list

# Get detailed info on a profile
./firefox-profile-manager.sh info default-release

# Backup all profiles
./firefox-profile-manager.sh backup

# Create a new profile for work
./firefox-profile-manager.sh create work

# Reset a profile (keeps bookmarks + passwords, removes everything else)
./firefox-profile-manager.sh reset default-release

# Same commands work for Floorp
./floorp-profile-manager.sh list
./floorp-profile-manager.sh reset default-release
```

### Selective Cleaning

```bash
# Interactively pick which apps to clean
./clean-all.sh --select

# Only clean Flatpak versions
./clean-all.sh --flatpak-only -y

# Only clean native versions
./clean-all.sh --native-only -y

# Clean just one browser
./clean-brave.sh -y
```

## Common Options

All scripts support these flags:

| Flag | Description |
|------|-------------|
| `-y`, `--yes` | Skip all confirmation prompts |
| `--native-only` | Only clean native installations |
| `--flatpak-only` | Only clean Flatpak installations |
| `-h`, `--help` | Show help message |

Additional flags for specific scripts:

| Flag | Script | Description |
|------|--------|-------------|
| `--deep` | Firefox, Floorp, Thunderbird, clean-all | Remove cookies, site storage, form history |
| `--oauth` | Thunderbird | Clear OAuth2 tokens (forces re-login) |
| `--offline-cache` | Thunderbird | Clear IMAP offline cache |
| `--select` | clean-all | Interactively select apps to clean |

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

## Safety

- All scripts check if the target application is running and refuse to proceed if so
- Destructive operations prompt for confirmation by default (use `-y` to skip)
- Profile delete and reset operations create automatic backups first
- The `--deep` flag is required for anything beyond cache cleaning

## License

MIT License — see [LICENSE](LICENSE) for details.
