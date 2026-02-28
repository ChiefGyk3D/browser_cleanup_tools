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
  -y, --yes              Skip confirmation prompts
  -n, --dry-run          Show what would be removed without deleting anything
  --select               Interactively select which apps to clean
  --deep                 Deep clean where supported (Firefox, Floorp, Thunderbird)
  --thunderbird-oauth    Also clear Thunderbird OAuth2 tokens
  --native-only          Only clean native installations
  --flatpak-only         Only clean Flatpak installations
  --snap-only            Only clean Snap installations
  -h, --help             Show this help message

Supported Applications:
  - Thunderbird (native + Flatpak + Snap)
  - Firefox     (native + Flatpak + Snap)
  - Floorp      (native + Flatpak)
  - Chromium    (native + Flatpak + Snap)
  - Brave       (native + Flatpak + Snap)
  - Chrome      (native only)

Examples:
  $(basename "$0")                    # Clean all with prompts
  $(basename "$0") -y                 # Clean all, no prompts
  $(basename "$0") --deep -y          # Deep clean everything
  $(basename "$0") --dry-run          # Preview everything
  $(basename "$0") --select           # Pick which apps to clean
EOF
}

main() {
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

    # Define all available cleaners
    local -A cleaners=(
        [1-Thunderbird]="clean-thunderbird.sh"
        [2-Firefox]="clean-firefox.sh"
        [3-Floorp]="clean-floorp.sh"
        [4-Chromium]="clean-chromium.sh"
        [5-Brave]="clean-brave.sh"
        [6-Chrome]="clean-chrome.sh"
    )

    local run_list=()

    if [[ "$select_mode" == "true" ]]; then
        echo "Select which applications to clean:"
        echo ""
        for key in $(echo "${!cleaners[@]}" | tr ' ' '\n' | sort); do
            local name="${key#*-}"
            local script="${cleaners[$key]}"
            if [[ -f "$SCRIPT_DIR/$script" ]]; then
                if confirm "  Clean $name?"; then
                    run_list+=("$script")
                fi
            fi
        done
    else
        for key in $(echo "${!cleaners[@]}" | tr ' ' '\n' | sort); do
            run_list+=("${cleaners[$key]}")
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
