#!/usr/bin/env bash
# audit-extensions.sh - Audit installed extensions across all browsers
# Lists extensions for Firefox, Floorp, Chromium, Brave, and Chrome
# Supports native, Flatpak, and Snap installations
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

declare -A CHROMIUM_PATHS=(
    [native]="$HOME/.config/chromium"
    [flatpak]="$HOME/.var/app/org.chromium.Chromium/config/chromium"
    [snap]="$HOME/snap/chromium/common/chromium"
)

declare -A BRAVE_PATHS=(
    [native]="$HOME/.config/BraveSoftware/Brave-Browser"
    [flatpak]="$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser"
    [snap]="$HOME/snap/brave/common/.config/BraveSoftware/Brave-Browser"
)

declare -A CHROME_PATHS=(
    [native]="$HOME/.config/google-chrome"
)

# Output format
OUTPUT_FORMAT="text"
SHOW_DETAILS=false

show_help() {
    cat <<EOF
${BOLD}Browser Extension Audit Tool${NC}

Lists installed extensions across all supported browsers. Identifies
extension names, IDs, versions, and status.

Usage: $(basename "$0") [OPTIONS]

Options:
  --json            Output report as JSON
  --csv             Output report as CSV
  --details         Show extended details (permissions, update URL)
  --browser <name>  Only audit a specific browser
                    (firefox, floorp, chromium, brave, chrome)
  -h, --help        Show this help message

Examples:
  $(basename "$0")                         # Audit all browsers
  $(basename "$0") --json                  # JSON output
  $(basename "$0") --browser firefox       # Only Firefox
  $(basename "$0") --details               # Show permissions

EOF
}

# ---- Mozilla extension parsing ----
# Mozilla browsers store extensions in extensions.json within each profile

audit_mozilla_profile() {
    local profile_dir="$1"
    local app_name="$2"
    local install_type="$3"
    local profile_name
    profile_name=$(basename "$profile_dir")

    local extensions_file="$profile_dir/extensions.json"
    if [[ ! -f "$extensions_file" ]]; then
        return
    fi

    # Check if python3 or jq is available for JSON parsing
    if command -v python3 &>/dev/null; then
        python3 -c "
import json, sys

with open('$extensions_file', 'r') as f:
    data = json.load(f)

addons = data.get('addons', [])
for addon in addons:
    ext_id = addon.get('id', 'unknown')
    name = addon.get('defaultLocale', {}).get('name', addon.get('name', 'Unknown'))
    version = addon.get('version', '?')
    ext_type = addon.get('type', '?')
    active = addon.get('active', False)
    # Skip built-in/system addons
    location = addon.get('location', '')
    if location in ('app-builtin', 'app-system-defaults'):
        continue
    status = 'enabled' if active else 'disabled'
    creator = addon.get('defaultLocale', {}).get('creator', addon.get('creator', ''))
    if isinstance(creator, dict):
        creator = creator.get('name', '')
    homepage = addon.get('defaultLocale', {}).get('homepageURL', addon.get('homepageURL', ''))
    permissions_list = addon.get('userPermissions', {}).get('permissions', []) if addon.get('userPermissions') else []
    permissions = ', '.join(permissions_list) if permissions_list else 'none'
    print(f'EXT|{ext_id}|{name}|{version}|{ext_type}|{status}|{creator}|{homepage}|{permissions}')
" 2>/dev/null
    elif command -v jq &>/dev/null; then
        jq -r '
            .addons[]
            | select(.location != "app-builtin" and .location != "app-system-defaults")
            | "EXT|\(.id)|\(.defaultLocale.name // .name // "Unknown")|\(.version // "?")|\(.type // "?")|\(if .active then "enabled" else "disabled" end)|\(.defaultLocale.creator // .creator // "")|\(.defaultLocale.homepageURL // .homepageURL // "")|\((.userPermissions.permissions // []) | join(", "))"
        ' "$extensions_file" 2>/dev/null
    else
        # Fallback: basic grep parsing
        grep -oP '"id"\s*:\s*"[^"]*"' "$extensions_file" 2>/dev/null | while read -r line; do
            local ext_id
            ext_id=$(echo "$line" | grep -oP '"id"\s*:\s*"\K[^"]*')
            echo "EXT|$ext_id|Unknown|?|?|?|||"
        done
    fi
}

audit_mozilla_browser() {
    local -n path_map=$1
    local app_name="$2"
    local ext_count=0
    local found_any=false

    for install_type in "${!path_map[@]}"; do
        local base_dir="${path_map[$install_type]}"
        [[ ! -d "$base_dir" ]] && continue

        # Find profile directories via profiles.ini
        local profiles_ini="$base_dir/profiles.ini"
        local profile_dirs=()

        if [[ -f "$profiles_ini" ]]; then
            while IFS= read -r line; do
                if [[ "$line" =~ ^Path= ]]; then
                    local rel_path="${line#Path=}"
                    if [[ "$rel_path" == /* ]]; then
                        profile_dirs+=("$rel_path")
                    else
                        profile_dirs+=("$base_dir/$rel_path")
                    fi
                fi
            done < "$profiles_ini"
        fi

        # Also scan for any directory with extensions.json
        while IFS= read -r -d '' pdir; do
            local already=false
            for existing in "${profile_dirs[@]}"; do
                [[ "$(dirname "$pdir")" == "$existing" ]] && already=true
            done
            if [[ "$already" == "false" ]]; then
                profile_dirs+=("$(dirname "$pdir")")
            fi
        done < <(find "$base_dir" -maxdepth 2 -name "extensions.json" -print0 2>/dev/null)

        for profile_dir in "${profile_dirs[@]}"; do
            [[ ! -d "$profile_dir" ]] && continue
            local profile_name
            profile_name=$(basename "$profile_dir")

            local extensions
            extensions=$(audit_mozilla_profile "$profile_dir" "$app_name" "$install_type")
            [[ -z "$extensions" ]] && continue

            found_any=true

            if [[ "$OUTPUT_FORMAT" == "text" ]]; then
                echo -e "  ${DIM}[$install_type] Profile: $profile_name${NC}"
            fi

            while IFS='|' read -r _ ext_id name version ext_type status creator homepage permissions; do
                ((ext_count++))
                case "$OUTPUT_FORMAT" in
                    text)
                        local status_color="$GREEN"
                        [[ "$status" == "disabled" ]] && status_color="$DIM"
                        echo -e "    ${status_color}${name}${NC} v${version} ${DIM}(${ext_id})${NC} [${status}]"
                        if [[ "$SHOW_DETAILS" == "true" ]]; then
                            [[ -n "$creator" ]] && echo -e "      ${DIM}Author: $creator${NC}"
                            [[ -n "$homepage" ]] && echo -e "      ${DIM}URL: $homepage${NC}"
                            [[ -n "$permissions" && "$permissions" != "none" ]] && echo -e "      ${DIM}Permissions: $permissions${NC}"
                        fi
                        ;;
                    json)
                        echo "{\"browser\":\"$app_name\",\"install\":\"$install_type\",\"profile\":\"$profile_name\",\"id\":\"$ext_id\",\"name\":\"$(echo "$name" | sed 's/"/\\"/g')\",\"version\":\"$version\",\"type\":\"$ext_type\",\"status\":\"$status\",\"creator\":\"$(echo "$creator" | sed 's/"/\\"/g')\",\"homepage\":\"$(echo "$homepage" | sed 's/"/\\"/g')\",\"permissions\":\"$(echo "$permissions" | sed 's/"/\\"/g')\"}"
                        ;;
                    csv)
                        echo "\"$app_name\",\"$install_type\",\"$profile_name\",\"$ext_id\",\"$(echo "$name" | sed 's/"/""/g')\",\"$version\",\"$ext_type\",\"$status\",\"$(echo "$creator" | sed 's/"/""/g')\",\"$(echo "$homepage" | sed 's/"/""/g')\""
                        ;;
                esac
            done <<< "$extensions"
        done
    done

    if [[ "$found_any" == "false" && "$OUTPUT_FORMAT" == "text" ]]; then
        echo -e "  ${DIM}No extensions found or not installed${NC}"
    fi

    return 0
}

# ---- Chromium extension parsing ----
# Chromium-based browsers store extensions in <profile>/Extensions/<ext_id>/<version>/manifest.json

audit_chromium_profile() {
    local profile_dir="$1"
    local app_name="$2"
    local install_type="$3"
    local profile_name
    profile_name=$(basename "$profile_dir")

    local extensions_dir="$profile_dir/Extensions"
    [[ ! -d "$extensions_dir" ]] && return

    local preferences_file="$profile_dir/Preferences"
    local secure_prefs="$profile_dir/Secure Preferences"

    for ext_dir in "$extensions_dir"/*/; do
        [[ ! -d "$ext_dir" ]] && continue
        local ext_id
        ext_id=$(basename "$ext_dir")

        # Skip Chrome's built-in extensions
        [[ "$ext_id" == "Temp" ]] && continue

        # Find the latest version directory
        local latest_version_dir=""
        for ver_dir in "$ext_dir"/*/; do
            [[ -d "$ver_dir" ]] && latest_version_dir="$ver_dir"
        done
        [[ -z "$latest_version_dir" ]] && continue

        local manifest="$latest_version_dir/manifest.json"
        [[ ! -f "$manifest" ]] && continue

        local name version permissions
        if command -v python3 &>/dev/null; then
            read -r name version permissions < <(python3 -c "
import json
with open('$manifest', 'r') as f:
    data = json.load(f)
name = data.get('name', 'Unknown')
# Resolve __MSG_ references
if name.startswith('__MSG_'):
    name = name.strip('_').replace('MSG_', '')
version = data.get('version', '?')
perms = data.get('permissions', [])
perms = [str(p) for p in perms if isinstance(p, str)]
print(f'{name}\t{version}\t{\", \".join(perms[:10]) if perms else \"none\"}')
" 2>/dev/null) || continue
        elif command -v jq &>/dev/null; then
            name=$(jq -r '.name // "Unknown"' "$manifest" 2>/dev/null)
            version=$(jq -r '.version // "?"' "$manifest" 2>/dev/null)
            permissions=$(jq -r '(.permissions // [])[:10] | join(", ")' "$manifest" 2>/dev/null)
            [[ -z "$permissions" ]] && permissions="none"
        else
            name="Unknown"
            version="?"
            permissions="?"
        fi

        # Try to get the real extension name from Preferences
        local real_name=""
        if [[ -f "$secure_prefs" ]] && command -v python3 &>/dev/null; then
            real_name=$(python3 -c "
import json
try:
    with open('$secure_prefs', 'r') as f:
        data = json.load(f)
    settings = data.get('extensions', {}).get('settings', {})
    ext = settings.get('$ext_id', {})
    mf = ext.get('manifest', {})
    name = mf.get('name', '')
    if name and not name.startswith('__MSG_'):
        print(name)
except:
    pass
" 2>/dev/null)
        fi
        [[ -n "$real_name" ]] && name="$real_name"

        # Determine if extension is enabled
        local status="enabled"
        if [[ -f "$preferences_file" ]] && command -v python3 &>/dev/null; then
            status=$(python3 -c "
import json
try:
    with open('$preferences_file', 'r') as f:
        data = json.load(f)
    settings = data.get('extensions', {}).get('settings', {})
    ext = settings.get('$ext_id', {})
    state = ext.get('state', 1)
    print('enabled' if state == 1 else 'disabled')
except:
    print('unknown')
" 2>/dev/null)
        fi

        echo "EXT|$ext_id|$name|$version|extension|$status|||$permissions"
    done
}

audit_chromium_browser() {
    local -n path_map=$1
    local app_name="$2"
    local found_any=false

    for install_type in "${!path_map[@]}"; do
        local base_dir="${path_map[$install_type]}"
        [[ ! -d "$base_dir" ]] && continue

        # Scan Default and Profile* directories
        local profiles=()
        for p in "$base_dir"/Default "$base_dir"/Profile\ *; do
            [[ -d "$p" ]] && profiles+=("$p")
        done
        [[ ${#profiles[@]} -eq 0 ]] && continue

        for profile_dir in "${profiles[@]}"; do
            local profile_name
            profile_name=$(basename "$profile_dir")

            local extensions
            extensions=$(audit_chromium_profile "$profile_dir" "$app_name" "$install_type")
            [[ -z "$extensions" ]] && continue

            found_any=true

            if [[ "$OUTPUT_FORMAT" == "text" ]]; then
                echo -e "  ${DIM}[$install_type] Profile: $profile_name${NC}"
            fi

            while IFS='|' read -r _ ext_id name version ext_type status creator homepage permissions; do
                case "$OUTPUT_FORMAT" in
                    text)
                        local status_color="$GREEN"
                        [[ "$status" == "disabled" ]] && status_color="$DIM"
                        echo -e "    ${status_color}${name}${NC} v${version} ${DIM}(${ext_id})${NC} [${status}]"
                        if [[ "$SHOW_DETAILS" == "true" ]]; then
                            [[ -n "$permissions" && "$permissions" != "none" ]] && echo -e "      ${DIM}Permissions: $permissions${NC}"
                        fi
                        ;;
                    json)
                        echo "{\"browser\":\"$app_name\",\"install\":\"$install_type\",\"profile\":\"$profile_name\",\"id\":\"$ext_id\",\"name\":\"$(echo "$name" | sed 's/"/\\"/g')\",\"version\":\"$version\",\"type\":\"$ext_type\",\"status\":\"$status\",\"permissions\":\"$(echo "$permissions" | sed 's/"/\\"/g')\"}"
                        ;;
                    csv)
                        echo "\"$app_name\",\"$install_type\",\"$profile_name\",\"$ext_id\",\"$(echo "$name" | sed 's/"/""/g')\",\"$version\",\"$ext_type\",\"$status\",\"\",\"\""
                        ;;
                esac
            done <<< "$extensions"
        done
    done

    if [[ "$found_any" == "false" && "$OUTPUT_FORMAT" == "text" ]]; then
        echo -e "  ${DIM}No extensions found or not installed${NC}"
    fi
}

# ---- Main ----

main() {
    local target_browser=""

    for arg in "$@"; do
        case "$arg" in
            --json)    OUTPUT_FORMAT="json" ;;
            --csv)     OUTPUT_FORMAT="csv" ;;
            --details) SHOW_DETAILS=true ;;
            -h|--help) show_help; exit 0 ;;
        esac
    done

    # Parse --browser
    local prev=""
    for arg in "$@"; do
        if [[ "$prev" == "--browser" ]]; then
            target_browser="$arg"
        fi
        prev="$arg"
    done

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "["
        local first=true
    elif [[ "$OUTPUT_FORMAT" == "csv" ]]; then
        echo "\"Browser\",\"Install Type\",\"Profile\",\"Extension ID\",\"Name\",\"Version\",\"Type\",\"Status\",\"Creator\",\"Homepage\""
    else
        header "Browser Extension Audit"
        echo -e "Scanning all browser installations for extensions...\n"
    fi

    local json_entries=()

    # --- Firefox ---
    if [[ -z "$target_browser" || "$target_browser" == "firefox" ]]; then
        [[ "$OUTPUT_FORMAT" == "text" ]] && echo -e "${BOLD}Firefox${NC}"
        local output
        output=$(audit_mozilla_browser FIREFOX_PATHS "Firefox")
        if [[ "$OUTPUT_FORMAT" == "json" ]]; then
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                json_entries+=("$line")
            done <<< "$output"
        else
            echo "$output"
        fi
        [[ "$OUTPUT_FORMAT" == "text" ]] && echo ""
    fi

    # --- Floorp ---
    if [[ -z "$target_browser" || "$target_browser" == "floorp" ]]; then
        [[ "$OUTPUT_FORMAT" == "text" ]] && echo -e "${BOLD}Floorp${NC}"
        local output
        output=$(audit_mozilla_browser FLOORP_PATHS "Floorp")
        if [[ "$OUTPUT_FORMAT" == "json" ]]; then
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                json_entries+=("$line")
            done <<< "$output"
        else
            echo "$output"
        fi
        [[ "$OUTPUT_FORMAT" == "text" ]] && echo ""
    fi

    # --- Chromium ---
    if [[ -z "$target_browser" || "$target_browser" == "chromium" ]]; then
        [[ "$OUTPUT_FORMAT" == "text" ]] && echo -e "${BOLD}Chromium${NC}"
        local output
        output=$(audit_chromium_browser CHROMIUM_PATHS "Chromium")
        if [[ "$OUTPUT_FORMAT" == "json" ]]; then
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                json_entries+=("$line")
            done <<< "$output"
        else
            echo "$output"
        fi
        [[ "$OUTPUT_FORMAT" == "text" ]] && echo ""
    fi

    # --- Brave ---
    if [[ -z "$target_browser" || "$target_browser" == "brave" ]]; then
        [[ "$OUTPUT_FORMAT" == "text" ]] && echo -e "${BOLD}Brave${NC}"
        local output
        output=$(audit_chromium_browser BRAVE_PATHS "Brave")
        if [[ "$OUTPUT_FORMAT" == "json" ]]; then
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                json_entries+=("$line")
            done <<< "$output"
        else
            echo "$output"
        fi
        [[ "$OUTPUT_FORMAT" == "text" ]] && echo ""
    fi

    # --- Chrome ---
    if [[ -z "$target_browser" || "$target_browser" == "chrome" ]]; then
        [[ "$OUTPUT_FORMAT" == "text" ]] && echo -e "${BOLD}Google Chrome${NC}"
        local output
        output=$(audit_chromium_browser CHROME_PATHS "Chrome")
        if [[ "$OUTPUT_FORMAT" == "json" ]]; then
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                json_entries+=("$line")
            done <<< "$output"
        else
            echo "$output"
        fi
        [[ "$OUTPUT_FORMAT" == "text" ]] && echo ""
    fi

    # JSON output
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        local total=${#json_entries[@]}
        for i in "${!json_entries[@]}"; do
            if [[ $i -lt $((total - 1)) ]]; then
                echo "  ${json_entries[$i]},"
            else
                echo "  ${json_entries[$i]}"
            fi
        done
        echo "]"
    fi

    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        echo -e "${DIM}Tip: Use --details for permissions, --json for machine-readable output${NC}"
    fi
}

main "$@"
