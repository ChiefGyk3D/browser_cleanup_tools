#!/usr/bin/env bash
# clean-chromium.sh - Clean Chromium cache, sessions, and temp data
# Supports both native and Flatpak installations
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# --- Path definitions ---
# Native
NATIVE_PROFILE_DIR="$HOME/.config/chromium"
NATIVE_CACHE_DIR="$HOME/.cache/chromium"

# Flatpak
FLATPAK_APP_ID="org.chromium.Chromium"
FLATPAK_BASE="$HOME/.var/app/$FLATPAK_APP_ID"
FLATPAK_PROFILE_DIR="$FLATPAK_BASE/config/chromium"
FLATPAK_CACHE_DIR="$FLATPAK_BASE/cache/chromium"

show_help() {
    cat <<EOF
${BOLD}Chromium Cleanup Tool${NC}

Clears cache, session data, and temp files for Chromium.
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

    header "Chromium Cleanup Tool"

    if app_is_running "chromium" || app_is_running "chromium-browser"; then
        error "Chromium appears to be running. Please close it first."
        exit 1
    fi

    local cleaned=false

    # Native installation
    if [[ "$flatpak_only" != "true" ]] && [[ -d "$NATIVE_PROFILE_DIR" ]]; then
        header "Native Chromium"
        if confirm "Clean native Chromium cache and data?"; then
            safe_clean_dir "$NATIVE_CACHE_DIR" "Native Chromium cache"
            clean_chromium_profile "$NATIVE_PROFILE_DIR" "Native Chromium"
            cleaned=true
        fi
    fi

    # Flatpak installation
    if [[ "$native_only" != "true" ]] && flatpak_installed "$FLATPAK_APP_ID"; then
        header "Flatpak Chromium"
        if confirm "Clean Flatpak Chromium cache and data?"; then
            safe_clean_dir "$FLATPAK_CACHE_DIR" "Flatpak Chromium cache"
            clean_chromium_profile "$FLATPAK_PROFILE_DIR" "Flatpak Chromium"
            cleaned=true
        fi
    elif [[ "$native_only" != "true" ]]; then
        info "Flatpak Chromium not installed"
    fi

    if [[ "$cleaned" == "true" ]]; then
        success "Chromium cleanup complete!"
    else
        warn "No Chromium installations found or no actions taken."
    fi
}

main "$@"
