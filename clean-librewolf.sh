#!/usr/bin/env bash
# clean-librewolf.sh - Cache and data cleaner for LibreWolf
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/paths.sh"
source "$SCRIPT_DIR/lib/config.sh"

show_help() {
    cat << EOF
LibreWolf Cache Cleaner

Usage: $(basename "$0") [OPTIONS]

Options:
  --deep              Deep clean (remove cookies, site data, form history)
  --max-age DAYS      Only clean cache files older than N days
  --min-size MB       Only clean if total cache exceeds N MB
  --native-only       Only clean native installation
  --flatpak-only      Only clean Flatpak installation
  -y, --yes           Auto-confirm all prompts
  -n, --dry-run       Show what would be deleted without removing
  -V, --version       Show version
  -h, --help          Show this help

Deep clean removes: cookies, site storage, form history, permissions, content preferences
EOF
}

clean_librewolf_deep() {
    local profile="$1"
    info "Deep cleaning profile: $(basename "$profile")"
    safe_remove "$profile/webappsstore.sqlite" "site storage"
    safe_remove "$profile/cookies.sqlite" "cookies"
    safe_remove "$profile/formhistory.sqlite" "form history"
    safe_remove "$profile/content-prefs.sqlite" "content preferences"
    safe_remove "$profile/permissions.sqlite" "permissions"
    safe_remove_glob "$profile" "*.sqlite-shm" "SQLite shared memory files"
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
            --max-age) shift; MAX_CACHE_AGE_DAYS="${2:-$MAX_CACHE_AGE_DAYS}" ;;
            --min-size) shift; MIN_CACHE_SIZE_MB="${2:-$MIN_CACHE_SIZE_MB}" ;;
        esac
    done

    [[ "$DEFAULT_CLEAN_LEVEL" == "deep" ]] && deep=true

    header "LibreWolf Cleanup"

    if browser_is_running "LIBREWOLF"; then
        error "LibreWolf is running. Please close it first."
        exit 1
    fi

    local cleaned=false

    for install_type in native flatpak; do
        [[ -n "$filter" && "$filter" != "${install_type}-only" && -n "$filter" ]] && continue

        local profile_dir cache_dir
        profile_dir=$(get_profile_path "LIBREWOLF" "$install_type")
        cache_dir=$(get_cache_path "LIBREWOLF" "$install_type")

        [[ ! -d "$profile_dir" ]] && continue

        info "Cleaning LibreWolf ($install_type)..."

        # Check thresholds
        if [[ -d "$cache_dir" ]]; then
            if ! cache_meets_size_threshold "$cache_dir"; then
                info "Cache below size threshold (${MIN_CACHE_SIZE_MB}MB), skipping"
                continue
            fi
        fi

        clean_mozilla_profile "$profile_dir" "$cache_dir" "LibreWolf ($install_type)"

        if $deep; then
            while IFS='|' read -r _ _ prof_path; do
                clean_librewolf_deep "$prof_path"
            done < <(find_mozilla_profiles "LIBREWOLF" "${install_type}-only" 2>/dev/null)
        fi

        cleaned=true
        log_info "Cleaned LibreWolf ($install_type)"
    done

    if ! $cleaned; then
        info "LibreWolf not found on this system"
    fi
}

main "$@"
