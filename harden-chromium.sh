#!/usr/bin/env bash
# harden-chromium.sh - Privacy hardening for Chromium-based browsers via policy files
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools
#
# Applies privacy policies to Chrome, Chromium, Brave, Vivaldi, and Opera
# via JSON policy files. These take effect on next browser launch.
#
# Policy locations:
#   System-wide: /etc/<browser>/policies/managed/
#   Per-user:    ~/.config/<browser>/policies/managed/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/paths.sh"
source "$SCRIPT_DIR/lib/config.sh"

POLICY_FILENAME="browser-cleanup-tools-privacy.json"

show_help() {
    cat << EOF
Chromium Privacy Hardening

Applies privacy policies to Chromium-based browsers via JSON policy files.
These are enforced on browser launch and cannot be overridden by the user.

Usage: $(basename "$0") <COMMAND> [OPTIONS]

Commands:
  apply                 Apply privacy hardening policies
  show                  Display the policy that would be applied
  status                Check current policy status
  revert                Remove applied policies

Levels:
  --standard            Minimal breakage (default): disable telemetry, block 3rd-party cookies,
                        disable autofill, enforce Safe Browsing
  --strict              May break some sites: disable all cookies except session,
                        restrict WebRTC, disable prediction services, block ads
  --paranoid            Maximum privacy: disable JavaScript JIT, block all cookies,
                        disable WebRTC entirely, disable Safe Browsing remote checks

Options:
  --browser <name>      Target specific browser (chromium, brave, chrome, vivaldi, opera)
  --user-only           Install policies in user directory (no sudo required)
  --system              Install system-wide policies (requires sudo)
  -y, --yes             Auto-confirm all prompts
  -n, --dry-run         Show what would be done
  -V, --version         Show version
  -h, --help            Show this help

Examples:
  $(basename "$0") apply --standard
  $(basename "$0") apply --strict --browser brave --user-only
  $(basename "$0") status
  $(basename "$0") revert --browser chrome
EOF
}

# ===========================================================================
# POLICY GENERATION
# ===========================================================================

generate_policy_json() {
    local level="${1:-standard}"

    case "$level" in
        standard)
            cat << 'POLICY'
{
    "_comment": "Browser Cleanup Tools - Standard Privacy Hardening",
    "_level": "standard",

    "MetricsReportingEnabled": false,
    "SpellCheckServiceEnabled": false,

    "BlockThirdPartyCookies": true,

    "AutofillAddressEnabled": false,
    "AutofillCreditCardEnabled": false,
    "PasswordManagerEnabled": true,

    "SafeBrowsingEnabled": true,
    "SafeBrowsingProtectionLevel": 1,
    "SafeBrowsingExtendedReportingEnabled": false,

    "SearchSuggestEnabled": true,
    "UrlKeyedAnonymizedDataCollectionEnabled": false,
    "WebRtcEventLogCollectionAllowed": false,

    "TranslateEnabled": true,

    "HttpsOnlyMode": "force_enabled",
    "DefaultInsecureContentSetting": 2,

    "BackgroundModeEnabled": false,
    "HardwareAccelerationModeEnabled": true,

    "BrowserSignin": 0,
    "SyncDisabled": false,

    "DefaultNotificationsSetting": 2,
    "DefaultGeolocationSetting": 2,

    "PromotionalTabsEnabled": false,
    "ShowHomeButton": true,
    "HomepageIsNewTabPage": true,

    "CloudPrintSubmitEnabled": false,

    "MediaRouterCastAllowAllIPs": false,

    "PaymentMethodQueryEnabled": false,

    "SideSearchEnabled": false,
    "ShoppingListEnabled": false
}
POLICY
            ;;
        strict)
            cat << 'POLICY'
{
    "_comment": "Browser Cleanup Tools - Strict Privacy Hardening",
    "_level": "strict",

    "MetricsReportingEnabled": false,
    "SpellCheckServiceEnabled": false,

    "BlockThirdPartyCookies": true,
    "DefaultCookiesSetting": 4,
    "CookiesSessionOnlyForUrls": ["[*.]"],

    "AutofillAddressEnabled": false,
    "AutofillCreditCardEnabled": false,
    "PasswordManagerEnabled": false,
    "PasswordLeakDetectionEnabled": false,

    "SafeBrowsingEnabled": true,
    "SafeBrowsingProtectionLevel": 1,
    "SafeBrowsingExtendedReportingEnabled": false,

    "SearchSuggestEnabled": false,
    "UrlKeyedAnonymizedDataCollectionEnabled": false,
    "WebRtcEventLogCollectionAllowed": false,

    "TranslateEnabled": false,

    "HttpsOnlyMode": "force_enabled",
    "DefaultInsecureContentSetting": 2,

    "BackgroundModeEnabled": false,

    "BrowserSignin": 0,
    "SyncDisabled": true,

    "DefaultNotificationsSetting": 2,
    "DefaultGeolocationSetting": 2,
    "DefaultSensorsSetting": 2,

    "WebRtcIPHandling": "default_public_interface_only",
    "WebRtcUdpPortRange": "10000-10010",

    "NetworkPredictionOptions": 2,

    "DnsOverHttpsMode": "automatic",

    "PromotionalTabsEnabled": false,
    "ShowHomeButton": true,

    "CloudPrintSubmitEnabled": false,
    "PrintingEnabled": true,

    "MediaRouterCastAllowAllIPs": false,

    "PaymentMethodQueryEnabled": false,

    "DefaultPopupsSetting": 2,
    "AdsSettingForIntrusiveAdsSites": 2,

    "SideSearchEnabled": false,
    "ShoppingListEnabled": false,

    "ClearBrowsingDataOnExitList": ["cached_images_and_files", "download_history", "autofill"],

    "AudioCaptureAllowed": false,
    "VideoCaptureAllowed": false,

    "AbusiveExperienceInterventionEnforce": true,

    "BuiltInDnsClientEnabled": true
}
POLICY
            ;;
        paranoid)
            cat << 'POLICY'
{
    "_comment": "Browser Cleanup Tools - Paranoid Privacy Hardening",
    "_level": "paranoid",

    "MetricsReportingEnabled": false,
    "SpellCheckServiceEnabled": false,

    "BlockThirdPartyCookies": true,
    "DefaultCookiesSetting": 2,

    "AutofillAddressEnabled": false,
    "AutofillCreditCardEnabled": false,
    "PasswordManagerEnabled": false,
    "PasswordLeakDetectionEnabled": false,

    "SafeBrowsingEnabled": false,
    "SafeBrowsingProtectionLevel": 0,
    "SafeBrowsingExtendedReportingEnabled": false,

    "SearchSuggestEnabled": false,
    "UrlKeyedAnonymizedDataCollectionEnabled": false,
    "WebRtcEventLogCollectionAllowed": false,

    "TranslateEnabled": false,

    "HttpsOnlyMode": "force_enabled",
    "DefaultInsecureContentSetting": 2,

    "BackgroundModeEnabled": false,

    "BrowserSignin": 0,
    "SyncDisabled": true,

    "DefaultNotificationsSetting": 2,
    "DefaultGeolocationSetting": 2,
    "DefaultSensorsSetting": 2,
    "DefaultSerialGuardSetting": 2,
    "DefaultWebBluetoothGuardSetting": 2,
    "DefaultWebUsbGuardSetting": 2,
    "DefaultFileSystemReadGuardSetting": 2,
    "DefaultFileSystemWriteGuardSetting": 2,

    "WebRtcIPHandling": "disable_non_proxied_udp",
    "WebRtcUdpPortRange": "10000-10010",

    "NetworkPredictionOptions": 2,

    "DnsOverHttpsMode": "automatic",

    "PromotionalTabsEnabled": false,

    "CloudPrintSubmitEnabled": false,

    "MediaRouterCastAllowAllIPs": false,
    "EnableMediaRouter": false,

    "PaymentMethodQueryEnabled": false,

    "DefaultPopupsSetting": 2,
    "AdsSettingForIntrusiveAdsSites": 2,

    "SideSearchEnabled": false,
    "ShoppingListEnabled": false,

    "ClearBrowsingDataOnExitList": ["browsing_history", "cached_images_and_files", "cookies_and_other_site_data", "download_history", "autofill", "site_settings", "hosted_app_data", "password_signin"],

    "AudioCaptureAllowed": false,
    "VideoCaptureAllowed": false,

    "AbusiveExperienceInterventionEnforce": true,

    "BuiltInDnsClientEnabled": true,

    "DefaultJavaScriptJitSetting": 2,

    "FetchKeepaliveDurationSecondsOnShutdown": 0,

    "ImportAutofillFormData": false,
    "ImportBookmarks": false,
    "ImportHistory": false,
    "ImportSavedPasswords": false,
    "ImportSearchEngine": false,

    "BrowserNetworkTimeQueriesEnabled": false,

    "PrivacySandboxAdMeasurementEnabled": false,
    "PrivacySandboxAdTopicsEnabled": false,
    "PrivacySandboxSiteEnabledAdsEnabled": false,
    "PrivacySandboxPromptEnabled": false
}
POLICY
            ;;
    esac
}

# ===========================================================================
# COMMANDS
# ===========================================================================

do_apply() {
    local level="$1"
    local target_browser="$2"
    local user_only="$3"

    local browsers=()
    if [[ -n "$target_browser" ]]; then
        browsers=("$target_browser")
    else
        browsers=("${CHROMIUM_BROWSERS[@]}")
    fi

    local policy_content
    policy_content=$(generate_policy_json "$level")

    for browser in "${browsers[@]}"; do
        local display_name
        display_name=$(get_display_name "$browser")

        # Check if browser is installed
        local has_install=false
        local profiles_var="${browser}_PROFILES"
        local -n profiles_ref="$profiles_var"
        for install_type in "${!profiles_ref[@]}"; do
            [[ -d "${profiles_ref[$install_type]}" ]] && { has_install=true; break; }
        done
        $has_install || continue

        info "Applying $level privacy hardening to $display_name..."

        local policy_dir=""
        if [[ "$user_only" == "true" ]]; then
            policy_dir=$(get_user_policy_dir "$browser")
        else
            policy_dir=$(get_policy_dir "$browser")
        fi

        [[ -z "$policy_dir" ]] && { warn "No policy directory known for $display_name"; continue; }

        if [[ "$DRY_RUN" == "true" ]]; then
            dry_run "Would write policy to: $policy_dir/$POLICY_FILENAME"
            continue
        fi

        if [[ "$user_only" == "true" ]]; then
            mkdir -p "$policy_dir"
        else
            if [[ ! -d "$policy_dir" ]]; then
                sudo mkdir -p "$policy_dir" || { error "Cannot create $policy_dir (try --user-only)"; continue; }
            fi
        fi

        if [[ "$user_only" == "true" ]]; then
            echo "$policy_content" > "$policy_dir/$POLICY_FILENAME"
        else
            echo "$policy_content" | sudo tee "$policy_dir/$POLICY_FILENAME" > /dev/null || {
                error "Cannot write to $policy_dir (try --user-only)"
                continue
            }
        fi

        success "Applied $level privacy policy to $display_name"
        info "  Policy file: $policy_dir/$POLICY_FILENAME"
        log_info "Applied $level Chromium privacy policy to $display_name"
    done
}

do_show() {
    local level="$1"
    header "Chromium Privacy Policy ($level level)"
    generate_policy_json "$level"
}

do_status() {
    local target_browser="$1"

    local browsers=()
    if [[ -n "$target_browser" ]]; then
        browsers=("$target_browser")
    else
        browsers=("${CHROMIUM_BROWSERS[@]}")
    fi

    header "Chromium Privacy Hardening Status"

    for browser in "${browsers[@]}"; do
        local display_name
        display_name=$(get_display_name "$browser")

        # Check if installed
        local has_install=false
        local profiles_var="${browser}_PROFILES"
        local -n profiles_ref="$profiles_var"
        for install_type in "${!profiles_ref[@]}"; do
            [[ -d "${profiles_ref[$install_type]}" ]] && { has_install=true; break; }
        done
        $has_install || continue

        echo -e "${BOLD}$display_name:${NC}"

        # Check system policy
        local sys_dir
        sys_dir=$(get_policy_dir "$browser")
        if [[ -n "$sys_dir" && -f "$sys_dir/$POLICY_FILENAME" ]]; then
            local level
            level=$(grep -o '"_level": *"[^"]*"' "$sys_dir/$POLICY_FILENAME" 2>/dev/null | cut -d'"' -f4)
            echo -e "  System policy: ${GREEN}Active${NC} (${level:-unknown} level)"
        else
            echo -e "  System policy: ${DIM}Not applied${NC}"
        fi

        # Check user policy
        local user_dir
        user_dir=$(get_user_policy_dir "$browser")
        if [[ -n "$user_dir" && -f "$user_dir/$POLICY_FILENAME" ]]; then
            local level
            level=$(grep -o '"_level": *"[^"]*"' "$user_dir/$POLICY_FILENAME" 2>/dev/null | cut -d'"' -f4)
            echo -e "  User policy:   ${GREEN}Active${NC} (${level:-unknown} level)"
        else
            echo -e "  User policy:   ${DIM}Not applied${NC}"
        fi

        # Check chrome://policy status hint
        echo -e "  ${DIM}Verify at: chrome://policy in $display_name${NC}"
        echo ""
    done
}

do_revert() {
    local target_browser="$1"
    local user_only="$2"

    local browsers=()
    if [[ -n "$target_browser" ]]; then
        browsers=("$target_browser")
    else
        browsers=("${CHROMIUM_BROWSERS[@]}")
    fi

    for browser in "${browsers[@]}"; do
        local display_name
        display_name=$(get_display_name "$browser")
        local removed=false

        # Remove user policy
        local user_dir
        user_dir=$(get_user_policy_dir "$browser")
        if [[ -n "$user_dir" && -f "$user_dir/$POLICY_FILENAME" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                dry_run "Would remove: $user_dir/$POLICY_FILENAME"
            else
                rm -f "$user_dir/$POLICY_FILENAME"
                success "Removed user policy for $display_name"
                removed=true
            fi
        fi

        # Remove system policy
        if [[ "$user_only" != "true" ]]; then
            local sys_dir
            sys_dir=$(get_policy_dir "$browser")
            if [[ -n "$sys_dir" && -f "$sys_dir/$POLICY_FILENAME" ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    dry_run "Would remove: $sys_dir/$POLICY_FILENAME"
                else
                    sudo rm -f "$sys_dir/$POLICY_FILENAME" 2>/dev/null && {
                        success "Removed system policy for $display_name"
                        removed=true
                    }
                fi
            fi
        fi

        $removed || info "No policies found for $display_name"
        log_info "Reverted Chromium privacy policy for $display_name"
    done
}

# ===========================================================================
# MAIN
# ===========================================================================

main() {
    check_version_flag "$@"

    local command="" level="$DEFAULT_PRIVACY_LEVEL" target_browser="" user_only="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            apply|show|status|revert) command="$1"; shift ;;
            --standard)  level="standard"; shift ;;
            --strict)    level="strict"; shift ;;
            --paranoid)  level="paranoid"; shift ;;
            --browser)   target_browser=$(resolve_browser "${2:-}" 2>/dev/null || echo "${2^^}"); shift 2 ;;
            --user-only) user_only="true"; shift ;;
            --system)    user_only="false"; shift ;;
            -y|--yes)    AUTO_YES=true; export AUTO_YES; shift ;;
            -n|--dry-run) DRY_RUN=true; export DRY_RUN; shift ;;
            -h|--help)   show_help; exit 0 ;;
            -V|--version) show_version; exit 0 ;;
            *) shift ;;
        esac
    done

    # Helper for browser name resolution from CLI
    resolve_browser_cli() {
        case "${1,,}" in
            chromium) echo "CHROMIUM" ;;
            brave)    echo "BRAVE" ;;
            chrome|google-chrome) echo "CHROME" ;;
            vivaldi)  echo "VIVALDI" ;;
            opera)    echo "OPERA" ;;
            *) echo "${1^^}" ;;
        esac
    }

    if [[ -n "$target_browser" ]]; then
        target_browser=$(resolve_browser_cli "$target_browser")
    fi

    case "$command" in
        apply)  do_apply "$level" "$target_browser" "$user_only" ;;
        show)   do_show "$level" ;;
        status) do_status "$target_browser" ;;
        revert) do_revert "$target_browser" "$user_only" ;;
        *)      show_help; exit 1 ;;
    esac
}

main "$@"
