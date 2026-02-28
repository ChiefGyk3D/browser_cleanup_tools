#!/usr/bin/env bash
# disk-report.sh - Show disk usage for all supported browsers and email clients
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

show_help() {
    cat <<EOF
${BOLD}Browser Disk Usage Report${NC}

Shows how much disk space is used by each browser/email client,
broken down by cache, profiles, and installation type.

Usage: $(basename "$0") [OPTIONS]

Options:
  --json        Output in JSON format
  -h, --help    Show this help message

Examples:
  $(basename "$0")          # Show disk usage report
  $(basename "$0") --json   # Machine-readable output
EOF
}

JSON_MODE=false
TOTAL_BYTES=0
TOTAL_CACHE_BYTES=0
TOTAL_PROFILE_BYTES=0

# Add to running total
add_bytes() {
    local bytes="$1"
    TOTAL_BYTES=$((TOTAL_BYTES + bytes))
}

# Report a single app's disk usage
# Usage: report_app "App Name" "Type" "profile_dir" "cache_dir"
report_app() {
    local app_name="$1"
    local install_type="$2"
    local profile_dir="$3"
    local cache_dir="$4"

    local profile_bytes=0
    local cache_bytes=0
    local profile_size="—"
    local cache_size="—"
    local total_size="—"

    if [[ -d "$profile_dir" ]]; then
        profile_bytes=$(get_size_bytes "$profile_dir")
        profile_size=$(get_size "$profile_dir")
    fi

    if [[ -d "$cache_dir" ]]; then
        cache_bytes=$(get_size_bytes "$cache_dir")
        cache_size=$(get_size "$cache_dir")
    fi

    local total_bytes=$((profile_bytes + cache_bytes))

    if [[ "$total_bytes" -eq 0 ]]; then
        return  # Skip if nothing found
    fi

    total_size=$(human_size "$total_bytes")
    TOTAL_CACHE_BYTES=$((TOTAL_CACHE_BYTES + cache_bytes))
    TOTAL_PROFILE_BYTES=$((TOTAL_PROFILE_BYTES + profile_bytes))
    add_bytes "$total_bytes"

    if [[ "$JSON_MODE" == "true" ]]; then
        echo "    {\"app\": \"$app_name\", \"type\": \"$install_type\", \"profile_bytes\": $profile_bytes, \"cache_bytes\": $cache_bytes, \"total_bytes\": $total_bytes},"
    else
        printf "  ${BOLD}%-20s${NC} %-10s  Profile: %-8s  Cache: %-8s  ${CYAN}Total: %-8s${NC}\n" \
            "$app_name" "($install_type)" "$profile_size" "$cache_size" "$total_size"
    fi
}

# Report on a Mozilla-based app
report_mozilla() {
    local app_name="$1"

    local native_profiles="$2"
    local native_cache="$3"
    local flatpak_profiles="$4"
    local flatpak_cache="$5"
    local snap_profiles="${6:-}"
    local snap_cache="${7:-}"

    report_app "$app_name" "Native" "$native_profiles" "$native_cache"
    report_app "$app_name" "Flatpak" "$flatpak_profiles" "$flatpak_cache"
    if [[ -n "$snap_profiles" ]]; then
        report_app "$app_name" "Snap" "$snap_profiles" "$snap_cache"
    fi
}

# Report on a Chromium-based app
report_chromium() {
    local app_name="$1"

    local native_profiles="$2"
    local native_cache="$3"
    local flatpak_profiles="$4"
    local flatpak_cache="$5"
    local snap_profiles="${6:-}"
    local snap_cache="${7:-}"

    report_app "$app_name" "Native" "$native_profiles" "$native_cache"
    report_app "$app_name" "Flatpak" "$flatpak_profiles" "$flatpak_cache"
    if [[ -n "$snap_profiles" ]]; then
        report_app "$app_name" "Snap" "$snap_profiles" "$snap_cache"
    fi
}

main() {
    for arg in "$@"; do
        case "$arg" in
            --json) JSON_MODE=true ;;
            -h|--help) show_help; exit 0 ;;
        esac
    done

    if [[ "$JSON_MODE" == "true" ]]; then
        echo "{"
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"apps\": ["
    else
        header "Browser & Email Client Disk Usage Report"
        echo -e "  ${DIM}Scanning all supported applications...${NC}\n"
    fi

    # --- Thunderbird ---
    report_mozilla "Thunderbird" \
        "$HOME/.thunderbird" "$HOME/.cache/thunderbird" \
        "$HOME/.var/app/org.mozilla.Thunderbird/.thunderbird" "$HOME/.var/app/org.mozilla.Thunderbird/cache" \
        "$HOME/snap/thunderbird/common/.thunderbird" "$HOME/snap/thunderbird/common/.cache/thunderbird"

    # --- Firefox ---
    report_mozilla "Firefox" \
        "$HOME/.mozilla/firefox" "$HOME/.cache/mozilla/firefox" \
        "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox" "$HOME/.var/app/org.mozilla.firefox/cache/mozilla/firefox" \
        "$HOME/snap/firefox/common/.mozilla/firefox" "$HOME/snap/firefox/common/.cache/mozilla/firefox"

    # --- Floorp ---
    report_mozilla "Floorp" \
        "$HOME/.floorp" "$HOME/.cache/floorp" \
        "$HOME/.var/app/one.ablaze.floorp/.floorp" "$HOME/.var/app/one.ablaze.floorp/cache/floorp"

    # --- Chromium ---
    report_chromium "Chromium" \
        "$HOME/.config/chromium" "$HOME/.cache/chromium" \
        "$HOME/.var/app/org.chromium.Chromium/config/chromium" "$HOME/.var/app/org.chromium.Chromium/cache/chromium" \
        "$HOME/snap/chromium/common/chromium" "$HOME/snap/chromium/common/.cache/chromium"

    # --- Brave ---
    report_chromium "Brave" \
        "$HOME/.config/BraveSoftware/Brave-Browser" "$HOME/.cache/BraveSoftware/Brave-Browser" \
        "$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser" "$HOME/.var/app/com.brave.Browser/cache/BraveSoftware/Brave-Browser" \
        "$HOME/snap/brave/common/.config/BraveSoftware/Brave-Browser" "$HOME/snap/brave/common/.cache/BraveSoftware/Brave-Browser"

    # --- Chrome ---
    report_app "Chrome" "Native" \
        "$HOME/.config/google-chrome" "$HOME/.cache/google-chrome"

    # --- Summary ---
    if [[ "$JSON_MODE" == "true" ]]; then
        # Remove trailing comma from last entry (best effort)
        echo "  ],"
        echo "  \"total_bytes\": $TOTAL_BYTES,"
        echo "  \"total_cache_bytes\": $TOTAL_CACHE_BYTES,"
        echo "  \"total_profile_bytes\": $TOTAL_PROFILE_BYTES"
        echo "}"
    else
        echo ""
        echo -e "  ${BOLD}────────────────────────────────────────────────────────────────${NC}"
        printf "  ${BOLD}%-20s${NC} %-10s  Profile: %-8s  Cache: %-8s  ${BOLD}${CYAN}Total: %-8s${NC}\n" \
            "GRAND TOTAL" "" \
            "$(human_size "$TOTAL_PROFILE_BYTES")" \
            "$(human_size "$TOTAL_CACHE_BYTES")" \
            "$(human_size "$TOTAL_BYTES")"
        echo ""

        if [[ "$TOTAL_BYTES" -eq 0 ]]; then
            info "No browser data found on this system."
        else
            info "Run ${BOLD}./clean-all.sh --dry-run${NC} to preview what can be safely cleaned."
        fi
    fi
}

main "$@"
