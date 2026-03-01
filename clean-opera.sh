#!/usr/bin/env bash
# clean-opera.sh - Cache and data cleaner for Opera
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/paths.sh"
source "$SCRIPT_DIR/lib/config.sh"

show_help() {
    cat << EOF
Opera Cache Cleaner

Usage: $(basename "$0") [OPTIONS]

Options:
  --deep              Deep clean (remove cookies, sessions, local storage, service workers)
  --max-age DAYS      Only clean cache files older than N days
  --min-size MB       Only clean if total cache exceeds N MB
  --native-only       Only clean native installation
  --flatpak-only      Only clean Flatpak installation
  -y, --yes           Auto-confirm all prompts
  -n, --dry-run       Show what would be deleted without removing
  -V, --version       Show version
  -h, --help          Show this help
EOF
}

main() {
    check_version_flag "$@"
    parse_common_flags "$@" || { show_help; exit 0; }

    local deep=false
    local filter="$DEFAULT_INSTALL_FILTER"

    for arg in "$@"; do
        case "$arg" in
            --deep) deep=true ;;
            --native-only) filter="native-only" ;;
            --flatpak-only) filter="flatpak-only" ;;
        esac
    done

    [[ "$DEFAULT_CLEAN_LEVEL" == "deep" ]] && deep=true

    header "Opera Cleanup"

    if browser_is_running "OPERA"; then
        error "Opera is running. Please close it first."
        exit 1
    fi

    local cleaned=false

    for install_type in native flatpak; do
        [[ -n "$filter" && "$filter" != "${install_type}-only" ]] && continue

        local profile_dir cache_dir
        profile_dir=$(get_profile_path "OPERA" "$install_type")
        cache_dir=$(get_cache_path "OPERA" "$install_type")

        [[ ! -d "$profile_dir" ]] && continue

        info "Cleaning Opera ($install_type)..."

        if [[ -d "$cache_dir" ]]; then
            safe_clean_dir "$cache_dir" "Opera cache ($install_type)"
        fi

        clean_chromium_profile "$profile_dir" "Opera ($install_type)"

        if $deep; then
            clean_chromium_deep "$profile_dir" "Opera ($install_type)"
        fi

        cleaned=true
        log_info "Cleaned Opera ($install_type)"
    done

    if ! $cleaned; then
        info "Opera not found on this system"
    fi
}

main "$@"
