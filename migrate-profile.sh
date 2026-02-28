#!/usr/bin/env bash
# migrate-profile.sh - Migrate profiles between Firefox and Floorp
# Since Floorp is a Firefox fork, profiles are compatible between them
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

show_help() {
    cat <<EOF
${BOLD}Profile Migration Tool (Firefox <-> Floorp)${NC}

Migrate profiles between Firefox and Floorp. Since Floorp is a Firefox fork,
their profiles are compatible. This tool copies a profile from one browser
to the other, handling both native and Flatpak installations.

Usage: $(basename "$0") <direction> [OPTIONS]

Directions:
  firefox-to-floorp    Copy a Firefox profile to Floorp
  floorp-to-firefox    Copy a Floorp profile to Firefox

Options:
  --source-profile <name>   Name of the source profile to migrate
  --source-type <type>      Source install type: native, flatpak, snap (default: auto)
  --target-type <type>      Target install type: native, flatpak (default: auto)
  --profile-name <name>     Name for the new profile (default: migrated-<source>)
  -y, --yes                 Skip confirmation prompts
  -h, --help                Show this help message

Examples:
  $(basename "$0") firefox-to-floorp
  $(basename "$0") floorp-to-firefox --source-profile default-release
  $(basename "$0") firefox-to-floorp --source-type flatpak --target-type native
EOF
}

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

# Parse profiles.ini (same as profile managers)
parse_profiles_ini() {
    local ini_file="$1"
    if [[ ! -f "$ini_file" ]]; then
        return 1
    fi

    local name="" path="" is_relative="" is_default=""
    while IFS='=' read -r key value; do
        key=$(echo "$key" | tr -d '[:space:]')
        value=$(echo "$value" | tr -d '[:space:]' | tr -d $'\r')
        case "$key" in
            \[Profile*)
                if [[ -n "$name" ]]; then
                    echo "${name}|${path}|${is_relative}|${is_default}"
                fi
                name="" path="" is_relative="" is_default="0"
                ;;
            Name) name="$value" ;;
            Path) path="$value" ;;
            IsRelative) is_relative="$value" ;;
            Default) is_default="$value" ;;
        esac
    done < "$ini_file"
    if [[ -n "$name" ]]; then
        echo "${name}|${path}|${is_relative}|${is_default}"
    fi
}

# Find the first available path from an associative array
find_install() {
    local -n paths=$1
    local preferred="${2:-}"

    if [[ -n "$preferred" ]] && [[ -d "${paths[$preferred]}" ]]; then
        echo "$preferred|${paths[$preferred]}"
        return 0
    fi

    for type in native flatpak snap; do
        if [[ -n "${paths[$type]:-}" ]] && [[ -d "${paths[$type]}" ]]; then
            echo "$type|${paths[$type]}"
            return 0
        fi
    done
    return 1
}

# List profiles for user selection
select_profile() {
    local profiles_dir="$1"
    local app_name="$2"
    local preferred_name="$3"

    local ini_file="$profiles_dir/profiles.ini"
    if [[ ! -f "$ini_file" ]]; then
        error "No profiles.ini found in $profiles_dir"
        return 1
    fi

    local profiles=()
    local names=()
    local paths=()

    while IFS='|' read -r name path is_relative is_default; do
        local full_path
        if [[ "$is_relative" == "1" ]]; then
            full_path="$profiles_dir/$path"
        else
            full_path="$path"
        fi
        if [[ -d "$full_path" ]]; then
            profiles+=("$name|$path|$is_relative|$is_default")
            names+=("$name")
            paths+=("$full_path")
        fi
    done < <(parse_profiles_ini "$ini_file")

    if [[ ${#profiles[@]} -eq 0 ]]; then
        error "No $app_name profiles found"
        return 1
    fi

    # If a preferred name was given, use it
    if [[ -n "$preferred_name" ]]; then
        for i in "${!names[@]}"; do
            if [[ "${names[$i]}" == "$preferred_name" ]]; then
                echo "${paths[$i]}|${names[$i]}"
                return 0
            fi
        done
        error "Profile '$preferred_name' not found in $app_name"
        return 1
    fi

    # Interactive selection
    echo ""
    echo "Available $app_name profiles:"
    for i in "${!names[@]}"; do
        local size
        size=$(du -sh "${paths[$i]}" 2>/dev/null | cut -f1)
        local default_marker=""
        IFS='|' read -r _ _ _ is_default <<< "${profiles[$i]}"
        if [[ "$is_default" == "1" ]]; then
            default_marker=" ${GREEN}[DEFAULT]${NC}"
        fi
        printf "  ${BOLD}%2d)${NC} %-30s %s%b\n" "$((i + 1))" "${names[$i]}" "$size" "$default_marker"
    done
    echo ""

    read -rp "$(echo -e "${YELLOW}Select profile number:${NC} ")" choice
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#names[@]} ]]; then
        error "Invalid selection"
        return 1
    fi

    local idx=$((choice - 1))
    echo "${paths[$idx]}|${names[$idx]}"
}

main() {
    local direction=""
    local source_profile=""
    local source_type=""
    local target_type=""
    local new_profile_name=""

    parse_common_flags "$@" || { show_help; exit 0; }

    local prev=""
    for arg in "$@"; do
        case "$prev" in
            --source-profile) source_profile="$arg"; prev=""; continue ;;
            --source-type)    source_type="$arg"; prev=""; continue ;;
            --target-type)    target_type="$arg"; prev=""; continue ;;
            --profile-name)   new_profile_name="$arg"; prev=""; continue ;;
        esac
        case "$arg" in
            firefox-to-floorp|floorp-to-firefox) direction="$arg" ;;
            --source-profile|--source-type|--target-type|--profile-name) prev="$arg" ;;
        esac
    done

    if [[ -z "$direction" ]]; then
        show_help
        exit 0
    fi

    # Determine source and target
    local source_app="" target_app=""
    local -n source_paths_ref target_paths_ref

    case "$direction" in
        firefox-to-floorp)
            source_app="Firefox"
            target_app="Floorp"
            source_paths_ref=FIREFOX_PATHS
            target_paths_ref=FLOORP_PATHS
            ;;
        floorp-to-firefox)
            source_app="Floorp"
            target_app="Firefox"
            source_paths_ref=FLOORP_PATHS
            target_paths_ref=FIREFOX_PATHS
            ;;
    esac

    header "Profile Migration: $source_app -> $target_app"

    # Check both browsers are not running
    if app_is_running "firefox"; then
        error "Firefox appears to be running. Please close it first."
        exit 1
    fi
    if app_is_running "floorp"; then
        error "Floorp appears to be running. Please close it first."
        exit 1
    fi

    # Find source installation
    local source_result
    source_result=$(find_install source_paths_ref "$source_type") || {
        error "No $source_app installation found"
        exit 1
    }
    local src_install_type src_dir
    IFS='|' read -r src_install_type src_dir <<< "$source_result"
    info "Source: $source_app ($src_install_type) at $src_dir"

    # Find target installation
    local target_result
    target_result=$(find_install target_paths_ref "$target_type") || {
        error "No $target_app installation found"
        exit 1
    }
    local tgt_install_type tgt_dir
    IFS='|' read -r tgt_install_type tgt_dir <<< "$target_result"
    info "Target: $target_app ($tgt_install_type) at $tgt_dir"

    # Select source profile
    local profile_result
    profile_result=$(select_profile "$src_dir" "$source_app" "$source_profile") || exit 1
    local src_profile_path src_profile_name
    IFS='|' read -r src_profile_path src_profile_name <<< "$profile_result"

    info "Migrating profile: $src_profile_name"

    # Determine new profile name
    if [[ -z "$new_profile_name" ]]; then
        new_profile_name="migrated-${src_profile_name}"
    fi

    # Generate target directory name
    local random_str
    random_str=$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 8)
    local tgt_dir_name="${random_str}.${new_profile_name}"
    local tgt_profile_path="$tgt_dir/$tgt_dir_name"

    local src_size
    src_size=$(du -sh "$src_profile_path" 2>/dev/null | cut -f1)

    echo ""
    echo -e "${BOLD}Migration Plan:${NC}"
    echo "  Source:  $source_app ($src_install_type) / $src_profile_name ($src_size)"
    echo "  Target:  $target_app ($tgt_install_type) / $new_profile_name"
    echo "  From:    $src_profile_path"
    echo "  To:      $tgt_profile_path"
    echo ""
    echo -e "${YELLOW}Note: This COPIES the profile. The original remains untouched.${NC}"
    echo ""

    if confirm "Proceed with migration?"; then
        info "Copying profile..."
        cp -a "$src_profile_path" "$tgt_profile_path"

        # Add to target profiles.ini
        local ini_file="$tgt_dir/profiles.ini"
        local next_num=0
        if [[ -f "$ini_file" ]]; then
            next_num=$(grep -c '^\[Profile' "$ini_file" 2>/dev/null || echo "0")
        else
            cat > "$ini_file" <<INIEOF
[General]
StartWithLastProfile=1

INIEOF
        fi

        cat >> "$ini_file" <<INIEOF
[Profile${next_num}]
Name=${new_profile_name}
IsRelative=1
Path=${tgt_dir_name}

INIEOF

        local tgt_size
        tgt_size=$(du -sh "$tgt_profile_path" 2>/dev/null | cut -f1)
        success "Profile migrated successfully! ($tgt_size)"
        info "You can now launch $target_app and select the '$new_profile_name' profile."

        case "$target_app" in
            Firefox) info "Or run: firefox -P \"$new_profile_name\"" ;;
            Floorp)  info "Or run: floorp -P \"$new_profile_name\"" ;;
        esac
    fi
}

main "$@"
