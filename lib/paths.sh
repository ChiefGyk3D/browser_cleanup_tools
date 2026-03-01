#!/usr/bin/env bash
# paths.sh - Centralized browser path definitions for Browser Cleanup Tools
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools
#
# All browser profile/cache paths are defined here to avoid duplication
# across scripts. Each browser has an associative array of install types
# mapping to their profile and cache directories.

# Prevent double-sourcing
[[ -n "${_PATHS_SH_LOADED:-}" ]] && return 0
_PATHS_SH_LOADED=1

# ===========================================================================
# MOZILLA-BASED BROWSERS
# ===========================================================================

# --- Firefox ---
declare -gA FIREFOX_PROFILES=(
    [native]="$HOME/.mozilla/firefox"
    [flatpak]="$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
    [snap]="$HOME/snap/firefox/common/.mozilla/firefox"
)
declare -gA FIREFOX_CACHE=(
    [native]="$HOME/.cache/mozilla/firefox"
    [flatpak]="$HOME/.var/app/org.mozilla.firefox/cache/mozilla/firefox"
    [snap]="$HOME/snap/firefox/common/.cache/mozilla/firefox"
)
declare -g FIREFOX_FLATPAK_ID="org.mozilla.firefox"
declare -g FIREFOX_SNAP_NAME="firefox"
declare -g FIREFOX_PROCESS_NAMES="firefox firefox-esr"

# --- Floorp ---
declare -gA FLOORP_PROFILES=(
    [native]="$HOME/.floorp"
    [flatpak]="$HOME/.var/app/one.ablaze.floorp/.floorp"
)
declare -gA FLOORP_CACHE=(
    [native]="$HOME/.cache/floorp"
    [flatpak]="$HOME/.var/app/one.ablaze.floorp/cache/floorp"
)
declare -g FLOORP_FLATPAK_ID="one.ablaze.floorp"
declare -g FLOORP_SNAP_NAME=""
declare -g FLOORP_PROCESS_NAMES="floorp"

# --- LibreWolf ---
declare -gA LIBREWOLF_PROFILES=(
    [native]="$HOME/.librewolf"
    [flatpak]="$HOME/.var/app/io.gitlab.librewolf-community/.librewolf"
)
declare -gA LIBREWOLF_CACHE=(
    [native]="$HOME/.cache/librewolf"
    [flatpak]="$HOME/.var/app/io.gitlab.librewolf-community/cache/librewolf"
)
declare -g LIBREWOLF_FLATPAK_ID="io.gitlab.librewolf-community"
declare -g LIBREWOLF_SNAP_NAME=""
declare -g LIBREWOLF_PROCESS_NAMES="librewolf"

# --- Waterfox ---
declare -gA WATERFOX_PROFILES=(
    [native]="$HOME/.waterfox"
    [flatpak]="$HOME/.var/app/net.waterfox.waterfox/.waterfox"
)
declare -gA WATERFOX_CACHE=(
    [native]="$HOME/.cache/waterfox"
    [flatpak]="$HOME/.var/app/net.waterfox.waterfox/cache/waterfox"
)
declare -g WATERFOX_FLATPAK_ID="net.waterfox.waterfox"
declare -g WATERFOX_SNAP_NAME=""
declare -g WATERFOX_PROCESS_NAMES="waterfox"

# --- Zen Browser ---
declare -gA ZEN_PROFILES=(
    [native]="$HOME/.zen"
    [flatpak]="$HOME/.var/app/io.github.zen_browser.zen/.zen"
)
declare -gA ZEN_CACHE=(
    [native]="$HOME/.cache/zen"
    [flatpak]="$HOME/.var/app/io.github.zen_browser.zen/cache/zen"
)
declare -g ZEN_FLATPAK_ID="io.github.zen_browser.zen"
declare -g ZEN_SNAP_NAME=""
declare -g ZEN_PROCESS_NAMES="zen zen-browser"

# --- Tor Browser ---
declare -gA TOR_PROFILES=(
    [native]="$HOME/.local/share/torbrowser/tbb/x86_64/tor-browser/Browser/TorBrowser/Data/Browser/profile.default"
    [flatpak]="$HOME/.var/app/com.github.nickvergessen.TorBrowser/.local/share/torbrowser/tbb/x86_64/tor-browser/Browser/TorBrowser/Data/Browser/profile.default"
)
declare -gA TOR_CACHE=(
    [native]="$HOME/.local/share/torbrowser/tbb/x86_64/tor-browser/Browser/TorBrowser/Data/Browser/Caches"
    [flatpak]="$HOME/.var/app/com.github.nickvergessen.TorBrowser/cache"
)
declare -g TOR_FLATPAK_ID="com.github.nickvergessen.TorBrowser"
declare -g TOR_SNAP_NAME=""
declare -g TOR_PROCESS_NAMES="tor-browser firefox"

# --- Thunderbird ---
declare -gA THUNDERBIRD_PROFILES=(
    [native]="$HOME/.thunderbird"
    [flatpak]="$HOME/.var/app/org.mozilla.Thunderbird/.thunderbird"
    [snap]="$HOME/snap/thunderbird/common/.thunderbird"
)
declare -gA THUNDERBIRD_CACHE=(
    [native]="$HOME/.cache/thunderbird"
    [flatpak]="$HOME/.var/app/org.mozilla.Thunderbird/cache/thunderbird"
    [snap]="$HOME/snap/thunderbird/common/.cache/thunderbird"
)
declare -g THUNDERBIRD_FLATPAK_ID="org.mozilla.Thunderbird"
declare -g THUNDERBIRD_SNAP_NAME="thunderbird"
declare -g THUNDERBIRD_PROCESS_NAMES="thunderbird thunderbird-bin"

# ===========================================================================
# CHROMIUM-BASED BROWSERS
# ===========================================================================

# --- Chromium ---
declare -gA CHROMIUM_PROFILES=(
    [native]="$HOME/.config/chromium"
    [flatpak]="$HOME/.var/app/org.chromium.Chromium/config/chromium"
    [snap]="$HOME/snap/chromium/common/chromium"
)
declare -gA CHROMIUM_CACHE=(
    [native]="$HOME/.cache/chromium"
    [flatpak]="$HOME/.var/app/org.chromium.Chromium/cache/chromium"
    [snap]="$HOME/snap/chromium/common/.cache/chromium"
)
declare -g CHROMIUM_FLATPAK_ID="org.chromium.Chromium"
declare -g CHROMIUM_SNAP_NAME="chromium"
declare -g CHROMIUM_PROCESS_NAMES="chromium chromium-browser"
declare -g CHROMIUM_POLICY_DIR="/etc/chromium/policies/managed"
declare -g CHROMIUM_USER_POLICY_DIR="$HOME/.config/chromium/policies/managed"

# --- Brave ---
declare -gA BRAVE_PROFILES=(
    [native]="$HOME/.config/BraveSoftware/Brave-Browser"
    [flatpak]="$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser"
    [snap]="$HOME/snap/brave/current/.config/BraveSoftware/Brave-Browser"
)
declare -gA BRAVE_CACHE=(
    [native]="$HOME/.cache/BraveSoftware/Brave-Browser"
    [flatpak]="$HOME/.var/app/com.brave.Browser/cache/BraveSoftware/Brave-Browser"
    [snap]="$HOME/snap/brave/current/.cache/BraveSoftware/Brave-Browser"
)
declare -g BRAVE_FLATPAK_ID="com.brave.Browser"
declare -g BRAVE_SNAP_NAME="brave"
declare -g BRAVE_PROCESS_NAMES="brave brave-browser"
declare -g BRAVE_POLICY_DIR="/etc/brave/policies/managed"
declare -g BRAVE_USER_POLICY_DIR="$HOME/.config/BraveSoftware/Brave-Browser/policies/managed"

# --- Google Chrome ---
declare -gA CHROME_PROFILES=(
    [native]="$HOME/.config/google-chrome"
)
declare -gA CHROME_CACHE=(
    [native]="$HOME/.cache/google-chrome"
)
declare -g CHROME_FLATPAK_ID=""
declare -g CHROME_SNAP_NAME=""
declare -g CHROME_PROCESS_NAMES="chrome google-chrome google-chrome-stable"
declare -g CHROME_POLICY_DIR="/etc/opt/chrome/policies/managed"
declare -g CHROME_USER_POLICY_DIR="$HOME/.config/google-chrome/policies/managed"

# --- Vivaldi ---
declare -gA VIVALDI_PROFILES=(
    [native]="$HOME/.config/vivaldi"
    [flatpak]="$HOME/.var/app/com.vivaldi.Vivaldi/config/vivaldi"
)
declare -gA VIVALDI_CACHE=(
    [native]="$HOME/.cache/vivaldi"
    [flatpak]="$HOME/.var/app/com.vivaldi.Vivaldi/cache/vivaldi"
)
declare -g VIVALDI_FLATPAK_ID="com.vivaldi.Vivaldi"
declare -g VIVALDI_SNAP_NAME=""
declare -g VIVALDI_PROCESS_NAMES="vivaldi vivaldi-bin"
declare -g VIVALDI_POLICY_DIR="/etc/opt/vivaldi/policies/managed"
declare -g VIVALDI_USER_POLICY_DIR="$HOME/.config/vivaldi/policies/managed"

# --- Opera ---
declare -gA OPERA_PROFILES=(
    [native]="$HOME/.config/opera"
    [flatpak]="$HOME/.var/app/com.opera.Opera/config/opera"
)
declare -gA OPERA_CACHE=(
    [native]="$HOME/.cache/opera"
    [flatpak]="$HOME/.var/app/com.opera.Opera/cache/opera"
)
declare -g OPERA_FLATPAK_ID="com.opera.Opera"
declare -g OPERA_SNAP_NAME=""
declare -g OPERA_PROCESS_NAMES="opera"
declare -g OPERA_POLICY_DIR="/etc/opt/opera/policies/managed"
declare -g OPERA_USER_POLICY_DIR="$HOME/.config/opera/policies/managed"

# ===========================================================================
# BROWSER REGISTRY — maps browser names to their variable prefixes
# ===========================================================================

# All supported Mozilla-based browsers
declare -ga MOZILLA_BROWSERS=("FIREFOX" "FLOORP" "LIBREWOLF" "WATERFOX" "ZEN" "TOR")

# All supported Chromium-based browsers
declare -ga CHROMIUM_BROWSERS=("CHROMIUM" "BRAVE" "CHROME" "VIVALDI" "OPERA")

# All browsers (order matters for display)
declare -ga ALL_BROWSERS=("FIREFOX" "FLOORP" "LIBREWOLF" "WATERFOX" "ZEN" "TOR" "CHROMIUM" "BRAVE" "CHROME" "VIVALDI" "OPERA")

# Mail clients
declare -ga MAIL_CLIENTS=("THUNDERBIRD")

# Human-readable names
declare -gA BROWSER_DISPLAY_NAMES=(
    [FIREFOX]="Firefox"
    [FLOORP]="Floorp"
    [LIBREWOLF]="LibreWolf"
    [WATERFOX]="Waterfox"
    [ZEN]="Zen Browser"
    [TOR]="Tor Browser"
    [THUNDERBIRD]="Thunderbird"
    [CHROMIUM]="Chromium"
    [BRAVE]="Brave"
    [CHROME]="Google Chrome"
    [VIVALDI]="Vivaldi"
    [OPERA]="Opera"
)

# ===========================================================================
# HELPER FUNCTIONS
# ===========================================================================

# Get the profiles associative array name for a browser
# Usage: get_profiles_var "FIREFOX" => "FIREFOX_PROFILES"
get_profiles_var() { echo "${1}_PROFILES"; }
get_cache_var()    { echo "${1}_CACHE"; }

# Get profile path for a browser + install type
# Usage: get_profile_path "FIREFOX" "native"
get_profile_path() {
    local var="${1}_PROFILES"
    local -n ref="$var"
    echo "${ref[$2]:-}"
}

# Get cache path for a browser + install type
get_cache_path() {
    local var="${1}_CACHE"
    local -n ref="$var"
    echo "${ref[$2]:-}"
}

# Get flatpak ID for a browser
get_flatpak_id() {
    local var="${1}_FLATPAK_ID"
    echo "${!var:-}"
}

# Get snap name for a browser
get_snap_name() {
    local var="${1}_SNAP_NAME"
    echo "${!var:-}"
}

# Get process names for a browser
get_process_names() {
    local var="${1}_PROCESS_NAMES"
    echo "${!var:-}"
}

# Get display name for a browser
get_display_name() {
    echo "${BROWSER_DISPLAY_NAMES[$1]:-$1}"
}

# Get policy directory for Chromium-based browser
get_policy_dir() {
    local var="${1}_POLICY_DIR"
    echo "${!var:-}"
}

# Get user policy directory for Chromium-based browser
get_user_policy_dir() {
    local var="${1}_USER_POLICY_DIR"
    echo "${!var:-}"
}

# Check if a browser is Mozilla-based
is_mozilla_browser() {
    local browser="$1"
    for b in "${MOZILLA_BROWSERS[@]}"; do
        [[ "$b" == "$browser" ]] && return 0
    done
    return 1
}

# Check if a browser is Chromium-based
is_chromium_browser() {
    local browser="$1"
    for b in "${CHROMIUM_BROWSERS[@]}"; do
        [[ "$b" == "$browser" ]] && return 0
    done
    return 1
}

# Get available install types for a browser
# Returns space-separated list of available install types
get_available_installs() {
    local browser="$1"
    local filter="${2:-}" # optional: native-only, flatpak-only, snap-only
    local available=()
    local profiles_var="${browser}_PROFILES"
    local -n profiles_ref="$profiles_var"

    for install_type in "${!profiles_ref[@]}"; do
        # Apply filter
        case "$filter" in
            native-only)  [[ "$install_type" != "native" ]] && continue ;;
            flatpak-only) [[ "$install_type" != "flatpak" ]] && continue ;;
            snap-only)    [[ "$install_type" != "snap" ]] && continue ;;
        esac

        local path="${profiles_ref[$install_type]}"

        # Check if the path exists
        if [[ -d "$path" ]]; then
            available+=("$install_type")
            continue
        fi

        # For flatpak, check if app is installed even if profile dir doesn't exist yet
        if [[ "$install_type" == "flatpak" ]]; then
            local flatpak_id
            flatpak_id=$(get_flatpak_id "$browser")
            if [[ -n "$flatpak_id" ]] && flatpak_installed "$flatpak_id"; then
                available+=("$install_type")
                continue
            fi
        fi

        # For snap, check if snap is installed
        if [[ "$install_type" == "snap" ]]; then
            local snap_name
            snap_name=$(get_snap_name "$browser")
            if [[ -n "$snap_name" ]] && snap_installed "$snap_name"; then
                available+=("$install_type")
                continue
            fi
        fi
    done

    echo "${available[*]}"
}

# Check if any process for a browser is running
browser_is_running() {
    local browser="$1"
    local process_names
    process_names=$(get_process_names "$browser")
    for name in $process_names; do
        app_is_running "$name" && return 0
    done
    return 1
}
