#!/usr/bin/env bash
# clean-thunderbird.sh - Clean Thunderbird cache, tokens, and temp data
# Supports native, Flatpak, and Snap installations
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# --- Path definitions ---
# Native
NATIVE_PROFILE_DIR="$HOME/.thunderbird"
NATIVE_CACHE_DIR="$HOME/.cache/thunderbird"

# Flatpak
FLATPAK_APP_ID="org.mozilla.Thunderbird"
FLATPAK_BASE="$HOME/.var/app/$FLATPAK_APP_ID"
FLATPAK_PROFILE_DIR="$FLATPAK_BASE/.thunderbird"
FLATPAK_CACHE_DIR="$FLATPAK_BASE/cache"

# Snap
SNAP_NAME="thunderbird"
SNAP_PROFILE_DIR="$HOME/snap/thunderbird/common/.thunderbird"
SNAP_CACHE_DIR="$HOME/snap/thunderbird/common/.cache/thunderbird"

show_help() {
    cat <<EOF
${BOLD}Thunderbird Cleanup Tool${NC}

Clears cache, OAuth tokens, offline storage, and temp data for Thunderbird.
Supports native (apt/dnf/pacman), Flatpak, and Snap installations.

Usage: $(basename "$0") [OPTIONS]

Options:
  -y, --yes         Skip confirmation prompts
  -n, --dry-run     Show what would be removed without deleting anything
  --native-only     Only clean native installation
  --flatpak-only    Only clean Flatpak installation
  --snap-only       Only clean Snap installation
  --oauth           Also remove OAuth2 tokens (forces re-login)
  --offline-cache   Also remove IMAP offline cache
  --deep            Remove OAuth tokens + offline cache + search index
  -h, --help        Show this help message

Examples:
  $(basename "$0")              # Clean cache for all installations
  $(basename "$0") --deep -y    # Deep clean, no prompts
  $(basename "$0") --oauth      # Clean cache + force OAuth re-auth
  $(basename "$0") --dry-run    # Preview what would be cleaned
EOF
}

# Thunderbird-specific cleaning for a profile directory
clean_thunderbird_profiles() {
    local profiles_dir="$1"
    local install_type="$2"  # "Native" or "Flatpak"

    if [[ ! -d "$profiles_dir" ]]; then
        warn "$install_type Thunderbird profile directory not found"
        return 0
    fi

    local profiles=()
    while IFS= read -r -d '' p; do
        profiles+=("$p")
    done < <(find "$profiles_dir" -maxdepth 1 -mindepth 1 -type d ! -name "Crash Reports" ! -name "Pending Pings" -print0 2>/dev/null)

    for profile in "${profiles[@]}"; do
        local pname
        pname=$(basename "$profile")
        info "Cleaning $install_type Thunderbird profile: $pname"

        # Standard Mozilla cache cleanup
        safe_remove "$profile/cache2" "$pname/cache2"
        safe_remove "$profile/startupCache" "$pname/startupCache"
        safe_remove "$profile/thumbnails" "$pname/thumbnails"

        # Crash data
        safe_remove "$profile/minidumps" "$pname/minidumps"
        safe_remove "$profile/Crash Reports" "$pname/Crash Reports"

        # Shader cache
        safe_remove "$profile/shader-cache" "$pname/shader-cache"

        # Temp storage
        safe_remove "$profile/storage/temporary" "$pname/storage/temporary"

        # OAuth2 tokens (forces re-authentication with Office 365 etc.)
        if [[ "${CLEAN_OAUTH:-false}" == "true" ]]; then
            safe_remove "$profile/oauth-tokens.json" "$pname OAuth2 tokens"
        fi

        # IMAP offline cache
        if [[ "${CLEAN_OFFLINE:-false}" == "true" ]]; then
            if [[ -d "$profile/ImapMail" ]]; then
                # Remove .msf files (index files that get rebuilt)
                find "$profile/ImapMail" -name "*.msf" -delete 2>/dev/null
                success "Removed IMAP index files (.msf) in $pname"
            fi
        fi

        # Deep clean: search index database
        if [[ "${DEEP_CLEAN:-false}" == "true" ]]; then
            safe_remove "$profile/global-messages-db.sqlite" "$pname search index"
            safe_remove "$profile/places.sqlite-wal" "$pname places WAL"
            safe_remove "$profile/places.sqlite-shm" "$pname places SHM"
            safe_remove "$profile/webappsstore.sqlite" "$pname web app storage"
            safe_remove "$profile/cookies.sqlite" "$pname cookies"
        fi
    done
}

main() {
    local native_only=false
    local flatpak_only=false
    local snap_only=false
    CLEAN_OAUTH=false
    CLEAN_OFFLINE=false
    DEEP_CLEAN=false

    parse_common_flags "$@" || { show_help; exit 0; }

    for arg in "$@"; do
        case "$arg" in
            --native-only)   native_only=true ;;
            --flatpak-only)  flatpak_only=true ;;
            --snap-only)     snap_only=true ;;
            --oauth)         CLEAN_OAUTH=true ;;
            --offline-cache) CLEAN_OFFLINE=true ;;
            --deep)          CLEAN_OAUTH=true; CLEAN_OFFLINE=true; DEEP_CLEAN=true ;;
        esac
    done

    export CLEAN_OAUTH CLEAN_OFFLINE DEEP_CLEAN

    header "Thunderbird Cleanup Tool"

    # Check if Thunderbird is running
    if app_is_running "thunderbird"; then
        error "Thunderbird appears to be running. Please close it first."
        exit 1
    fi

    local cleaned=false

    # Native installation
    if [[ "$flatpak_only" != "true" && "$snap_only" != "true" ]] && [[ -d "$NATIVE_PROFILE_DIR" ]]; then
        header "Native Thunderbird"
        if confirm "Clean native Thunderbird cache and data?"; then
            safe_clean_dir "$NATIVE_CACHE_DIR" "Native Thunderbird cache"
            clean_thunderbird_profiles "$NATIVE_PROFILE_DIR" "Native"
            cleaned=true
        fi
    fi

    # Flatpak installation
    if [[ "$native_only" != "true" && "$snap_only" != "true" ]] && flatpak_installed "$FLATPAK_APP_ID"; then
        header "Flatpak Thunderbird"
        if confirm "Clean Flatpak Thunderbird cache and data?"; then
            safe_clean_dir "$FLATPAK_CACHE_DIR" "Flatpak Thunderbird cache"
            clean_thunderbird_profiles "$FLATPAK_PROFILE_DIR" "Flatpak"
            cleaned=true
        fi
    elif [[ "$native_only" != "true" && "$snap_only" != "true" ]]; then
        info "Flatpak Thunderbird not installed"
    fi

    # Snap installation
    if [[ "$native_only" != "true" && "$flatpak_only" != "true" ]] && snap_installed "$SNAP_NAME"; then
        header "Snap Thunderbird"
        if confirm "Clean Snap Thunderbird cache and data?"; then
            safe_clean_dir "$SNAP_CACHE_DIR" "Snap Thunderbird cache"
            clean_thunderbird_profiles "$SNAP_PROFILE_DIR" "Snap"
            cleaned=true
        fi
    elif [[ "$native_only" != "true" && "$flatpak_only" != "true" ]]; then
        info "Snap Thunderbird not installed"
    fi

    if [[ "$cleaned" == "true" ]]; then
        success "Thunderbird cleanup complete!"
    else
        warn "No Thunderbird installations found or no actions taken."
    fi
}

main "$@"
