#!/usr/bin/env bash
# harden-privacy.sh - Apply privacy-focused settings to Mozilla browser profiles
# Generates and applies a user.js with hardened privacy/security preferences
# Incorporates settings from Betterfox (https://github.com/yokoffing/Betterfox)
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/paths.sh"
source "$SCRIPT_DIR/lib/profiles.sh"
source "$SCRIPT_DIR/lib/config.sh"

# Hardening levels
LEVEL="${DEFAULT_PRIVACY_LEVEL:-standard}"
TARGET_BROWSER=""
TARGET_PROFILE=""
BACKUP=true

show_help() {
    cat <<EOF
${BOLD}Privacy Hardening Tool${NC}

Apply privacy-focused user.js settings to Mozilla-based browser profiles.
Supports Firefox, Floorp, LibreWolf, Waterfox, and Zen Browser.
Incorporates best practices from the Betterfox project.
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
  --paranoid           Maximum privacy — significant site breakage expected

Options:
  --browser <name>     Target browser: firefox, floorp, librewolf, waterfox, zen
                       (default: all installed)
  --profile <name>     Target a specific profile (default: all)
  --no-backup          Don't backup existing user.js before applying
  -n, --dry-run        Show what would be applied without changing anything
  -y, --yes            Skip confirmation prompts
  -V, --version        Show version
  -h, --help           Show this help message

Examples:
  $(basename "$0") show                            # Preview standard settings
  $(basename "$0") show --strict                   # Preview strict settings
  $(basename "$0") apply                           # Apply standard to all profiles
  $(basename "$0") apply --strict --browser firefox
  $(basename "$0") apply --profile default-release
  $(basename "$0") apply --paranoid --browser librewolf
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
// Incorporates settings from Betterfox (yokoffing/Betterfox)
//
// Auto-generated. To revert, restore user.js.backup or delete user.js
// and restart the browser.
// ============================================================

HEADER

    # Standard settings (applied at all levels)
    cat <<'STANDARD'
// --- STANDARD PRIVACY ---
// Based on Betterfox Securefox.js + Peskyfox.js defaults

// ── Telemetry & Data Collection ──
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.telemetry.server", "data:,");
user_pref("toolkit.telemetry.coverage.opt-out", true);
user_pref("toolkit.coverage.opt-out", true);
user_pref("toolkit.coverage.endpoint.base", "");
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.usage.uploadEnabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
user_pref("browser.ping-centre.telemetry", false);

// ── Crash Reporter ──
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false);
user_pref("browser.crashReports.unsubmittedCheck.enabled", false);
user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);

// ── Studies & Experiments ──
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("app.normandy.enabled", false);
user_pref("app.normandy.api_url", "");

// ── Sponsored Content & Recommendations ──
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("browser.urlbar.quicksuggest.enabled", false);
user_pref("browser.urlbar.groupLabels.enabled", false);
user_pref("browser.discovery.enabled", false);
user_pref("extensions.getAddons.showPane", false);
user_pref("extensions.htmlaboutaddons.recommendations.enabled", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);
user_pref("browser.preferences.moreFromMozilla", false);

// ── Enhanced Tracking Protection — Strict ──
user_pref("browser.contentblocking.category", "strict");
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);

// ── Global Privacy Control (GPC) [Betterfox] ──
user_pref("privacy.globalprivacycontrol.enabled", true);

// ── DNS-over-HTTPS (DoH) ──
user_pref("network.trr.mode", 2);

// ── Speculative Loading — disable leaks [Betterfox] ──
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.dns.disablePrefetchFromHTTPS", true);
user_pref("network.predictor.enabled", false);
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("browser.urlbar.speculativeConnect.enabled", false);
user_pref("browser.places.speculativeConnect.enabled", false);

// ── HTTPS-Only Mode ──
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_error_page_user_suggestions", true);
user_pref("dom.security.https_only_mode_send_http_background_request", false);

// ── SSL/TLS Hardening [Betterfox] ──
user_pref("security.ssl.treat_unsafe_negotiation_as_broken", true);
user_pref("browser.xul.error_pages.expert_bad_cert", true);
user_pref("security.tls.enable_0rtt_data", false);

// ── Certificate Handling — CRLite over OCSP [Betterfox] ──
user_pref("security.OCSP.enabled", 0);
user_pref("security.csp.reporting.enabled", false);
user_pref("privacy.antitracking.isolateContentScriptResources", true);

// ── Referrer Trimming [Betterfox] ──
user_pref("network.http.referer.XOriginTrimmingPolicy", 2);

// ── Punycode for IDN — anti-spoofing [Betterfox] ──
user_pref("network.IDN_show_punycode", true);

// ── Form & Password Privacy [Betterfox] ──
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);
user_pref("browser.formfill.enable", false);
user_pref("signon.formlessCapture.enabled", false);
user_pref("signon.privateBrowsingCapture.enabled", false);
user_pref("network.auth.subresource-http-auth-allow", 1);
user_pref("editor.truncate_user_pastes", false);

// ── Extension Scope [Betterfox] ──
user_pref("extensions.enabledScopes", 5);

// ── PDF Scripting [Betterfox] ──
user_pref("pdfjs.enableScripting", false);

// ── Safe Browsing: disable remote checks [Betterfox] ──
user_pref("browser.safebrowsing.downloads.remote.enabled", false);

// ── Permissions Defaults [Betterfox] ──
user_pref("permissions.default.desktop-notification", 2);
user_pref("permissions.default.geo", 2);
user_pref("geo.provider.network.url", "https://beacondb.net/v1/geolocate");
user_pref("permissions.manager.defaultsUrl", "");

// ── Disk Avoidance [Betterfox] ──
user_pref("browser.cache.disk.enable", false);
user_pref("browser.privatebrowsing.forceMediaMemoryCache", true);
user_pref("media.memory_cache_max_size", 65536);
user_pref("browser.sessionstore.interval", 60000);

// ── Search Privacy [Betterfox] ──
user_pref("browser.search.update", false);
user_pref("browser.search.suggest.enabled", false);

// ── Container Tabs UI [Betterfox] ──
user_pref("privacy.userContext.ui.enabled", true);

// ── UI Cleanup [Betterfox Peskyfox] ──
user_pref("browser.uitour.enabled", false);
user_pref("browser.download.start_downloads_in_tmp_dir", true);
user_pref("browser.aboutConfig.showWarning", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.compactmode.show", true);
user_pref("browser.urlbar.trimHttps", true);
user_pref("browser.urlbar.untrimOnUserInteraction.featureGate", true);
user_pref("browser.search.separatePrivateDefault.ui.enabled", true);
user_pref("browser.privatebrowsing.resetPBM.enabled", true);

// ── Metadata & Addon cache [Betterfox] ──
user_pref("extensions.getAddons.cache.enabled", false);

// ── Privacy-Preserving Attribution — disable [Betterfox] ──
user_pref("dom.private-attribution.submission.enabled", false);

// ── Download ──
user_pref("browser.download.useDownloadDir", false);
STANDARD

    # Strict settings
    if [[ "$level" == "strict" || "$level" == "paranoid" ]]; then
        cat <<'STRICT'

// --- STRICT PRIVACY ---

// ── Cookie Isolation (Total Cookie Protection) ──
user_pref("network.cookie.cookieBehavior", 5);
user_pref("privacy.partition.network_state.ocsp_cache", true);

// ── State Partitioning (dFPI) [Betterfox] ──
user_pref("privacy.partition.serviceWorkers", true);
user_pref("privacy.partition.always_partition_third_party_non_cookie_storage", true);
user_pref("privacy.partition.always_partition_third_party_non_cookie_storage.exempt_sessionstorage", false);

// ── WebRTC IP Leak Protection ──
user_pref("media.peerconnection.ice.default_address_only", true);
user_pref("media.peerconnection.ice.no_host", true);
user_pref("media.peerconnection.ice.proxy_only_if_behind_proxy", true);

// ── Disable Tracking APIs [Betterfox] ──
user_pref("beacon.enabled", false);
user_pref("dom.battery.enabled", false);
user_pref("device.sensors.enabled", false);

// ── Shutdown Sanitization [Betterfox] ──
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("privacy.history.custom", true);
user_pref("privacy.clearOnShutdown.cache", true);
user_pref("privacy.clearOnShutdown_v2.cache", true);
user_pref("privacy.clearOnShutdown.downloads", true);
user_pref("privacy.clearOnShutdown.formdata", true);
user_pref("privacy.clearOnShutdown.history", false);
user_pref("privacy.clearOnShutdown_v2.historyFormDataAndDownloads", true);
user_pref("privacy.clearOnShutdown.sessions", true);
user_pref("privacy.clearOnShutdown.cookies", false);

// ── Search Privacy ──
user_pref("browser.urlbar.suggest.searches", false);

// ── Disable Firefox Accounts / Sync ──
user_pref("identity.fxaccounts.enabled", false);

// ── Fingerprinting Protection helpers [Betterfox] ──
user_pref("privacy.resistFingerprinting.block_mozAddonManager", true);
user_pref("extensions.webcompat.enable_shims", true);

// ── Disable Pocket ──
user_pref("extensions.pocket.enabled", false);

// ── Disable Firefox Relay ──
user_pref("signon.firefoxRelay.feature", "");

// ── SameSite Cookies [Betterfox] ──
user_pref("network.cookie.sameSite.laxByDefault", true);
user_pref("network.cookie.sameSite.schemeful", true);

// ── Encrypted Client Hello (ECH) [Betterfox] ──
user_pref("network.dns.echconfig.enabled", true);
user_pref("network.dns.http3_echconfig.enabled", true);

// ── SOCKS Proxy DNS [Betterfox] ──
user_pref("network.proxy.socks_remote_dns", true);

// ── AI Controls — disable [Betterfox Peskyfox] ──
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.chat.sidebar", false);
STRICT
    fi

    # Paranoid settings
    if [[ "$level" == "paranoid" ]]; then
        cat <<'PARANOID'

// --- PARANOID PRIVACY ---
// WARNING: These settings WILL break many websites!

// ── Resist Fingerprinting (RFP) — changes timezone, locale, screen size ──
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.resistFingerprinting.letterboxing", true);
user_pref("privacy.window.maxInnerWidth", 1600);
user_pref("privacy.window.maxInnerHeight", 900);

// ── Disable WebGL (fingerprinting vector) ──
user_pref("webgl.disabled", true);

// ── Disable WebRTC entirely ──
user_pref("media.peerconnection.enabled", false);

// ── Disable JavaScript JIT (hardening, slower performance) [Betterfox] ──
user_pref("javascript.options.baselinejit", false);
user_pref("javascript.options.ion", false);
user_pref("javascript.options.wasm", false);
user_pref("javascript.options.asmjs", false);

// ── Clear ALL data on shutdown [Betterfox] ──
user_pref("privacy.clearOnShutdown.cookies", true);
user_pref("privacy.clearOnShutdown.offlineApps", true);
user_pref("privacy.clearOnShutdown_v2.cookiesAndStorage", true);
user_pref("privacy.clearOnShutdown.history", true);
user_pref("privacy.clearOnShutdown.siteSettings", true);
user_pref("privacy.clearOnShutdown.openWindows", true);

// ── Disable media autoplay ──
user_pref("media.autoplay.default", 5);

// ── Disable DRM content ──
user_pref("media.eme.enabled", false);

// ── Disable geolocation ──
user_pref("geo.enabled", false);
user_pref("geo.provider.use_geoclue", false);

// ── Disable push notifications ──
user_pref("dom.push.enabled", false);

// ── Disable Web Notifications ──
user_pref("dom.webnotifications.enabled", false);

// ── Limit font fingerprinting ──
user_pref("layout.css.font-visibility.level", 1);

// ── Strict referrer policy ──
user_pref("network.http.referer.XOriginPolicy", 2);

// ── Disable captive portal detection [Betterfox] ──
user_pref("captivedetect.canonicalURL", "");
user_pref("network.captive-portal-service.enabled", false);

// ── Disable network connectivity check ──
user_pref("network.connectivity-service.enabled", false);

// ── Device access permissions — block all [Betterfox] ──
user_pref("permissions.default.camera", 2);
user_pref("permissions.default.microphone", 2);
user_pref("permissions.default.xr", 2);

// ── Disable GMP/Widevine ──
user_pref("media.gmp-provider.enabled", false);

// ── HPKP strict mode [Betterfox] ──
user_pref("security.cert_pinning.enforcement_level", 2);

// ── Disable password manager ──
user_pref("signon.rememberSignons", false);
user_pref("signon.autofillForms", false);

// ── Privacy Sandbox — block all [Betterfox] ──
user_pref("dom.private-attribution.submission.enabled", false);

// ── ECH fallback disable [Betterfox] ──
user_pref("network.dns.echconfig.fallback_to_origin_when_all_failed", false);

// ── Disable Media Router (Cast) ──
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
PARANOID
    fi
}

# ---- Helper functions ----

# Resolve CLI browser name to internal key
resolve_browser_key() {
    case "${1,,}" in
        firefox)   echo "FIREFOX" ;;
        floorp)    echo "FLOORP" ;;
        librewolf) echo "LIBREWOLF" ;;
        waterfox)  echo "WATERFOX" ;;
        zen)       echo "ZEN" ;;
        *) echo "${1^^}" ;;
    esac
}

# Get target browsers list
get_target_browsers() {
    if [[ -n "$TARGET_BROWSER" ]]; then
        echo "$TARGET_BROWSER"
    else
        printf '%s\n' "${MOZILLA_BROWSERS[@]}"
    fi
}

# Find profiles for a specific browser key using lib/profiles.sh
find_browser_profiles() {
    local browser_key="$1"
    find_profiles "$browser_key"
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
            "privacy.globalprivacycontrol.enabled|Global Privacy Control|true"
            "network.IDN_show_punycode|Punycode (anti-spoof)|true"
            "security.OCSP.enabled|OCSP (0=CRLite)|0"
            "pdfjs.enableScripting|PDF Scripting|false"
            "media.peerconnection.ice.default_address_only|WebRTC IP Protection|true"
            "privacy.sanitize.sanitizeOnShutdown|Clear on Shutdown|true"
            "privacy.resistFingerprinting|Resist Fingerprinting|true"
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

# ---- Iterate profiles for a browser ----

for_each_profile() {
    local browser_key="$1"
    local callback="$2"
    shift 2

    local display_name
    display_name=$(get_display_name "$browser_key")
    local found=false

    while IFS='|' read -r install_type profile_name profile_dir; do
        [[ -z "$profile_dir" ]] && continue
        if [[ -n "$TARGET_PROFILE" && "$profile_name" != *"$TARGET_PROFILE"* ]]; then
            continue
        fi
        if [[ "$found" == "false" ]]; then
            echo -e "\n${BOLD}${display_name}${NC}"
            found=true
        fi
        echo -e "  ${DIM}[$install_type]${NC} $profile_name"
        "$callback" "$profile_dir" "$@"
    done < <(find_browser_profiles "$browser_key")

    [[ "$found" == "true" ]]
}

# ---- Main ----

main() {
    check_version_flag "$@"

    local command=""

    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            apply|show|status|revert) command="$arg" ;;
            --standard) LEVEL="standard" ;;
            --strict)   LEVEL="strict" ;;
            --paranoid)  LEVEL="paranoid" ;;
            --no-backup) BACKUP=false ;;
            -n|--dry-run) DRY_RUN=true; export DRY_RUN ;;
            -y|--yes)    AUTO_YES=true; export AUTO_YES ;;
            -V|--version) show_version; exit 0 ;;
            -h|--help)   show_help; exit 0 ;;
        esac
    done

    # Parse --browser and --profile
    local prev=""
    for arg in "$@"; do
        if [[ "$prev" == "--browser" ]]; then
            TARGET_BROWSER=$(resolve_browser_key "$arg")
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
            while IFS= read -r browser_key; do
                for_each_profile "$browser_key" apply_to_profile "$LEVEL" && ((applied++))
            done < <(get_target_browsers)

            echo ""
            if [[ "$applied" -eq 0 ]]; then
                warn "No matching profiles found"
            else
                success "Applied settings to browser(s)"
                echo -e "\n${DIM}Restart your browser for settings to take effect.${NC}"
            fi
            ;;
        status)
            header "Privacy Status"
            while IFS= read -r browser_key; do
                for_each_profile "$browser_key" show_profile_status || true
            done < <(get_target_browsers)
            ;;
        revert)
            header "Reverting Privacy Hardening"

            if [[ "$AUTO_YES" != "true" && "$DRY_RUN" != "true" ]]; then
                confirm "Revert privacy settings (restore original user.js)?" || { info "Cancelled."; exit 0; }
            fi

            while IFS= read -r browser_key; do
                for_each_profile "$browser_key" revert_profile || true
            done < <(get_target_browsers)

            echo -e "\n${DIM}Restart your browser for changes to take effect.${NC}"
            ;;
        *)
            show_help
            exit 0
            ;;
    esac
}

main "$@"