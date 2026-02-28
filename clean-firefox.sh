#!/usr/bin/env bash
# clean-firefox.sh - Clean Firefox cache, sessions, and temp data
# Supports native, Flatpak, and Snap installations
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# --- Path definitions ---
# Native
NATIVE_PROFILE_DIR="$HOME/.mozilla/firefox"
NATIVE_CACHE_DIR="$HOME/.cache/mozilla/firefox"

# Flatpak
FLATPAK_APP_ID="org.mozilla.firefox"
FLATPAK_BASE="$HOME/.var/app/$FLATPAK_APP_ID"
FLATPAK_PROFILE_DIR="$FLATPAK_BASE/.mozilla/firefox"
FLATPAK_CACHE_DIR="$FLATPAK_BASE/cache/mozilla/firefox"

# Snap
SNAP_NAME="firefox"
SNAP_PROFILE_DIR="$HOME/snap/firefox/common/.mozilla/firefox"
SNAP_CACHE_DIR="$HOME/snap/firefox/common/.cache/mozilla/firefox"

show_help() {
    cat <<EOF
${BOLD}Firefox Cleanup Tool${NC}

Clears cache, session data, and temp files for Firefox.
Supports native, Flatpak, and Snap installations.

Usage: $(basename "$0") [OPTIONS]

Options:
  -y, --yes         Skip confirmation prompts
  -n, --dry-run     Show what would be removed without deleting anything
  --native-only     Only clean native installation
  --flatpak-only    Only clean Flatpak installation
  --snap-only       Only clean Snap installation
  --deep            Also remove site storage, cookies, and search history
  -h, --help        Show this help message

Examples:
  $(basename "$0")              # Clean cache for all installations
  $(basename "$0") --deep -y    # Deep clean, no prompts
  $(basename "$0") --dry-run    # Preview what would be cleaned

For profile management, see: firefox-profile-manager.sh
EOF
}

# Firefox-specific extended cleaning
clean_firefox_deep() {
    local profile="$1"
    local pname
    pname=$(basename "$profile")

    safe_remove "$profile/webappsstore.sqlite" "$pname web app storage"
    safe_remove "$profile/webappsstore.sqlite-wal" "$pname web app WAL"
    safe_remove "$profile/cookies.sqlite" "$pname cookies"
    safe_remove "$profile/cookies.sqlite-wal" "$pname cookies WAL"
    safe_remove "$profile/formhistory.sqlite" "$pname form history"
    safe_remove "$profile/content-prefs.sqlite" "$pname content prefs"
    safe_remove "$profile/permissions.sqlite" "$pname site permissions"
    safe_remove_glob "$profile" "*.sqlite-shm" "$pname SQLite shared memory files"
}

main() {
    local native_only=false
    local flatpak_only=false
    local snap_only=false
    local deep=false

    parse_common_flags "$@" || { show_help; exit 0; }

    for arg in "$@"; do
        case "$arg" in
            --native-only)  native_only=true ;;
            --flatpak-only) flatpak_only=true ;;
            --snap-only)    snap_only=true ;;
            --deep)         deep=true ;;
        esac
    done

    header "Firefox Cleanup Tool"

    if app_is_running "firefox"; then
        error "Firefox appears to be running. Please close it first."
        exit 1
    fi

    local cleaned=false

    # Native installation
    if [[ "$flatpak_only" != "true" && "$snap_only" != "true" ]] && [[ -d "$NATIVE_PROFILE_DIR" ]]; then
        header "Native Firefox"
        if confirm "Clean native Firefox cache and data?"; then
            clean_mozilla_profile "$NATIVE_PROFILE_DIR" "$NATIVE_CACHE_DIR" "Native Firefox"
            if [[ "$deep" == "true" ]]; then
                while IFS= read -r -d '' p; do
                    clean_firefox_deep "$p"
                done < <(find "$NATIVE_PROFILE_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
            fi
            cleaned=true
        fi
    fi

    # Flatpak installation
    if [[ "$native_only" != "true" && "$snap_only" != "true" ]] && flatpak_installed "$FLATPAK_APP_ID"; then
        header "Flatpak Firefox"
        if confirm "Clean Flatpak Firefox cache and data?"; then
            clean_mozilla_profile "$FLATPAK_PROFILE_DIR" "$FLATPAK_CACHE_DIR" "Flatpak Firefox"
            if [[ "$deep" == "true" ]]; then
                while IFS= read -r -d '' p; do
                    clean_firefox_deep "$p"
                done < <(find "$FLATPAK_PROFILE_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
            fi
            cleaned=true
        fi
    elif [[ "$native_only" != "true" && "$snap_only" != "true" ]]; then
        info "Flatpak Firefox not installed"
    fi

    # Snap installation
    if [[ "$native_only" != "true" && "$flatpak_only" != "true" ]] && snap_installed "$SNAP_NAME"; then
        header "Snap Firefox"
        if confirm "Clean Snap Firefox cache and data?"; then
            clean_mozilla_profile "$SNAP_PROFILE_DIR" "$SNAP_CACHE_DIR" "Snap Firefox"
            if [[ "$deep" == "true" ]]; then
                while IFS= read -r -d '' p; do
                    clean_firefox_deep "$p"
                done < <(find "$SNAP_PROFILE_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
            fi
            cleaned=true
        fi
    elif [[ "$native_only" != "true" && "$flatpak_only" != "true" ]]; then
        info "Snap Firefox not installed"
    fi

    if [[ "$cleaned" == "true" ]]; then
        success "Firefox cleanup complete!"
    else
        warn "No Firefox installations found or no actions taken."
    fi
}

main "$@"
