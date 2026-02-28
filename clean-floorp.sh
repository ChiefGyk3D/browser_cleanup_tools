#!/usr/bin/env bash
# clean-floorp.sh - Clean Floorp cache, sessions, and temp data
# Supports both native and Flatpak installations
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# --- Path definitions ---
# Native (Floorp uses ~/.floorp for profiles)
NATIVE_PROFILE_DIR="$HOME/.floorp"
NATIVE_CACHE_DIR="$HOME/.cache/floorp"

# Flatpak
FLATPAK_APP_ID="one.ablaze.floorp"
FLATPAK_BASE="$HOME/.var/app/$FLATPAK_APP_ID"
FLATPAK_PROFILE_DIR="$FLATPAK_BASE/.floorp"
FLATPAK_CACHE_DIR="$FLATPAK_BASE/cache/floorp"

show_help() {
    cat <<EOF
${BOLD}Floorp Cleanup Tool${NC}

Clears cache, session data, and temp files for Floorp.
Supports both native and Flatpak installations.

Usage: $(basename "$0") [OPTIONS]

Options:
  -y, --yes         Skip confirmation prompts
  -n, --dry-run     Show what would be removed without deleting anything
  --native-only     Only clean native installation
  --flatpak-only    Only clean Flatpak installation
  --deep            Also remove site storage, cookies, and search history
  -h, --help        Show this help message

Examples:
  $(basename "$0")              # Clean cache for all installations
  $(basename "$0") --deep -y    # Deep clean, no prompts
  $(basename "$0") --dry-run    # Preview what would be cleaned

For profile management, see: floorp-profile-manager.sh
EOF
}

# Floorp-specific extended cleaning (same as Firefox since it's a fork)
clean_floorp_deep() {
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
    local deep=false

    parse_common_flags "$@" || { show_help; exit 0; }

    for arg in "$@"; do
        case "$arg" in
            --native-only)  native_only=true ;;
            --flatpak-only) flatpak_only=true ;;
            --deep)         deep=true ;;
        esac
    done

    header "Floorp Cleanup Tool"

    # Check if any Floorp installation exists before checking if running
    if [[ ! -d "$NATIVE_PROFILE_DIR" ]] \
        && ! flatpak_installed "$FLATPAK_APP_ID"; then
        warn "Floorp not found on this system"
        exit 0
    fi

    if app_is_running "floorp"; then
        error "Floorp appears to be running. Please close it first."
        exit 1
    fi

    local cleaned=false

    # Native installation
    if [[ "$flatpak_only" != "true" ]] && [[ -d "$NATIVE_PROFILE_DIR" ]]; then
        header "Native Floorp"
        if confirm "Clean native Floorp cache and data?"; then
            clean_mozilla_profile "$NATIVE_PROFILE_DIR" "$NATIVE_CACHE_DIR" "Native Floorp"
            if [[ "$deep" == "true" ]]; then
                while IFS= read -r -d '' p; do
                    clean_floorp_deep "$p"
                done < <(find "$NATIVE_PROFILE_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
            fi
            cleaned=true
        fi
    fi

    # Flatpak installation
    if [[ "$native_only" != "true" ]] && flatpak_installed "$FLATPAK_APP_ID"; then
        header "Flatpak Floorp"
        if confirm "Clean Flatpak Floorp cache and data?"; then
            clean_mozilla_profile "$FLATPAK_PROFILE_DIR" "$FLATPAK_CACHE_DIR" "Flatpak Floorp"
            if [[ "$deep" == "true" ]]; then
                while IFS= read -r -d '' p; do
                    clean_floorp_deep "$p"
                done < <(find "$FLATPAK_PROFILE_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
            fi
            cleaned=true
        fi
    elif [[ "$native_only" != "true" ]]; then
        info "Flatpak Floorp not installed"
    fi

    if [[ "$cleaned" == "true" ]]; then
        success "Floorp cleanup complete!"
    else
        warn "No Floorp installations found or no actions taken."
    fi
}

main "$@"
