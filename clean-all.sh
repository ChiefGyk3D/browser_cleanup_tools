#!/usr/bin/env bash
# clean-all.sh - Run all cleanup scripts at once
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

show_help() {
    cat <<EOF
${BOLD}Browser Cleanup Tools — Clean All${NC}

Run cleanup for all supported browsers and email clients.

Usage: $(basename "$0") [OPTIONS]

Options:
  -V, --version          Show version
  -y, --yes              Skip confirmation prompts
  -n, --dry-run          Show what would be removed without deleting anything
  --select               Interactively select which apps to clean
  --deep                 Deep clean where supported
  --thunderbird-oauth    Also clear Thunderbird OAuth2 tokens
  --native-only          Only clean native installations
  --flatpak-only         Only clean Flatpak installations
  --snap-only            Only clean Snap installations
  -h, --help             Show this help message

Supported Applications:
  - Thunderbird (native + Flatpak + Snap)
  - Firefox     (native + Flatpak + Snap)
  - Floorp      (native + Flatpak)
  - LibreWolf   (native + Flatpak)
  - Waterfox    (native)
  - Zen         (native + Flatpak)
  - Chromium    (native + Flatpak + Snap)
  - Brave       (native + Flatpak + Snap)
  - Chrome      (native only)
  - Vivaldi     (native only)
  - Opera       (native only)

Examples:
  $(basename "$0")                    # Clean all with prompts
  $(basename "$0") -y                 # Clean all, no prompts
  $(basename "$0") --deep -y          # Deep clean everything
  $(basename "$0") --dry-run          # Preview everything
  $(basename "$0") --select           # Pick which apps to clean
EOF
}

main() {
    check_version_flag "$@" 2>/dev/null || true
    local select_mode=false
    local extra_args=()

    parse_common_flags "$@" || { show_help; exit 0; }

    for arg in "$@"; do
        case "$arg" in
            --select)            select_mode=true ;;
            --deep)              extra_args+=("--deep") ;;
            --thunderbird-oauth) extra_args+=("--oauth") ;;
            --native-only)       extra_args+=("--native-only") ;;
            --flatpak-only)      extra_args+=("--flatpak-only") ;;
            --snap-only)         extra_args+=("--snap-only") ;;
            -y|--yes)            extra_args+=("-y") ;;
            -n|--dry-run)        extra_args+=("--dry-run") ;;
        esac
    done

    header "Browser Cleanup Tools"
    echo "This will clean cache and temporary data for all detected browsers."
    echo ""

    # Define all available cleaners (order matters for display)
    local -a cleaner_order=(
        "Thunderbird:clean-thunderbird.sh"
        "Firefox:clean-firefox.sh"
        "Floorp:clean-floorp.sh"
        "LibreWolf:clean-librewolf.sh"
        "Waterfox:clean-waterfox.sh"
        "Zen:clean-zen.sh"
        "Chromium:clean-chromium.sh"
        "Brave:clean-brave.sh"
        "Chrome:clean-chrome.sh"
        "Vivaldi:clean-vivaldi.sh"
        "Opera:clean-opera.sh"
    )

    local run_list=()

    if [[ "$select_mode" == "true" ]]; then
        echo "Select which applications to clean:"
        echo ""
        for entry in "${cleaner_order[@]}"; do
            local name="${entry%%:*}"
            local script="${entry#*:}"
            if [[ -f "$SCRIPT_DIR/$script" ]]; then
                if confirm "  Clean $name?"; then
                    run_list+=("$script")
                fi
            fi
        done
    else
        for entry in "${cleaner_order[@]}"; do
            local script="${entry#*:}"
            [[ -f "$SCRIPT_DIR/$script" ]] && run_list+=("$script")
        done
    fi

    if [[ ${#run_list[@]} -eq 0 ]]; then
        warn "No applications selected for cleaning."
        exit 0
    fi

    local total=${#run_list[@]}
    local current=0
    local succeeded=0
    local failed=0

    for script in "${run_list[@]}"; do
        current=$((current + 1))
        local script_path="$SCRIPT_DIR/$script"

        if [[ ! -f "$script_path" ]]; then
            warn "Script not found: $script (skipped)"
            failed=$((failed + 1))
            continue
        fi

        echo ""
        info "[$current/$total] Running $script..."
        echo ""

        if bash "$script_path" "${extra_args[@]}"; then
            succeeded=$((succeeded + 1))
        else
            failed=$((failed + 1))
        fi
    done

    echo ""
    header "Summary"
    success "Completed: $succeeded/$total cleaners ran successfully"
    if [[ $failed -gt 0 ]]; then
        warn "Failed/skipped: $failed"
    fi
}

main "$@"
