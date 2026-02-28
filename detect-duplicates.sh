#!/usr/bin/env bash
# detect-duplicates.sh - Find duplicate data across browser profiles
# Identifies duplicate extensions, bookmarks, cache, and redundant profiles
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

OUTPUT_FORMAT="text"
SCAN_EXTENSIONS=true
SCAN_BOOKMARKS=true
SCAN_PROFILES=true
SCAN_CACHE=true

show_help() {
    cat <<EOF
${BOLD}Duplicate Profile Detection Tool${NC}

Scans all browser installations to find duplicate or redundant data:
  - Duplicate extensions installed across browsers/profiles
  - Similar bookmarks across profiles
  - Unused or empty profiles taking up space
  - Redundant cache data across install types

Usage: $(basename "$0") [OPTIONS]

Options:
  --json               Output as JSON
  --extensions-only    Only scan for duplicate extensions
  --profiles-only      Only scan for unused/redundant profiles
  --browser <name>     Only scan a specific browser
  -h, --help           Show this help message

Examples:
  $(basename "$0")                          # Full duplicate scan
  $(basename "$0") --json                   # JSON output
  $(basename "$0") --extensions-only        # Only check extensions
  $(basename "$0") --browser firefox        # Only scan Firefox

EOF
}

# ---- Profile scanning ----

# Find all Mozilla profiles with metadata
scan_mozilla_profiles() {
    local -n path_map=$1
    local browser_name="$2"

    for install_type in "${!path_map[@]}"; do
        local base_dir="${path_map[$install_type]}"
        [[ ! -d "$base_dir" ]] && continue

        local profiles_ini="$base_dir/profiles.ini"
        [[ ! -f "$profiles_ini" ]] && continue

        while IFS= read -r line; do
            if [[ "$line" =~ ^Path= ]]; then
                local rel_path="${line#Path=}"
                local profile_dir
                if [[ "$rel_path" == /* ]]; then
                    profile_dir="$rel_path"
                else
                    profile_dir="$base_dir/$rel_path"
                fi
                [[ ! -d "$profile_dir" ]] && continue

                local pname
                pname=$(basename "$profile_dir")
                local total_size
                total_size=$(get_size_bytes "$profile_dir")
                local cache_size=0
                for cache_dir in "$profile_dir/cache2" "$profile_dir/startupCache" "$profile_dir/shader-cache"; do
                    if [[ -d "$cache_dir" ]]; then
                        cache_size=$((cache_size + $(get_size_bytes "$cache_dir")))
                    fi
                done
                local data_size=$((total_size - cache_size))

                # Count files
                local file_count
                file_count=$(find "$profile_dir" -type f 2>/dev/null | wc -l)

                # Check last modified
                local last_modified
                last_modified=$(find "$profile_dir" -type f -name "*.sqlite" -printf '%T@\n' 2>/dev/null | sort -rn | head -1)
                local last_mod_date="unknown"
                if [[ -n "$last_modified" ]]; then
                    last_mod_date=$(date -d "@${last_modified%.*}" '+%Y-%m-%d' 2>/dev/null || echo "unknown")
                fi

                # Check if profile has meaningful data
                local has_bookmarks=false has_passwords=false has_history=false
                [[ -f "$profile_dir/places.sqlite" && $(stat -c%s "$profile_dir/places.sqlite" 2>/dev/null || echo 0) -gt 100000 ]] && has_bookmarks=true
                [[ -f "$profile_dir/logins.json" || -f "$profile_dir/key4.db" ]] && has_passwords=true
                [[ -f "$profile_dir/places.sqlite" ]] && has_history=true

                echo "PROFILE|$browser_name|$install_type|$pname|$total_size|$cache_size|$data_size|$file_count|$last_mod_date|$has_bookmarks|$has_passwords|$has_history|$profile_dir"
            fi
        done < "$profiles_ini"
    done
}

scan_chromium_profiles() {
    local -n path_map=$1
    local browser_name="$2"

    for install_type in "${!path_map[@]}"; do
        local base_dir="${path_map[$install_type]}"
        [[ ! -d "$base_dir" ]] && continue

        for profile_dir in "$base_dir"/Default "$base_dir"/Profile\ *; do
            [[ ! -d "$profile_dir" ]] && continue
            local pname
            pname=$(basename "$profile_dir")
            local total_size
            total_size=$(get_size_bytes "$profile_dir")
            local cache_size=0
            for cache_dir in "$profile_dir/Cache" "$profile_dir/Code Cache" "$profile_dir/GPUCache" "$profile_dir/ShaderCache" "$profile_dir/DawnCache"; do
                if [[ -d "$cache_dir" ]]; then
                    cache_size=$((cache_size + $(get_size_bytes "$cache_dir")))
                fi
            done
            local data_size=$((total_size - cache_size))

            local file_count
            file_count=$(find "$profile_dir" -type f 2>/dev/null | wc -l)

            local last_modified
            last_modified=$(find "$profile_dir" -type f -newer "$profile_dir" -printf '%T@\n' 2>/dev/null | sort -rn | head -1)
            local last_mod_date="unknown"
            if [[ -n "$last_modified" ]]; then
                last_mod_date=$(date -d "@${last_modified%.*}" '+%Y-%m-%d' 2>/dev/null || echo "unknown")
            fi

            local has_bookmarks=false has_passwords=false has_history=false
            [[ -f "$profile_dir/Bookmarks" && $(stat -c%s "$profile_dir/Bookmarks" 2>/dev/null || echo 0) -gt 100 ]] && has_bookmarks=true
            [[ -f "$profile_dir/Login Data" ]] && has_passwords=true
            [[ -f "$profile_dir/History" ]] && has_history=true

            echo "PROFILE|$browser_name|$install_type|$pname|$total_size|$cache_size|$data_size|$file_count|$last_mod_date|$has_bookmarks|$has_passwords|$has_history|$profile_dir"
        done
    done
}

# ---- Extension scanning ----

scan_mozilla_extensions() {
    local -n path_map=$1
    local browser_name="$2"

    for install_type in "${!path_map[@]}"; do
        local base_dir="${path_map[$install_type]}"
        [[ ! -d "$base_dir" ]] && continue
        local profiles_ini="$base_dir/profiles.ini"
        [[ ! -f "$profiles_ini" ]] && continue

        while IFS= read -r line; do
            if [[ "$line" =~ ^Path= ]]; then
                local rel_path="${line#Path=}"
                local profile_dir
                if [[ "$rel_path" == /* ]]; then profile_dir="$rel_path"; else profile_dir="$base_dir/$rel_path"; fi
                [[ ! -d "$profile_dir" ]] && continue
                local pname
                pname=$(basename "$profile_dir")

                local ext_file="$profile_dir/extensions.json"
                [[ ! -f "$ext_file" ]] && continue

                if command -v python3 &>/dev/null; then
                    python3 -c "
import json
with open('$ext_file') as f:
    data = json.load(f)
for addon in data.get('addons', []):
    loc = addon.get('location', '')
    if loc in ('app-builtin', 'app-system-defaults'):
        continue
    ext_id = addon.get('id', '')
    name = addon.get('defaultLocale', {}).get('name', addon.get('name', 'Unknown'))
    version = addon.get('version', '?')
    print(f'EXT|$browser_name|$install_type|$pname|{ext_id}|{name}|{version}')
" 2>/dev/null
                fi
            fi
        done < "$profiles_ini"
    done
}

scan_chromium_extensions() {
    local -n path_map=$1
    local browser_name="$2"

    for install_type in "${!path_map[@]}"; do
        local base_dir="${path_map[$install_type]}"
        [[ ! -d "$base_dir" ]] && continue

        for profile_dir in "$base_dir"/Default "$base_dir"/Profile\ *; do
            [[ ! -d "$profile_dir" ]] && continue
            local pname
            pname=$(basename "$profile_dir")
            local ext_dir="$profile_dir/Extensions"
            [[ ! -d "$ext_dir" ]] && continue

            for edir in "$ext_dir"/*/; do
                [[ ! -d "$edir" ]] && continue
                local ext_id
                ext_id=$(basename "$edir")
                [[ "$ext_id" == "Temp" ]] && continue

                local manifest=""
                for ver_dir in "$edir"/*/; do
                    [[ -f "$ver_dir/manifest.json" ]] && manifest="$ver_dir/manifest.json"
                done
                [[ -z "$manifest" ]] && continue

                local name="Unknown" version="?"
                if command -v python3 &>/dev/null; then
                    read -r name version < <(python3 -c "
import json
with open('$manifest') as f:
    d = json.load(f)
n = d.get('name','Unknown')
if n.startswith('__MSG_'): n = n.strip('_').replace('MSG_','')
print(f\"{n}\t{d.get('version','?')}\")
" 2>/dev/null) || true
                fi

                # Try to get real name from Secure Preferences
                if [[ -f "$profile_dir/Secure Preferences" ]] && command -v python3 &>/dev/null; then
                    local real_name
                    real_name=$(python3 -c "
import json
try:
    with open('$profile_dir/Secure Preferences') as f:
        d = json.load(f)
    n = d.get('extensions',{}).get('settings',{}).get('$ext_id',{}).get('manifest',{}).get('name','')
    if n and not n.startswith('__MSG_'): print(n)
except: pass
" 2>/dev/null)
                    [[ -n "$real_name" ]] && name="$real_name"
                fi

                echo "EXT|$browser_name|$install_type|$pname|$ext_id|$name|$version"
            done
        done
    done
}

# ---- Analysis ----

analyze_profiles() {
    local all_profiles="$1"
    local issues=0

    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        header "Profile Analysis"
    fi

    # Find empty or near-empty profiles
    local empty_profiles=""
    while IFS='|' read -r _ browser install pname total cache data files last_mod has_bm has_pw has_hist path; do
        [[ -z "$browser" ]] && continue
        local data_kb=$((data / 1024))

        # Profile with almost no data (< 1MB actual data, no bookmarks, no passwords)
        if [[ "$data_kb" -lt 1024 && "$has_bm" == "false" && "$has_pw" == "false" ]]; then
            ((issues++))
            empty_profiles+="EMPTY|$browser|$install|$pname|$(human_size "$total")|$last_mod|$path"$'\n'
        fi
    done <<< "$all_profiles"

    if [[ -n "$empty_profiles" ]]; then
        if [[ "$OUTPUT_FORMAT" == "text" ]]; then
            echo -e "${YELLOW}Empty/Unused Profiles:${NC}"
            while IFS='|' read -r _ browser install pname size last_mod path; do
                [[ -z "$browser" ]] && continue
                echo -e "  ${RED}●${NC} ${BOLD}$browser${NC} [$install] $pname — ${DIM}$size, last modified: $last_mod${NC}"
                echo -e "    ${DIM}Path: $path${NC}"
            done <<< "$empty_profiles"
            echo ""
        fi
    fi

    # Find duplicate installations (same browser in multiple install types)
    local seen_browsers=()
    local dup_installs=""
    while IFS='|' read -r _ browser install pname total cache data files last_mod has_bm has_pw has_hist path; do
        [[ -z "$browser" ]] && continue
        local key="$browser"
        local found=false
        for seen in "${seen_browsers[@]}"; do
            if [[ "$seen" == "$key" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            seen_browsers+=("$key")
        fi
    done <<< "$all_profiles"

    # Check for same browser across install types with similar profiles
    for browser_name in "Firefox" "Floorp" "Chromium" "Brave" "Chrome"; do
        local installs=()
        local install_sizes=()
        while IFS='|' read -r _ browser install pname total cache data files last_mod has_bm has_pw has_hist path; do
            [[ "$browser" != "$browser_name" ]] && continue
            local already=false
            for seen in "${installs[@]}"; do
                [[ "$seen" == "$install" ]] && already=true
            done
            if [[ "$already" == "false" ]]; then
                installs+=("$install")
                local total_for_install=0
                while IFS='|' read -r _ b2 i2 _ t2 _ _ _ _ _ _ _ _; do
                    [[ "$b2" == "$browser_name" && "$i2" == "$install" ]] && total_for_install=$((total_for_install + t2))
                done <<< "$all_profiles"
                install_sizes+=("$install:$total_for_install")
            fi
        done <<< "$all_profiles"

        if [[ ${#installs[@]} -gt 1 ]]; then
            ((issues++))
            if [[ "$OUTPUT_FORMAT" == "text" ]]; then
                echo -e "${YELLOW}Multiple installations of $browser_name:${NC}"
                for is in "${install_sizes[@]}"; do
                    local itype="${is%%:*}"
                    local isize="${is#*:}"
                    echo -e "  ${BOLD}●${NC} $itype — $(human_size "$isize") total"
                done
                echo -e "  ${DIM}Consider consolidating to a single install type${NC}"
                echo ""
            fi
        fi
    done

    # Find profiles with large cache relative to data
    while IFS='|' read -r _ browser install pname total cache data files last_mod has_bm has_pw has_hist path; do
        [[ -z "$browser" ]] && continue
        [[ "$total" -lt 1048576 ]] && continue  # Skip tiny profiles
        local cache_pct=0
        if [[ "$total" -gt 0 ]]; then
            cache_pct=$(( (cache * 100) / total ))
        fi
        if [[ "$cache_pct" -gt 70 ]]; then
            ((issues++))
            if [[ "$OUTPUT_FORMAT" == "text" ]]; then
                echo -e "${YELLOW}High cache ratio in $browser [$install] $pname:${NC}"
                echo -e "  Total: $(human_size "$total"), Cache: $(human_size "$cache") (${cache_pct}%)"
                echo -e "  ${DIM}Run the corresponding cleaner to free $(human_size "$cache")${NC}"
                echo ""
            fi
        fi
    done <<< "$all_profiles"

    return $issues
}

analyze_extensions() {
    local all_extensions="$1"
    local issues=0

    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        header "Extension Duplicate Analysis"
    fi

    # Build a map of extension_id -> list of (browser, install, profile)
    declare -A ext_locations
    declare -A ext_names

    while IFS='|' read -r _ browser install profile ext_id name version; do
        [[ -z "$ext_id" ]] && continue
        local key="$ext_id"
        local loc="$browser/$install/$profile"
        if [[ -n "${ext_locations[$key]:-}" ]]; then
            ext_locations[$key]="${ext_locations[$key]}|$loc"
        else
            ext_locations[$key]="$loc"
        fi
        ext_names[$key]="$name (v$version)"
    done <<< "$all_extensions"

    # Find extensions present in multiple places
    local dup_count=0
    for ext_id in "${!ext_locations[@]}"; do
        local locations="${ext_locations[$ext_id]}"
        local loc_count
        loc_count=$(echo "$locations" | tr '|' '\n' | wc -l)

        if [[ "$loc_count" -gt 1 ]]; then
            ((dup_count++))
            ((issues++))
            if [[ "$OUTPUT_FORMAT" == "text" ]]; then
                echo -e "${BOLD}${ext_names[$ext_id]}${NC} ${DIM}($ext_id)${NC}"
                echo -e "  Found in $loc_count locations:"
                echo "$locations" | tr '|' '\n' | while read -r loc; do
                    echo -e "    ${CYAN}●${NC} $loc"
                done
                echo ""
            fi
        fi
    done

    if [[ "$dup_count" -eq 0 && "$OUTPUT_FORMAT" == "text" ]]; then
        echo -e "  ${GREEN}No duplicate extensions found${NC}"
        echo ""
    fi

    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        # Summary
        local total_ext=${#ext_locations[@]}
        echo -e "${DIM}Total unique extensions: $total_ext, Duplicates: $dup_count${NC}"
    fi

    return $issues
}

# ---- JSON output ----

output_json() {
    local all_profiles="$1"
    local all_extensions="$2"

    if ! command -v python3 &>/dev/null; then
        error "python3 required for JSON output"
        exit 1
    fi

    python3 -c "
import json, sys
from datetime import datetime

profiles = []
extensions = []

# Parse profiles
for line in '''$all_profiles'''.strip().split('\n'):
    if not line or not line.startswith('PROFILE|'):
        continue
    parts = line.split('|')
    if len(parts) < 13:
        continue
    profiles.append({
        'browser': parts[1],
        'install_type': parts[2],
        'name': parts[3],
        'total_bytes': int(parts[4]),
        'cache_bytes': int(parts[5]),
        'data_bytes': int(parts[6]),
        'file_count': int(parts[7]),
        'last_modified': parts[8],
        'has_bookmarks': parts[9] == 'true',
        'has_passwords': parts[10] == 'true',
        'has_history': parts[11] == 'true',
        'path': parts[12]
    })

# Parse extensions
for line in '''$all_extensions'''.strip().split('\n'):
    if not line or not line.startswith('EXT|'):
        continue
    parts = line.split('|')
    if len(parts) < 7:
        continue
    extensions.append({
        'browser': parts[1],
        'install_type': parts[2],
        'profile': parts[3],
        'id': parts[4],
        'name': parts[5],
        'version': parts[6]
    })

# Find duplicates
ext_map = {}
for ext in extensions:
    key = ext['id']
    if key not in ext_map:
        ext_map[key] = {'name': ext['name'], 'version': ext['version'], 'locations': []}
    ext_map[key]['locations'].append(f\"{ext['browser']}/{ext['install_type']}/{ext['profile']}\")

duplicate_extensions = {k: v for k, v in ext_map.items() if len(v['locations']) > 1}

# Find empty profiles
empty_profiles = [p for p in profiles if p['data_bytes'] < 1048576 and not p['has_bookmarks'] and not p['has_passwords']]

# Find duplicate installs
browser_installs = {}
for p in profiles:
    b = p['browser']
    if b not in browser_installs:
        browser_installs[b] = set()
    browser_installs[b].add(p['install_type'])
multi_install = {b: list(types) for b, types in browser_installs.items() if len(types) > 1}

output = {
    'scanned': datetime.now().isoformat(),
    'summary': {
        'total_profiles': len(profiles),
        'total_extensions': len(extensions),
        'unique_extensions': len(ext_map),
        'duplicate_extensions': len(duplicate_extensions),
        'empty_profiles': len(empty_profiles),
        'multi_install_browsers': len(multi_install)
    },
    'issues': {
        'duplicate_extensions': duplicate_extensions,
        'empty_profiles': empty_profiles,
        'multi_install_browsers': multi_install
    },
    'profiles': profiles,
    'extensions': extensions
}

print(json.dumps(output, indent=2))
"
}

# ---- Main ----

main() {
    local target_browser=""

    for arg in "$@"; do
        case "$arg" in
            --json)             OUTPUT_FORMAT="json" ;;
            --extensions-only)  SCAN_PROFILES=false; SCAN_CACHE=false; SCAN_BOOKMARKS=false ;;
            --profiles-only)    SCAN_EXTENSIONS=false ;;
            -h|--help)          show_help; exit 0 ;;
        esac
    done

    # Parse --browser
    local prev=""
    for arg in "$@"; do
        [[ "$prev" == "--browser" ]] && target_browser="$arg"
        prev="$arg"
    done

    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        header "Duplicate & Redundancy Detection"
        info "Scanning all browser installations..."
        echo ""
    fi

    # Collect all profiles
    local all_profiles=""
    if [[ "$SCAN_PROFILES" == "true" ]]; then
        [[ -z "$target_browser" || "$target_browser" == "firefox" ]]  && all_profiles+=$(scan_mozilla_profiles FIREFOX_PATHS "Firefox")$'\n'
        [[ -z "$target_browser" || "$target_browser" == "floorp" ]]   && all_profiles+=$(scan_mozilla_profiles FLOORP_PATHS "Floorp")$'\n'
        [[ -z "$target_browser" || "$target_browser" == "chromium" ]] && all_profiles+=$(scan_chromium_profiles CHROMIUM_PATHS "Chromium")$'\n'
        [[ -z "$target_browser" || "$target_browser" == "brave" ]]    && all_profiles+=$(scan_chromium_profiles BRAVE_PATHS "Brave")$'\n'
        [[ -z "$target_browser" || "$target_browser" == "chrome" ]]   && all_profiles+=$(scan_chromium_profiles CHROME_PATHS "Chrome")$'\n'
    fi

    # Collect all extensions
    local all_extensions=""
    if [[ "$SCAN_EXTENSIONS" == "true" ]]; then
        [[ -z "$target_browser" || "$target_browser" == "firefox" ]]  && all_extensions+=$(scan_mozilla_extensions FIREFOX_PATHS "Firefox")$'\n'
        [[ -z "$target_browser" || "$target_browser" == "floorp" ]]   && all_extensions+=$(scan_mozilla_extensions FLOORP_PATHS "Floorp")$'\n'
        [[ -z "$target_browser" || "$target_browser" == "chromium" ]] && all_extensions+=$(scan_chromium_extensions CHROMIUM_PATHS "Chromium")$'\n'
        [[ -z "$target_browser" || "$target_browser" == "brave" ]]    && all_extensions+=$(scan_chromium_extensions BRAVE_PATHS "Brave")$'\n'
        [[ -z "$target_browser" || "$target_browser" == "chrome" ]]   && all_extensions+=$(scan_chromium_extensions CHROME_PATHS "Chrome")$'\n'
    fi

    # Clean up empty lines
    all_profiles=$(echo "$all_profiles" | grep -v '^$' || true)
    all_extensions=$(echo "$all_extensions" | grep -v '^$' || true)

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        output_json "$all_profiles" "$all_extensions"
        exit 0
    fi

    # Text output
    local total_issues=0

    if [[ "$SCAN_PROFILES" == "true" ]]; then
        analyze_profiles "$all_profiles" || total_issues=$((total_issues + $?))
    fi

    if [[ "$SCAN_EXTENSIONS" == "true" ]]; then
        analyze_extensions "$all_extensions" || total_issues=$((total_issues + $?))
    fi

    # Summary
    echo ""
    local profile_count
    profile_count=$(echo "$all_profiles" | grep -c '^PROFILE' || echo 0)
    local ext_count
    ext_count=$(echo "$all_extensions" | grep -c '^EXT' || echo 0)

    if [[ "$total_issues" -eq 0 ]]; then
        success "No issues found! ($profile_count profiles, $ext_count extensions scanned)"
    else
        warn "$total_issues issue(s) found across $profile_count profiles and $ext_count extensions"
    fi
}

main "$@"
