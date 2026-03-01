#!/usr/bin/env bash
# config.sh - Configuration file support for Browser Cleanup Tools
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools
#
# Provides persistent configuration via ~/.config/browser-cleanup-tools/config
# and cookie allowlist/extension blocklist functionality.

# Prevent double-sourcing
[[ -n "${_CONFIG_SH_LOADED:-}" ]] && return 0
_CONFIG_SH_LOADED=1

# ===========================================================================
# VERSION
# ===========================================================================
SCRIPT_DIR_CONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BCT_VERSION="$(cat "$SCRIPT_DIR_CONFIG/VERSION" 2>/dev/null || echo "unknown")"

# ===========================================================================
# CONFIGURATION PATHS
# ===========================================================================
BCT_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/browser-cleanup-tools"
BCT_CONFIG_FILE="$BCT_CONFIG_DIR/config"
BCT_COOKIE_ALLOWLIST="$BCT_CONFIG_DIR/cookie-allowlist"
BCT_EXTENSION_ALLOWLIST="$BCT_CONFIG_DIR/extension-allowlist"
BCT_EXTENSION_BLOCKLIST="$BCT_CONFIG_DIR/extension-blocklist"
BCT_LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/browser-cleanup-tools/logs"
BCT_LOG_FILE="$BCT_LOG_DIR/cleanup.log"

# ===========================================================================
# DEFAULT CONFIGURATION VALUES
# ===========================================================================

# Cleaning defaults
DEFAULT_CLEAN_LEVEL="${DEFAULT_CLEAN_LEVEL:-standard}"  # standard, deep
DEFAULT_INSTALL_FILTER="${DEFAULT_INSTALL_FILTER:-}"     # native-only, flatpak-only, snap-only, or empty for all
AUTO_YES="${AUTO_YES:-false}"

# Age/size threshold defaults
MAX_CACHE_AGE_DAYS="${MAX_CACHE_AGE_DAYS:-0}"     # 0 = no age limit
MIN_CACHE_SIZE_MB="${MIN_CACHE_SIZE_MB:-0}"        # 0 = no minimum size threshold

# Privacy defaults
DEFAULT_PRIVACY_LEVEL="${DEFAULT_PRIVACY_LEVEL:-standard}"  # standard, strict, paranoid
DEFAULT_PERF_LEVEL="${DEFAULT_PERF_LEVEL:-balanced}"         # balanced, aggressive, low-ram

# Browser exclusions (space-separated browser names to skip)
EXCLUDED_BROWSERS="${EXCLUDED_BROWSERS:-}"

# Logging
LOG_ENABLED="${LOG_ENABLED:-false}"

# Backup encryption
ENCRYPT_BACKUPS="${ENCRYPT_BACKUPS:-false}"

# Display/GPU (from nvidia-capture-card)
ENABLE_GPU_TWEAKS="${ENABLE_GPU_TWEAKS:-auto}"  # auto, nvidia, amd, intel, none
DISPLAY_REFRESH_RATE="${DISPLAY_REFRESH_RATE:-auto}"  # auto or specific Hz value

# Scrolling preference (from Betterfox Smoothfox)
SCROLL_STYLE="${SCROLL_STYLE:-sharpen}"  # sharpen, instant, smooth, natural

# ===========================================================================
# CONFIG FILE LOADING
# ===========================================================================

# Load config file if it exists
load_config() {
    if [[ -f "$BCT_CONFIG_FILE" ]]; then
        # Source the config file, but only known variables
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            # Trim whitespace
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            # Remove surrounding quotes
            value="${value%\"}"
            value="${value#\"}"
            value="${value%\'}"
            value="${value#\'}"

            case "$key" in
                DEFAULT_CLEAN_LEVEL)     DEFAULT_CLEAN_LEVEL="$value" ;;
                DEFAULT_INSTALL_FILTER)  DEFAULT_INSTALL_FILTER="$value" ;;
                AUTO_YES)                AUTO_YES="$value" ;;
                MAX_CACHE_AGE_DAYS)      MAX_CACHE_AGE_DAYS="$value" ;;
                MIN_CACHE_SIZE_MB)       MIN_CACHE_SIZE_MB="$value" ;;
                DEFAULT_PRIVACY_LEVEL)   DEFAULT_PRIVACY_LEVEL="$value" ;;
                DEFAULT_PERF_LEVEL)      DEFAULT_PERF_LEVEL="$value" ;;
                EXCLUDED_BROWSERS)       EXCLUDED_BROWSERS="$value" ;;
                LOG_ENABLED)             LOG_ENABLED="$value" ;;
                ENCRYPT_BACKUPS)         ENCRYPT_BACKUPS="$value" ;;
                ENABLE_GPU_TWEAKS)       ENABLE_GPU_TWEAKS="$value" ;;
                DISPLAY_REFRESH_RATE)    DISPLAY_REFRESH_RATE="$value" ;;
                SCROLL_STYLE)            SCROLL_STYLE="$value" ;;
            esac
        done < "$BCT_CONFIG_FILE"
    fi
}

# Initialize config directory and create default config if needed
init_config() {
    mkdir -p "$BCT_CONFIG_DIR"
    mkdir -p "$BCT_LOG_DIR"

    if [[ ! -f "$BCT_CONFIG_FILE" ]]; then
        cat > "$BCT_CONFIG_FILE" << 'CONFIGEOF'
# Browser Cleanup Tools Configuration
# ====================================
# Edit this file to set persistent defaults.
# Command-line flags override these settings.

# Cleaning level: standard or deep
# DEFAULT_CLEAN_LEVEL=standard

# Install type filter: native-only, flatpak-only, snap-only, or empty for all
# DEFAULT_INSTALL_FILTER=

# Auto-confirm prompts (true/false)
# AUTO_YES=false

# Age-based cleaning: only clean caches older than N days (0 = no limit)
# MAX_CACHE_AGE_DAYS=0

# Size-threshold cleaning: only clean if total cache exceeds N MB (0 = no limit)
# MIN_CACHE_SIZE_MB=0

# Privacy hardening level: standard, strict, paranoid
# DEFAULT_PRIVACY_LEVEL=standard

# Performance optimization level: balanced, aggressive, low-ram
# DEFAULT_PERF_LEVEL=balanced

# Browsers to exclude (space-separated): FIREFOX FLOORP LIBREWOLF WATERFOX ZEN TOR CHROMIUM BRAVE CHROME VIVALDI OPERA THUNDERBIRD
# EXCLUDED_BROWSERS=

# Enable logging for all operations (true/false)
# LOG_ENABLED=false

# Encrypt profile backups with GPG (true/false)
# ENCRYPT_BACKUPS=false

# GPU acceleration tweaks: auto, nvidia, amd, intel, none
# auto = detect GPU vendor and apply appropriate settings
# ENABLE_GPU_TWEAKS=auto

# Display refresh rate for browser optimization: auto or specific Hz (e.g., 144)
# auto = detect from xrandr/nvidia-settings
# DISPLAY_REFRESH_RATE=auto

# Scrolling style: sharpen, instant, smooth, natural
# sharpen = subtle improvement (60Hz+)
# instant = fast, immediate scrolling (60Hz+)
# smooth = MSD physics scrolling (90Hz+)
# natural = Chrome-like smooth scrolling (120Hz+)
# SCROLL_STYLE=sharpen
CONFIGEOF
    fi

    if [[ ! -f "$BCT_COOKIE_ALLOWLIST" ]]; then
        cat > "$BCT_COOKIE_ALLOWLIST" << 'COOKIEOF'
# Cookie Allowlist for Deep Clean
# ================================
# One domain per line. Cookies for these domains will be preserved
# during deep clean operations.
# Example:
# github.com
# google.com
# your-bank.com
COOKIEOF
    fi

    if [[ ! -f "$BCT_EXTENSION_ALLOWLIST" ]]; then
        cat > "$BCT_EXTENSION_ALLOWLIST" << 'EXTEOF'
# Extension Allowlist
# ====================
# Extensions listed here are approved. The audit tool will flag
# any installed extensions NOT in this list.
# Format: extension_id  # optional comment
# Example:
# uBlock0@raymondhill.net  # uBlock Origin
# {446900e4-71c2-419f-a6a7-df9c091e268b}  # Bitwarden
EXTEOF
    fi

    if [[ ! -f "$BCT_EXTENSION_BLOCKLIST" ]]; then
        cat > "$BCT_EXTENSION_BLOCKLIST" << 'BLKEOF'
# Extension Blocklist
# ====================
# Extensions listed here will trigger warnings during audits.
# They can optionally be auto-disabled with --enforce.
# Format: extension_id  # reason
# Example:
# {some-malware-id}  # Known malware
BLKEOF
    fi
}

# ===========================================================================
# LOGGING
# ===========================================================================

# Log a message to the log file
log_message() {
    [[ "$LOG_ENABLED" != "true" ]] && return 0
    local level="$1"
    shift
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $*" >> "$BCT_LOG_FILE"
}

log_info()    { log_message "INFO" "$@"; }
log_warn()    { log_message "WARN" "$@"; }
log_error()   { log_message "ERROR" "$@"; }
log_success() { log_message "OK" "$@"; }

# ===========================================================================
# COOKIE ALLOWLIST
# ===========================================================================

# Read cookie allowlist, returns domains one per line
get_cookie_allowlist() {
    [[ ! -f "$BCT_COOKIE_ALLOWLIST" ]] && return 0
    grep -v '^\s*#' "$BCT_COOKIE_ALLOWLIST" | grep -v '^\s*$' | xargs -n1
}

# Check if a domain is in the cookie allowlist
is_cookie_allowed() {
    local domain="$1"
    local allowed
    allowed=$(get_cookie_allowlist)
    [[ -z "$allowed" ]] && return 1
    echo "$allowed" | grep -qF "$domain"
}

# ===========================================================================
# EXTENSION LISTS
# ===========================================================================

# Get extension allowlist (IDs only)
get_extension_allowlist() {
    [[ ! -f "$BCT_EXTENSION_ALLOWLIST" ]] && return 0
    grep -v '^\s*#' "$BCT_EXTENSION_ALLOWLIST" | grep -v '^\s*$' | awk '{print $1}'
}

# Get extension blocklist (IDs only)
get_extension_blocklist() {
    [[ ! -f "$BCT_EXTENSION_BLOCKLIST" ]] && return 0
    grep -v '^\s*#' "$BCT_EXTENSION_BLOCKLIST" | grep -v '^\s*$' | awk '{print $1}'
}

# Check if an extension is in the allowlist
is_extension_allowed() {
    local ext_id="$1"
    local allowed
    allowed=$(get_extension_allowlist)
    [[ -z "$allowed" ]] && return 0  # empty allowlist = all allowed
    echo "$allowed" | grep -qF "$ext_id"
}

# Check if an extension is in the blocklist
is_extension_blocked() {
    local ext_id="$1"
    local blocked
    blocked=$(get_extension_blocklist)
    [[ -z "$blocked" ]] && return 1
    echo "$blocked" | grep -qF "$ext_id"
}

# ===========================================================================
# BROWSER EXCLUSION
# ===========================================================================

# Check if a browser is excluded
is_browser_excluded() {
    local browser="$1"
    [[ -z "$EXCLUDED_BROWSERS" ]] && return 1
    for excluded in $EXCLUDED_BROWSERS; do
        [[ "${excluded^^}" == "${browser^^}" ]] && return 0
    done
    return 1
}

# ===========================================================================
# AGE/SIZE THRESHOLD CHECKING
# ===========================================================================

# Check if cache meets the age threshold for cleaning
# Returns 0 if cache should be cleaned, 1 if too new
cache_meets_age_threshold() {
    local cache_dir="$1"
    local max_age_days="${MAX_CACHE_AGE_DAYS:-0}"

    [[ "$max_age_days" -eq 0 ]] && return 0  # no age limit
    [[ ! -d "$cache_dir" ]] && return 1

    # Check if any files are older than the threshold
    local old_files
    old_files=$(find "$cache_dir" -type f -mtime +"$max_age_days" 2>/dev/null | head -1)
    [[ -n "$old_files" ]]
}

# Check if cache meets the size threshold for cleaning
# Returns 0 if cache should be cleaned, 1 if too small
cache_meets_size_threshold() {
    local cache_dir="$1"
    local min_size_mb="${MIN_CACHE_SIZE_MB:-0}"

    [[ "$min_size_mb" -eq 0 ]] && return 0  # no size limit
    [[ ! -d "$cache_dir" ]] && return 1

    local size_bytes
    size_bytes=$(get_size_bytes "$cache_dir")
    local min_size_bytes=$((min_size_mb * 1048576))
    [[ "$size_bytes" -ge "$min_size_bytes" ]]
}

# Clean old files only (age-based cleaning)
clean_old_files() {
    local dir="$1"
    local max_age_days="$2"
    local description="${3:-old files}"

    [[ ! -d "$dir" ]] && return 0
    [[ "$max_age_days" -eq 0 ]] && return 0

    local count
    count=$(find "$dir" -type f -mtime +"$max_age_days" 2>/dev/null | wc -l)
    if [[ "$count" -gt 0 ]]; then
        local size
        size=$(find "$dir" -type f -mtime +"$max_age_days" -exec du -shc {} + 2>/dev/null | tail -1 | cut -f1) || size="unknown"
        if [[ "$DRY_RUN" == "true" ]]; then
            dry_run "$count $description older than ${max_age_days}d ($size)"
        else
            find "$dir" -type f -mtime +"$max_age_days" -delete 2>/dev/null
            # Clean empty directories
            find "$dir" -type d -empty -delete 2>/dev/null
            success "Removed $count $description older than ${max_age_days}d ($size)"
        fi
    fi
}

# ===========================================================================
# GPU/DISPLAY DETECTION (from nvidia-capture-card)
# ===========================================================================

# Detect GPU vendor
detect_gpu_vendor() {
    if [[ "$ENABLE_GPU_TWEAKS" != "auto" && "$ENABLE_GPU_TWEAKS" != "none" ]]; then
        echo "$ENABLE_GPU_TWEAKS"
        return
    fi
    [[ "$ENABLE_GPU_TWEAKS" == "none" ]] && { echo "none"; return; }

    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        echo "nvidia"
    elif lspci 2>/dev/null | grep -qi "VGA.*AMD\|VGA.*ATI"; then
        echo "amd"
    elif lspci 2>/dev/null | grep -qi "VGA.*Intel"; then
        echo "intel"
    else
        echo "none"
    fi
}

# Detect display refresh rate
detect_refresh_rate() {
    if [[ "$DISPLAY_REFRESH_RATE" != "auto" ]]; then
        echo "$DISPLAY_REFRESH_RATE"
        return
    fi

    local rate=""

    # Try nvidia-settings first (format: "2560x1440_180 @2560x1440")
    if command -v nvidia-settings &>/dev/null; then
        rate=$(nvidia-settings -t -q CurrentMetaMode 2>/dev/null | \
            grep -oP '[0-9]+x[0-9]+_\K[0-9]+' | sort -rn | head -1)
        [[ -n "$rate" ]] && { echo "$rate"; return; }
    fi

    # Fallback to xrandr
    if command -v xrandr &>/dev/null; then
        rate=$(xrandr 2>/dev/null | grep '\*' | \
            grep -oP '[0-9]+\.[0-9]+\*' | tr -d '*' | \
            sort -rn | head -1 | cut -d. -f1)
        [[ -n "$rate" ]] && { echo "$rate"; return; }
    fi

    echo "60"  # safe default
}

# Check if VA-API is available
check_vaapi() {
    if command -v vainfo &>/dev/null; then
        vainfo &>/dev/null 2>&1 && return 0
    fi
    return 1
}

# ===========================================================================
# VERSION SUPPORT
# ===========================================================================

show_version() {
    echo "Browser Cleanup Tools v${BCT_VERSION}"
}

# Parse --version flag (call early in main)
check_version_flag() {
    for arg in "$@"; do
        if [[ "$arg" == "--version" || "$arg" == "-V" ]]; then
            show_version
            exit 0
        fi
    done
}

# ===========================================================================
# AUTO-INIT: load config on source
# ===========================================================================
load_config
