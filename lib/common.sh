#!/usr/bin/env bash
# common.sh - Shared functions for Browser Cleanup Tools
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print helpers
info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
header()  { echo -e "\n${BOLD}${CYAN}=== $* ===${NC}\n"; }

# Prompt for confirmation (defaults to No unless -y flag was passed)
confirm() {
    local msg="${1:-Continue?}"
    if [[ "${AUTO_YES:-false}" == "true" ]]; then
        return 0
    fi
    read -rp "$(echo -e "${YELLOW}$msg [y/N]:${NC} ")" answer
    [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# Check if a flatpak app is installed
flatpak_installed() {
    local app_id="$1"
    flatpak list --app --columns=application 2>/dev/null | grep -q "^${app_id}$"
}

# Check if an app is running (works for both native and flatpak)
app_is_running() {
    local process_name="$1"
    pgrep -x "$process_name" > /dev/null 2>&1 || \
    pgrep -f "$process_name" > /dev/null 2>&1
}

# Safely remove a directory/file with size reporting
safe_remove() {
    local target="$1"
    local description="${2:-$target}"
    if [[ -e "$target" ]]; then
        local size
        size=$(du -sh "$target" 2>/dev/null | cut -f1) || size="unknown"
        rm -rf "$target"
        success "Removed $description ($size)"
    else
        info "Not found: $description (skipped)"
    fi
}

# Remove contents of a directory but keep the directory itself
safe_clean_dir() {
    local target="$1"
    local description="${2:-$target}"
    if [[ -d "$target" ]]; then
        local size
        size=$(du -sh "$target" 2>/dev/null | cut -f1) || size="unknown"
        rm -rf "${target:?}/"*
        success "Cleaned $description ($size freed)"
    else
        info "Not found: $description (skipped)"
    fi
}

# Remove files matching a glob pattern in a directory
safe_remove_glob() {
    local dir="$1"
    local pattern="$2"
    local description="${3:-$pattern in $dir}"
    if [[ -d "$dir" ]]; then
        local count
        count=$(find "$dir" -maxdepth 1 -name "$pattern" 2>/dev/null | wc -l)
        if [[ "$count" -gt 0 ]]; then
            find "$dir" -maxdepth 1 -name "$pattern" -exec rm -rf {} +
            success "Removed $count file(s): $description"
        else
            info "No matches: $description (skipped)"
        fi
    else
        info "Not found: $dir (skipped)"
    fi
}

# Clean common Chromium-based browser data
# Usage: clean_chromium_profile <profile_dir> <app_name>
clean_chromium_profile() {
    local profile_dir="$1"
    local app_name="$2"

    if [[ ! -d "$profile_dir" ]]; then
        warn "$app_name profile directory not found: $profile_dir"
        return 0
    fi

    # Find all profile directories (Default, Profile 1, Profile 2, etc.)
    local profiles=()
    for p in "$profile_dir"/Default "$profile_dir"/Profile\ *; do
        [[ -d "$p" ]] && profiles+=("$p")
    done

    if [[ ${#profiles[@]} -eq 0 ]]; then
        warn "No $app_name profiles found in $profile_dir"
        return 0
    fi

    for profile in "${profiles[@]}"; do
        local pname
        pname=$(basename "$profile")
        info "Cleaning $app_name profile: $pname"

        # Cache directories within the profile
        safe_remove "$profile/Cache" "$pname/Cache"
        safe_remove "$profile/Code Cache" "$pname/Code Cache"
        safe_remove "$profile/GPUCache" "$pname/GPUCache"
        safe_remove "$profile/DawnCache" "$pname/DawnCache"
        safe_remove "$profile/Service Worker/CacheStorage" "$pname/Service Worker/CacheStorage"
        safe_remove "$profile/Service Worker/ScriptCache" "$pname/Service Worker/ScriptCache"
        safe_remove "$profile/GrShaderCache" "$pname/GrShaderCache"
        safe_remove "$profile/ShaderCache" "$pname/ShaderCache"

        # Session data
        safe_remove "$profile/Sessions" "$pname/Sessions"
        safe_remove "$profile/Session Storage" "$pname/Session Storage"

        # Web storage and databases
        safe_remove "$profile/File System" "$pname/File System"
        safe_remove "$profile/IndexedDB" "$pname/IndexedDB"
        safe_remove "$profile/blob_storage" "$pname/blob_storage"
        safe_remove "$profile/databases" "$pname/databases"

        # Logs
        safe_remove_glob "$profile" "*.log" "$pname log files"

        # Crash reports
        safe_remove "$profile/Crashpad" "$pname/Crashpad"
    done

    # Top-level cache and crash data
    safe_remove "$profile_dir/ShaderCache" "$app_name ShaderCache"
    safe_remove "$profile_dir/GrShaderCache" "$app_name GrShaderCache"
    safe_remove "$profile_dir/Crashpad" "$app_name Crashpad"
    safe_remove "$profile_dir/CrashpadMetrics-active.pma" "$app_name Crashpad metrics"
    safe_remove "$profile_dir/BrowserMetrics" "$app_name BrowserMetrics"
    safe_remove_glob "$profile_dir" "*.log" "$app_name log files"
}

# Clean common Mozilla-based browser data (Firefox, Floorp, Thunderbird)
# Usage: clean_mozilla_profile <profiles_dir> <cache_dir> <app_name>
clean_mozilla_profile() {
    local profiles_dir="$1"
    local cache_dir="$2"
    local app_name="$3"

    # Clean the external cache directory
    if [[ -d "$cache_dir" ]]; then
        safe_clean_dir "$cache_dir" "$app_name cache"
    fi

    if [[ ! -d "$profiles_dir" ]]; then
        warn "$app_name profiles directory not found: $profiles_dir"
        return 0
    fi

    # Find actual profile directories (*.default, *.default-release, etc.)
    local profiles=()
    while IFS= read -r -d '' p; do
        profiles+=("$p")
    done < <(find "$profiles_dir" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

    if [[ ${#profiles[@]} -eq 0 ]]; then
        warn "No $app_name profiles found"
        return 0
    fi

    for profile in "${profiles[@]}"; do
        local pname
        pname=$(basename "$profile")
        info "Cleaning $app_name profile: $pname"

        # Cache within profile
        safe_remove "$profile/cache2" "$pname/cache2"
        safe_remove "$profile/thumbnails" "$pname/thumbnails"
        safe_remove "$profile/startupCache" "$pname/startupCache"
        safe_remove "$profile/jumpListCache" "$pname/jumpListCache"

        # Session restore backups
        safe_remove "$profile/sessionstore-backups" "$pname/sessionstore-backups"

        # Crash reports
        safe_remove "$profile/minidumps" "$pname/minidumps"
        safe_remove "$profile/crash reports" "$pname/crash reports"
        safe_remove "$profile/Crash Reports" "$pname/Crash Reports"

        # Storage and temp data
        safe_remove "$profile/storage/temporary" "$pname/storage/temporary"
        safe_remove "$profile/storage/default/*/cache" "$pname cached site storage"

        # Shader cache
        safe_remove "$profile/shader-cache" "$pname/shader-cache"
    done
}

# Parse common flags
parse_common_flags() {
    AUTO_YES=false
    for arg in "$@"; do
        case "$arg" in
            -y|--yes) AUTO_YES=true ;;
            -h|--help) return 1 ;;
        esac
    done
    export AUTO_YES
}
