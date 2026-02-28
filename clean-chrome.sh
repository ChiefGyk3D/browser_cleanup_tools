#!/usr/bin/env bash
# clean-chrome.sh - Clean Google Chrome cache, sessions, and temp data
# Native installation only (Chrome is not available as a Flatpak or Snap)
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# --- Path definitions ---
NATIVE_PROFILE_DIR="$HOME/.config/google-chrome"
NATIVE_CACHE_DIR="$HOME/.cache/google-chrome"

show_help() {
    cat <<EOF
${BOLD}Google Chrome Cleanup Tool${NC}

Clears cache, session data, and temp files for Google Chrome.
Chrome is only available as a native installation on Linux.

Usage: $(basename "$0") [OPTIONS]

Options:
  -y, --yes       Skip confirmation prompts
  -n, --dry-run   Show what would be removed without deleting anything
  -h, --help      Show this help message

Examples:
  $(basename "$0")          # Clean Chrome cache
  $(basename "$0") -y       # Clean without prompts
  $(basename "$0") --dry-run # Preview what would be cleaned
EOF
}

main() {
    parse_common_flags "$@" || { show_help; exit 0; }

    header "Google Chrome Cleanup Tool"

    if app_is_running "chrome" || app_is_running "google-chrome"; then
        error "Google Chrome appears to be running. Please close it first."
        exit 1
    fi

    if [[ ! -d "$NATIVE_PROFILE_DIR" ]]; then
        warn "Google Chrome not found at $NATIVE_PROFILE_DIR"
        exit 0
    fi

    if confirm "Clean Google Chrome cache and data?"; then
        safe_clean_dir "$NATIVE_CACHE_DIR" "Chrome cache"
        clean_chromium_profile "$NATIVE_PROFILE_DIR" "Google Chrome"
        success "Google Chrome cleanup complete!"
    fi
}

main "$@"
