#!/usr/bin/env bash
# harden-privacy.sh - Apply privacy-focused settings to Firefox/Floorp profiles
# Generates and applies a user.js with hardened privacy/security preferences
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# --- Path definitions ---
declare -A FIREFOX_PATHS=(
    [native]="$HOME/.mozilla/firefox"
    [flatpak]="$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
    [snap]="$HOME/snap/firefox/common/.mozilla/firefox"
)

declare -A FLOORP_PATHS=(
    [native]="$HOME/.floorp"
    [flatpak]="$HOME/.var/app/one.ablaze.floorp/.floorp"
)

# Hardening levels
LEVEL="standard"
TARGET_BROWSER=""
TARGET_PROFILE=""
DRY_RUN=false
AUTO_YES=false
BACKUP=true

show_help() {
    cat <<EOF
${BOLD}Privacy Hardening Tool${NC}

Apply privacy-focused user.js settings to Firefox and Floorp profiles.
Creates a backup of existing user.js before applying changes.

Usage: $(basename "$0") <command> [OPTIONS]

Commands:
  apply                Apply privacy settings to a profile
  show                 Display the settings that would be applied
  status               Show current privacy-relevant prefs in a profile
  revert               Restore the original user.js from backup

Levels:
  --standard           Balanced privacy (default) — minimal breakage
  --strict             Aggressive privacy — may break some sites
  --paranoid            Maximum privacy — significant site breakage expected

Options:
  --browser <name>     Target browser: firefox or floorp (default: both)
  --profile <name>     Target a specific profile (default: all)
  --no-backup          Don't backup existing user.js before applying
  -n, --dry-run        Show what would be applied without changing anything
  -y, --yes            Skip confirmation prompts
  -h, --help           Show this help message

Examples:
  $(basename "$0") show                            # Preview standard settings
  $(basename "$0") show --strict                   # Preview strict settings
  $(basename "$0") apply                           # Apply standard to all profiles
  $(basename "$0") apply --strict --browser firefox
  $(basename "$0") apply --profile default-release
  $(basename "$0") status --browser firefox        # Show current prefs
  $(basename "$0") revert                          # Restore backups
EOF
}

# ---- Privacy settings by level ----

generate_user_js() {
    local level="$1"

    cat <<'HEADER'
// ============================================================
// Browser Cleanup Tools — Privacy Hardening user.js
// https://github.com/chiefgyk3d/Browser_Cleanup_Tools
//
// Auto-generated. To revert, restore user.js.backup or delete user.js
// and restart the browser.
// ============================================================

HEADER

    # Standard settings (applied at all levels)
    cat <<'STANDARD'
// --- STANDARD PRIVACY ---

// Disable telemetry and data collection
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);

// Disable crash reporter
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false);
user_pref("browser.crashReports.unsubmittedCheck.enabled", false);
user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);

// Disable studies and experiments
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("app.normandy.enabled", false);
user_pref("app.normandy.api_url", "");

// Disable sponsored content and recommendations
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);

// Enhanced Tracking Protection — strict
user_pref("browser.contentblocking.category", "strict");
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);

// DNS-over-HTTPS (DoH) — use Mozilla's default
user_pref("network.trr.mode", 2);

// Disable prefetching (prevents DNS/connection leaks)
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.dns.disablePrefetchFromHTTPS", true);
user_pref("network.predictor.enabled", false);
user_pref("network.http.speculative-parallel-limit", 0);

// HTTPS-only mode
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_send_http_background_request", false);

// Disable form autofill
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);

// Ask where to save downloads
user_pref("browser.download.useDownloadDir", false);
STANDARD

    # Strict settings
    if [[ "$level" == "strict" || "$level" == "paranoid" ]]; then
        cat <<'STRICT'

// --- STRICT PRIVACY ---

// Isolate cookies to first-party (Total Cookie Protection)
user_pref("network.cookie.cookieBehavior", 5);
user_pref("privacy.partition.network_state.ocsp_cache", true);

// Enable state partitioning (dFPI)
user_pref("privacy.partition.serviceWorkers", true);
user_pref("privacy.partition.always_partition_third_party_non_cookie_storage", true);
user_pref("privacy.partition.always_partition_third_party_non_cookie_storage.exempt_sessionstorage", false);

// Disable WebRTC IP leak
user_pref("media.peerconnection.ice.default_address_only", true);
user_pref("media.peerconnection.ice.no_host", true);
user_pref("media.peerconnection.ice.proxy_only_if_behind_proxy", true);

// Disable beacon tracking
user_pref("beacon.enabled", false);

// Disable battery status API
user_pref("dom.battery.enabled", false);

// Disable Sensor APIs
user_pref("device.sensors.enabled", false);

// Clear data on shutdown
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("privacy.clearOnShutdown.cache", true);
user_pref("privacy.clearOnShutdown.downloads", true);
user_pref("privacy.clearOnShutdown.formdata", true);
user_pref("privacy.clearOnShutdown.history", false);
user_pref("privacy.clearOnShutdown.sessions", true);
user_pref("privacy.clearOnShutdown.cookies", false);

// Disable search suggestions (prevent keystroke leaking)
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.suggest.searches", false);

// Disable Firefox accounts / Sync promos
user_pref("identity.fxaccounts.enabled", false);

// Resist fingerprinting helpers
user_pref("privacy.resistFingerprinting.block_mozAddonManager", true);
user_pref("extensions.webcompat.enable_shims", true);

// Disable Pocket
user_pref("extensions.pocket.enabled", false);
STRICT
    fi

    # Paranoid settings
    if [[ "$level" == "paranoid" ]]; then
        cat <<'PARANOID'

// --- PARANOID PRIVACY ---
// WARNING: These settings WILL break many websites!

// Resist fingerprinting (RFP) — changes timezone, locale, screen size
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.resistFingerprinting.letterboxing", true);

// Disable WebGL (fingerprinting vector)
user_pref("webgl.disabled", true);

// Disable WebRTC entirely
user_pref("media.peerconnection.enabled", false);

// Disable JavaScript JIT (hardening, slower performance)
user_pref("javascript.options.baselinejit", false);
user_pref("javascript.options.ion", false);

// Clear ALL data on shutdown
user_pref("privacy.clearOnShutdown.cookies", true);
user_pref("privacy.clearOnShutdown.history", true);
user_pref("privacy.clearOnShutdown.offlineApps", true);
user_pref("privacy.clearOnShutdown.siteSettings", true);

// Disable media autoplay
user_pref("media.autoplay.default", 5);

// Disable DRM content
user_pref("media.eme.enabled", false);

// Disable geolocation
user_pref("geo.enabled", false);

// Disable push notifications
user_pref("dom.push.enabled", false);

// Disable Web Notifications
user_pref("dom.webnotifications.enabled", false);

// Limit font fingerprinting
user_pref("layout.css.font-visibility.level", 1);

// Strict referrer policy
user_pref("network.http.referer.XOriginPolicy", 2);
user_pref("network.http.referer.XOriginTrimmingPolicy", 2);

// Disable captive portal detection
user_pref("captivedetect.canonicalURL", "");
user_pref("network.captive-portal-service.enabled", false);

// Disable network connectivity check
user_pref("network.connectivity-service.enabled", false);
PARANOID
    fi
}

# ---- Profile discovery ----

find_profiles() {
    local -n path_map=$1
    local results=()

    for install_type in "${!path_map[@]}"; do
        local base_dir="${path_map[$install_type]}"
        [[ ! -d "$base_dir" ]] && continue

        local profiles_ini="$base_dir/profiles.ini"
        [[ ! -f "$profiles_ini" ]] && continue

        while IFS= read -r line; do
            if [[ "$line" =~ ^Path= ]]; then
                local rel_path="${line#Path=}"
                local full_path
                if [[ "$rel_path" == /* ]]; then
                    full_path="$rel_path"
                else
                    full_path="$base_dir/$rel_path"
                fi
                if [[ -d "$full_path" ]]; then
                    results+=("$install_type|$full_path")
                fi
            fi
        done < "$profiles_ini"
    done

    printf '%s\n' "${results[@]}"
}

# ---- Apply to a single profile ----

apply_to_profile() {
    local profile_dir="$1"
    local level="$2"
    local profile_name
    profile_name=$(basename "$profile_dir")

    local user_js="$profile_dir/user.js"

    # Backup existing user.js
    if [[ -f "$user_js" && "$BACKUP" == "true" ]]; then
        local backup_name="$user_js.backup.$(date +%Y%m%d_%H%M%S)"
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "${MAGENTA}[DRY-RUN]${NC} Would backup $user_js → $backup_name"
        else
            cp "$user_js" "$backup_name"
            success "Backed up existing user.js → $(basename "$backup_name")"
        fi
    fi

    # Generate and apply
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${MAGENTA}[DRY-RUN]${NC} Would write ${level} privacy settings to $user_js"
    else
        generate_user_js "$level" > "$user_js"
        success "Applied ${level} privacy settings to profile: $profile_name"
    fi
}

# ---- Show current privacy-relevant prefs ----

show_profile_status() {
    local profile_dir="$1"
    local profile_name
    profile_name=$(basename "$profile_dir")

    local prefs_file="$profile_dir/prefs.js"
    local user_file="$profile_dir/user.js"

    echo -e "  ${BOLD}Profile: $profile_name${NC}"

    # Check if our user.js is applied
    if [[ -f "$user_file" ]] && grep -q "Browser Cleanup Tools" "$user_file" 2>/dev/null; then
        local level="unknown"
        grep -q "PARANOID PRIVACY" "$user_file" && level="paranoid"
        [[ "$level" == "unknown" ]] && grep -q "STRICT PRIVACY" "$user_file" && level="strict"
        [[ "$level" == "unknown" ]] && grep -q "STANDARD PRIVACY" "$user_file" && level="standard"
        echo -e "    Hardening: ${GREEN}applied${NC} (${level})"
    elif [[ -f "$user_file" ]]; then
        echo -e "    Hardening: ${YELLOW}custom user.js present${NC}"
    else
        echo -e "    Hardening: ${DIM}not applied${NC}"
    fi

    # Check key prefs from prefs.js
    if [[ -f "$prefs_file" ]]; then
        local checks=(
            "toolkit.telemetry.enabled|Telemetry|false"
            "privacy.trackingprotection.enabled|Tracking Protection|true"
            "dom.security.https_only_mode|HTTPS-Only Mode|true"
            "network.trr.mode|DNS-over-HTTPS|2"
            "browser.contentblocking.category|Content Blocking|strict"
            "privacy.resistFingerprinting|Resist Fingerprinting|true"
            "media.peerconnection.ice.default_address_only|WebRTC IP Protection|true"
            "privacy.sanitize.sanitizeOnShutdown|Clear on Shutdown|true"
        )

        for check in "${checks[@]}"; do
            IFS='|' read -r pref_name label desired <<< "$check"
            local current
            current=$(grep -oP "user_pref\\(\"$pref_name\",\\s*\\K[^)]*" "$prefs_file" 2>/dev/null | tr -d ' "' || echo "default")
            # Also check user.js
            if [[ -f "$user_file" ]]; then
                local user_val
                user_val=$(grep -oP "user_pref\\(\"$pref_name\",\\s*\\K[^)]*" "$user_file" 2>/dev/null | tr -d ' "' || echo "")
                [[ -n "$user_val" ]] && current="$user_val"
            fi

            if [[ "$current" == "$desired" ]]; then
                echo -e "    ${GREEN}✓${NC} $label: $current"
            elif [[ "$current" == "default" ]]; then
                echo -e "    ${DIM}○${NC} $label: ${DIM}default${NC}"
            else
                echo -e "    ${YELLOW}✗${NC} $label: $current ${DIM}(recommended: $desired)${NC}"
            fi
        done
    else
        echo -e "    ${DIM}No prefs.js found${NC}"
    fi
    echo ""
}

# ---- Revert user.js ----

revert_profile() {
    local profile_dir="$1"
    local profile_name
    profile_name=$(basename "$profile_dir")

    local user_js="$profile_dir/user.js"

    # Find the most recent backup
    local latest_backup=""
    for backup in "$profile_dir"/user.js.backup.*; do
        [[ -f "$backup" ]] && latest_backup="$backup"
    done

    if [[ -n "$latest_backup" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "${MAGENTA}[DRY-RUN]${NC} Would restore $(basename "$latest_backup") → user.js in $profile_name"
        else
            cp "$latest_backup" "$user_js"
            success "Restored user.js from $(basename "$latest_backup") in profile: $profile_name"
        fi
    elif [[ -f "$user_js" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "${MAGENTA}[DRY-RUN]${NC} Would remove user.js from $profile_name (no backup found)"
        else
            rm "$user_js"
            success "Removed user.js from profile: $profile_name (no backup to restore)"
        fi
    else
        info "No user.js found in profile: $profile_name"
    fi
}

# ---- Main ----

main() {
    local command=""

    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            apply|show|status|revert) command="$arg" ;;
            --standard) LEVEL="standard" ;;
            --strict)   LEVEL="strict" ;;
            --paranoid)  LEVEL="paranoid" ;;
            --no-backup) BACKUP=false ;;
            -n|--dry-run) DRY_RUN=true ;;
            -y|--yes)    AUTO_YES=true ;;
            -h|--help)   show_help; exit 0 ;;
        esac
    done

    # Parse --browser and --profile
    local prev=""
    for arg in "$@"; do
        if [[ "$prev" == "--browser" ]]; then
            TARGET_BROWSER="$arg"
        elif [[ "$prev" == "--profile" ]]; then
            TARGET_PROFILE="$arg"
        fi
        prev="$arg"
    done

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${MAGENTA}${BOLD}*** DRY-RUN MODE — no files will be changed ***${NC}"
    fi

    case "$command" in
        show)
            header "Privacy Hardening Settings (${LEVEL})"
            generate_user_js "$LEVEL"
            ;;
        apply)
            header "Applying ${LEVEL} Privacy Hardening"
            echo -e "${BOLD}Level: ${LEVEL}${NC}"
            case "$LEVEL" in
                standard) echo -e "Balanced privacy — minimal breakage\n" ;;
                strict)   echo -e "${YELLOW}Aggressive privacy — some sites may break${NC}\n" ;;
                paranoid)  echo -e "${RED}Maximum privacy — significant site breakage expected${NC}\n" ;;
            esac

            if [[ "$AUTO_YES" != "true" && "$DRY_RUN" != "true" ]]; then
                confirm "Apply ${LEVEL} privacy settings?" || { info "Cancelled."; exit 0; }
            fi

            local applied=0

            # Firefox
            if [[ -z "$TARGET_BROWSER" || "$TARGET_BROWSER" == "firefox" ]]; then
                echo -e "\n${BOLD}Firefox${NC}"
                while IFS='|' read -r install_type profile_dir; do
                    [[ -z "$profile_dir" ]] && continue
                    local pname
                    pname=$(basename "$profile_dir")
                    if [[ -n "$TARGET_PROFILE" && "$pname" != *"$TARGET_PROFILE"* ]]; then
                        continue
                    fi
                    echo -e "  ${DIM}[$install_type]${NC} $pname"
                    apply_to_profile "$profile_dir" "$LEVEL"
                    ((applied++))
                done < <(find_profiles FIREFOX_PATHS)
            fi

            # Floorp
            if [[ -z "$TARGET_BROWSER" || "$TARGET_BROWSER" == "floorp" ]]; then
                echo -e "\n${BOLD}Floorp${NC}"
                while IFS='|' read -r install_type profile_dir; do
                    [[ -z "$profile_dir" ]] && continue
                    local pname
                    pname=$(basename "$profile_dir")
                    if [[ -n "$TARGET_PROFILE" && "$pname" != *"$TARGET_PROFILE"* ]]; then
                        continue
                    fi
                    echo -e "  ${DIM}[$install_type]${NC} $pname"
                    apply_to_profile "$profile_dir" "$LEVEL"
                    ((applied++))
                done < <(find_profiles FLOORP_PATHS)
            fi

            echo ""
            if [[ "$applied" -eq 0 ]]; then
                warn "No matching profiles found"
            else
                success "Applied settings to $applied profile(s)"
                echo -e "\n${DIM}Restart your browser for settings to take effect.${NC}"
            fi
            ;;
        status)
            header "Privacy Status"

            if [[ -z "$TARGET_BROWSER" || "$TARGET_BROWSER" == "firefox" ]]; then
                echo -e "${BOLD}Firefox${NC}"
                while IFS='|' read -r install_type profile_dir; do
                    [[ -z "$profile_dir" ]] && continue
                    local pname
                    pname=$(basename "$profile_dir")
                    if [[ -n "$TARGET_PROFILE" && "$pname" != *"$TARGET_PROFILE"* ]]; then
                        continue
                    fi
                    show_profile_status "$profile_dir"
                done < <(find_profiles FIREFOX_PATHS)
            fi

            if [[ -z "$TARGET_BROWSER" || "$TARGET_BROWSER" == "floorp" ]]; then
                echo -e "${BOLD}Floorp${NC}"
                while IFS='|' read -r install_type profile_dir; do
                    [[ -z "$profile_dir" ]] && continue
                    local pname
                    pname=$(basename "$profile_dir")
                    if [[ -n "$TARGET_PROFILE" && "$pname" != *"$TARGET_PROFILE"* ]]; then
                        continue
                    fi
                    show_profile_status "$profile_dir"
                done < <(find_profiles FLOORP_PATHS)
            fi
            ;;
        revert)
            header "Reverting Privacy Hardening"

            if [[ "$AUTO_YES" != "true" && "$DRY_RUN" != "true" ]]; then
                confirm "Revert privacy settings (restore original user.js)?" || { info "Cancelled."; exit 0; }
            fi

            if [[ -z "$TARGET_BROWSER" || "$TARGET_BROWSER" == "firefox" ]]; then
                echo -e "\n${BOLD}Firefox${NC}"
                while IFS='|' read -r install_type profile_dir; do
                    [[ -z "$profile_dir" ]] && continue
                    local pname
                    pname=$(basename "$profile_dir")
                    if [[ -n "$TARGET_PROFILE" && "$pname" != *"$TARGET_PROFILE"* ]]; then
                        continue
                    fi
                    revert_profile "$profile_dir"
                done < <(find_profiles FIREFOX_PATHS)
            fi

            if [[ -z "$TARGET_BROWSER" || "$TARGET_BROWSER" == "floorp" ]]; then
                echo -e "\n${BOLD}Floorp${NC}"
                while IFS='|' read -r install_type profile_dir; do
                    [[ -z "$profile_dir" ]] && continue
                    local pname
                    pname=$(basename "$profile_dir")
                    if [[ -n "$TARGET_PROFILE" && "$pname" != *"$TARGET_PROFILE"* ]]; then
                        continue
                    fi
                    revert_profile "$profile_dir"
                done < <(find_profiles FLOORP_PATHS)
            fi

            echo -e "\n${DIM}Restart your browser for changes to take effect.${NC}"
            ;;
        *)
            show_help
            exit 0
            ;;
    esac
}

main "$@"
