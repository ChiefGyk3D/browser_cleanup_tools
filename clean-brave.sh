#!/usr/bin/env bash
# clean-brave.sh - Clean Brave Browser cache, sessions, and temp data
# Supports both native and Flatpak installations
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# --- Path definitions ---
# Native
NATIVE_PROFILE_DIR="$HOME/.config/BraveSoftware/Brave-Browser"
NATIVE_CACHE_DIR="$HOME/.cache/BraveSoftware/Brave-Browser"

# Flatpak
FLATPAK_APP_ID="com.brave.Browser"
FLATPAK_BASE="$HOME/.var/app/$FLATPAK_APP_ID"
FLATPAK_PROFILE_DIR="$FLATPAK_BASE/config/BraveSoftware/Brave-Browser"
FLATPAK_CACHE_DIR="$FLATPAK_BASE/cache/BraveSoftware/Brave-Browser"

show_help() {
    cat <<EOF
${BOLD}Brave Browser Cleanup Tool${NC}

Clears cache, session data, and temp files for Brave Browser.
Supports both native and Flatpak installations.

Usage: $(basename "$0") [OPTIONS]

Options:
  -y, --yes         Skip confirmation prompts
  --native-only     Only clean native installation
  --flatpak-only    Only clean Flatpak installation
  -h, --help        Show this help message

Examples:
  $(basename "$0")              # Clean cache for all installations
  $(basename "$0") -y           # Clean everything, no prompts
EOF
}

main() {
    local native_only=false
    local flatpak_only=false

    parse_common_flags "$@" || { show_help; exit 0; }

    for arg in "$@"; do
        case "$arg" in
            --native-only)  native_only=true ;;
            --flatpak-only) flatpak_only=true ;;
        esac
    done

    header "Brave Browser Cleanup Tool"

    if app_is_running "brave" || app_is_running "brave-browser"; then
        error "Brave appears to be running. Please close it first."
        exit 1
    fi

    local cleaned=false

    # Native installation
    if [[ "$flatpak_only" != "true" ]] && [[ -d "$NATIVE_PROFILE_DIR" ]]; then
        header "Native Brave"
        if confirm "Clean native Brave cache and data?"; then
            safe_clean_dir "$NATIVE_CACHE_DIR" "Native Brave cache"
            clean_chromium_profile "$NATIVE_PROFILE_DIR" "Native Brave"
            cleaned=true
        fi
    fi

    # Flatpak installation
    if [[ "$native_only" != "true" ]] && flatpak_installed "$FLATPAK_APP_ID"; then
        header "Flatpak Brave"
        if confirm "Clean Flatpak Brave cache and data?"; then
            safe_clean_dir "$FLATPAK_CACHE_DIR" "Flatpak Brave cache"
            clean_chromium_profile "$FLATPAK_PROFILE_DIR" "Flatpak Brave"
            cleaned=true
        fi
    elif [[ "$native_only" != "true" ]]; then
        info "Flatpak Brave not installed"
    fi

    if [[ "$cleaned" == "true" ]]; then
        success "Brave cleanup complete!"
    else
        warn "No Brave installations found or no actions taken."
    fi
}

main "$@"
