#!/usr/bin/env bash
# profile-manager.sh - Unified profile manager for all Mozilla-based browsers
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools
#
# Replaces the separate firefox-profile-manager.sh and floorp-profile-manager.sh
# with a single parameterized script that works for all Mozilla-based browsers:
# Firefox, Floorp, LibreWolf, Waterfox, Zen Browser

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/paths.sh"
source "$SCRIPT_DIR/lib/profiles.sh"
source "$SCRIPT_DIR/lib/config.sh"

show_help() {
    cat << EOF
Unified Mozilla Profile Manager

Usage: $(basename "$0") --browser <BROWSER> <COMMAND> [OPTIONS]

Browsers: firefox, floorp, librewolf, waterfox, zen

Commands:
  list                  List all profiles with sizes
  info <profile>        Show detailed profile information
  backup <profile>      Create a compressed backup
  restore               Restore from a backup archive
  create <name>         Create a new profile
  delete <profile>      Delete a profile (auto-backs up first)
  reset <profile>       Reset profile (preserves bookmarks/passwords/extensions)

Options:
  --browser <name>      Browser to manage (required)
  --install <type>      Installation type: native, flatpak, snap (default: detect)
  --backup-dir <path>   Custom backup directory
  --encrypt             Encrypt backups with GPG
  -y, --yes             Auto-confirm all prompts
  -n, --dry-run         Show what would be done without making changes
  -V, --version         Show version
  -h, --help            Show this help

Examples:
  $(basename "$0") --browser firefox list
  $(basename "$0") --browser floorp backup default-release
  $(basename "$0") --browser librewolf reset default --encrypt
  $(basename "$0") --browser zen info default-release
EOF
}

# Map CLI browser name to internal registry name
resolve_browser() {
    case "${1,,}" in
        firefox)   echo "FIREFOX" ;;
        floorp)    echo "FLOORP" ;;
        librewolf) echo "LIBREWOLF" ;;
        waterfox)  echo "WATERFOX" ;;
        zen|zen-browser) echo "ZEN" ;;
        *) echo "" ;;
    esac
}

# ===========================================================================
# COMMANDS
# ===========================================================================

do_list() {
    local browser="$1"
    local install_filter="$2"
    local display_name
    display_name=$(get_display_name "$browser")

    header "$display_name Profiles"

    local found=false
    while IFS='|' read -r install_type name path; do
        found=true
        local size default_marker=""
        size=$(get_size "$path")

        # Check if this is the default profile
        local base_dir
        base_dir=$(dirname "$path")
        if [[ -f "$base_dir/profiles.ini" ]]; then
            local ini_default
            ini_default=$(parse_profiles_ini "$base_dir/profiles.ini" | grep "|1$" | head -1 | cut -d'|' -f2)
            local profile_dir_name
            profile_dir_name=$(basename "$path")
            if [[ "$ini_default" == *"$profile_dir_name" || "$profile_dir_name" == *"$ini_default" ]]; then
                default_marker=" ${GREEN}(default)${NC}"
            fi
        fi

        echo -e "  ${BOLD}$name${NC} [$install_type] - $size${default_marker}"
        echo -e "    Path: ${DIM}$path${NC}"
    done < <(find_mozilla_profiles "$browser" "$install_filter" 2>/dev/null)

    if ! $found; then
        info "No $display_name profiles found"
    fi
}

do_info() {
    local browser="$1"
    local install_filter="$2"
    local target_profile="$3"
    local display_name
    display_name=$(get_display_name "$browser")

    local found=false
    while IFS='|' read -r install_type name path; do
        local dir_name
        dir_name=$(basename "$path")
        if [[ "$name" == *"$target_profile"* || "$dir_name" == *"$target_profile"* ]]; then
            found=true
            header "$display_name Profile: $name ($install_type)"

            # Directory sizes
            echo -e "${BOLD}Storage Breakdown:${NC}"
            local total_size
            total_size=$(get_size "$path")
            echo -e "  Total Size: ${CYAN}$total_size${NC}"

            local dirs=(
                "cache2:Cache"
                "storage:Site Storage"
                "extensions:Extensions"
                "bookmarkbackups:Bookmark Backups"
                "sessionstore-backups:Session Backups"
                "datareporting:Data Reporting"
                "saved-telemetry-pings:Telemetry"
                "shader-cache:Shader Cache"
                "thumbnails:Thumbnails"
                "startupCache:Startup Cache"
            )

            for entry in "${dirs[@]}"; do
                local dir="${entry%%:*}"
                local label="${entry#*:}"
                if [[ -d "$path/$dir" ]]; then
                    local size
                    size=$(get_size "$path/$dir")
                    echo -e "  $label: $size"
                fi
            done

            # Key files
            echo -e "\n${BOLD}Key Files:${NC}"
            local files=(
                "places.sqlite:Bookmarks & History"
                "key4.db:Password Encryption Key"
                "logins.json:Saved Passwords"
                "cert9.db:Certificates"
                "cookies.sqlite:Cookies"
                "formhistory.sqlite:Form History"
                "permissions.sqlite:Site Permissions"
                "prefs.js:Preferences"
                "user.js:User Overrides"
            )

            for entry in "${files[@]}"; do
                local file="${entry%%:*}"
                local label="${entry#*:}"
                if [[ -f "$path/$file" ]]; then
                    local size
                    size=$(get_size "$path/$file")
                    echo -e "  ${GREEN}✓${NC} $label: $size"
                else
                    echo -e "  ${DIM}✗ $label: not present${NC}"
                fi
            done

            # Extension count
            if [[ -f "$path/extensions.json" ]]; then
                local ext_count
                ext_count=$(python3 -c "
import json
with open('$path/extensions.json') as f:
    data = json.load(f)
    exts = [a for a in data.get('addons', []) if a.get('location') not in ('app-builtin', 'app-system-defaults')]
    print(len(exts))
" 2>/dev/null) || ext_count="?"
                echo -e "\n  Extensions installed: ${CYAN}$ext_count${NC}"
            fi

            break
        fi
    done < <(find_mozilla_profiles "$browser" "$install_filter" 2>/dev/null)

    if ! $found; then
        error "Profile '$target_profile' not found. Use 'list' to see available profiles."
    fi
}

do_backup() {
    local browser="$1"
    local install_filter="$2"
    local target_profile="$3"
    local backup_dir="$4"
    local encrypt="$5"
    local display_name
    display_name=$(get_display_name "$browser")

    # Default backup directory
    if [[ -z "$backup_dir" ]]; then
        backup_dir="$HOME/${display_name,,}-backups"
    fi

    local found=false
    while IFS='|' read -r install_type name path; do
        local dir_name
        dir_name=$(basename "$path")
        if [[ "$name" == *"$target_profile"* || "$dir_name" == *"$target_profile"* ]]; then
            found=true
            backup_profile "$path" "$backup_dir" "${display_name,,}_${name}" "$encrypt"
            break
        fi
    done < <(find_mozilla_profiles "$browser" "$install_filter" 2>/dev/null)

    if ! $found; then
        error "Profile '$target_profile' not found. Use 'list' to see available profiles."
    fi
}

do_restore() {
    local browser="$1"
    local install_filter="$2"
    local backup_dir="$3"
    local display_name
    display_name=$(get_display_name "$browser")

    if [[ -z "$backup_dir" ]]; then
        backup_dir="$HOME/${display_name,,}-backups"
    fi

    header "Available Backups"
    list_backups "$backup_dir" || return 1

    echo ""
    read -rp "Enter backup filename to restore: " backup_name
    [[ -z "$backup_name" ]] && { error "No backup selected"; return 1; }

    local archive="$backup_dir/$backup_name"
    [[ ! -f "$archive" ]] && { error "Backup not found: $archive"; return 1; }

    # Select target profile directory
    echo ""
    info "Select target installation:"
    local targets=()
    local profiles_var="${browser}_PROFILES"
    local -n profiles_ref="$profiles_var"
    for install_type in "${!profiles_ref[@]}"; do
        local base="${profiles_ref[$install_type]}"
        [[ -d "$base" ]] && targets+=("$install_type|$base")
    done

    if [[ ${#targets[@]} -eq 0 ]]; then
        error "No $display_name installations found"
        return 1
    fi

    local i=1
    for t in "${targets[@]}"; do
        echo "  $i) ${t%%|*}: ${t#*|}"
        ((i++))
    done
    read -rp "Select (1-${#targets[@]}): " choice
    local target="${targets[$((choice-1))]}"
    local target_dir="${target#*|}"

    restore_profile "$archive" "$target_dir"
}

do_create() {
    local browser="$1"
    local install_filter="$2"
    local profile_name="$3"
    local display_name
    display_name=$(get_display_name "$browser")

    # Find the base directory
    local profiles_var="${browser}_PROFILES"
    local -n profiles_ref="$profiles_var"
    local base_dir=""
    for install_type in native flatpak snap; do
        local dir="${profiles_ref[$install_type]:-}"
        [[ -d "$dir" ]] && { base_dir="$dir"; break; }
    done

    [[ -z "$base_dir" ]] && { error "No $display_name installation found"; return 1; }

    # Generate random prefix
    local prefix
    prefix=$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 8)
    local dir_name="${prefix}.${profile_name}"
    local profile_path="$base_dir/$dir_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run "Would create profile: $profile_path"
        return 0
    fi

    mkdir -p "$profile_path"

    # Add to profiles.ini
    local ini_file="$base_dir/profiles.ini"
    if [[ -f "$ini_file" ]]; then
        # Find next profile number
        local max_num=0
        while IFS= read -r line; do
            if [[ "$line" =~ ^\[Profile([0-9]+)\] ]]; then
                local num="${BASH_REMATCH[1]}"
                [[ "$num" -gt "$max_num" ]] && max_num="$num"
            fi
        done < "$ini_file"
        local next_num=$((max_num + 1))

        cat >> "$ini_file" << EOF

[Profile${next_num}]
Name=${profile_name}
IsRelative=1
Path=${dir_name}
EOF
    fi

    success "Created profile '$profile_name' at: $profile_path"
}

do_delete() {
    local browser="$1"
    local install_filter="$2"
    local target_profile="$3"
    local backup_dir="$4"
    local encrypt="$5"
    local display_name
    display_name=$(get_display_name "$browser")

    local found=false
    while IFS='|' read -r install_type name path; do
        local dir_name
        dir_name=$(basename "$path")
        if [[ "$name" == *"$target_profile"* || "$dir_name" == *"$target_profile"* ]]; then
            found=true

            if ! confirm "Delete $display_name profile '$name'? (backup will be created first)"; then
                info "Cancelled"
                return 0
            fi

            # Auto-backup before deletion
            local bdir="${backup_dir:-$HOME/${display_name,,}-backups}"
            backup_profile "$path" "$bdir" "${display_name,,}_${name}_pre-delete" "$encrypt"

            if [[ "$DRY_RUN" == "true" ]]; then
                dry_run "Would delete profile: $path"
                return 0
            fi

            rm -rf "$path"

            # Remove from profiles.ini
            local base_dir
            base_dir=$(dirname "$path")
            local ini_file="$base_dir/profiles.ini"
            if [[ -f "$ini_file" ]]; then
                python3 -c "
import re, sys
with open('$ini_file', 'r') as f:
    content = f.read()
# Remove the profile section that contains this path
dir_name = '$(basename "$path")'
pattern = r'\[Profile\d+\][^\[]*Path=.*' + re.escape(dir_name) + r'[^\[]*'
content = re.sub(pattern, '', content)
content = re.sub(r'\n{3,}', '\n\n', content)
with open('$ini_file', 'w') as f:
    f.write(content.strip() + '\n')
" 2>/dev/null || warn "Could not update profiles.ini"
            fi

            success "Deleted profile '$name'"
            break
        fi
    done < <(find_mozilla_profiles "$browser" "$install_filter" 2>/dev/null)

    if ! $found; then
        error "Profile '$target_profile' not found"
    fi
}

do_reset() {
    local browser="$1"
    local install_filter="$2"
    local target_profile="$3"
    local backup_dir="$4"
    local encrypt="$5"
    local display_name
    display_name=$(get_display_name "$browser")

    local found=false
    while IFS='|' read -r install_type name path; do
        local dir_name
        dir_name=$(basename "$path")
        if [[ "$name" == *"$target_profile"* || "$dir_name" == *"$target_profile"* ]]; then
            found=true

            if ! confirm "Reset $display_name profile '$name'? (bookmarks/passwords/extensions preserved, backup created first)"; then
                info "Cancelled"
                return 0
            fi

            # Auto-backup
            local bdir="${backup_dir:-$HOME/${display_name,,}-backups}"
            backup_profile "$path" "$bdir" "${display_name,,}_${name}_pre-reset" "$encrypt"

            if [[ "$DRY_RUN" == "true" ]]; then
                dry_run "Would reset profile: $path"
                return 0
            fi

            info "Resetting profile (preserving bookmarks, passwords, extensions)..."

            # Remove items that will be regenerated
            local remove_items=(
                "cache2" "thumbnails" "startupCache" "jumpListCache"
                "sessionstore-backups" "sessionstore.jsonlz4"
                "cookies.sqlite" "cookies.sqlite-wal" "cookies.sqlite-shm"
                "formhistory.sqlite" "formhistory.sqlite-wal"
                "webappsstore.sqlite" "webappsstore.sqlite-wal"
                "content-prefs.sqlite" "permissions.sqlite"
                "storage/temporary" "shader-cache"
                "datareporting" "saved-telemetry-pings"
                "minidumps" "crash reports" "Crash Reports"
            )

            for item in "${remove_items[@]}"; do
                [[ -e "$path/$item" ]] && rm -rf "$path/$item"
            done

            success "Profile '$name' has been reset"
            info "Preserved: bookmarks, passwords, certificates, extensions, preferences"
            break
        fi
    done < <(find_mozilla_profiles "$browser" "$install_filter" 2>/dev/null)

    if ! $found; then
        error "Profile '$target_profile' not found"
    fi
}

# ===========================================================================
# MAIN
# ===========================================================================

main() {
    check_version_flag "$@"

    local browser_name="" browser="" command="" target="" install_filter=""
    local backup_dir="" encrypt="${ENCRYPT_BACKUPS:-false}"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --browser|-b) browser_name="${2:-}"; shift 2 ;;
            --install)    install_filter="${2:-}-only"; shift 2 ;;
            --backup-dir) backup_dir="${2:-}"; shift 2 ;;
            --encrypt)    encrypt="true"; shift ;;
            -y|--yes)     AUTO_YES=true; export AUTO_YES; shift ;;
            -n|--dry-run) DRY_RUN=true; export DRY_RUN; shift ;;
            -h|--help)    show_help; exit 0 ;;
            -V|--version) show_version; exit 0 ;;
            list|info|backup|restore|create|delete|reset)
                command="$1"; shift
                [[ $# -gt 0 && ! "$1" =~ ^- ]] && { target="$1"; shift; }
                ;;
            *) shift ;;
        esac
    done

    if [[ -z "$browser_name" ]]; then
        error "Browser name required. Use --browser <name>"
        echo "Supported: firefox, floorp, librewolf, waterfox, zen"
        exit 1
    fi

    browser=$(resolve_browser "$browser_name")
    if [[ -z "$browser" ]]; then
        error "Unsupported browser: $browser_name"
        echo "Supported: firefox, floorp, librewolf, waterfox, zen"
        exit 1
    fi

    if browser_is_running "$browser"; then
        error "$(get_display_name "$browser") is running. Please close it first."
        exit 1
    fi

    case "$command" in
        list)    do_list "$browser" "$install_filter" ;;
        info)    [[ -z "$target" ]] && { error "Profile name required"; exit 1; }
                 do_info "$browser" "$install_filter" "$target" ;;
        backup)  [[ -z "$target" ]] && { error "Profile name required"; exit 1; }
                 do_backup "$browser" "$install_filter" "$target" "$backup_dir" "$encrypt" ;;
        restore) do_restore "$browser" "$install_filter" "$backup_dir" ;;
        create)  [[ -z "$target" ]] && { error "Profile name required"; exit 1; }
                 do_create "$browser" "$install_filter" "$target" ;;
        delete)  [[ -z "$target" ]] && { error "Profile name required"; exit 1; }
                 do_delete "$browser" "$install_filter" "$target" "$backup_dir" "$encrypt" ;;
        reset)   [[ -z "$target" ]] && { error "Profile name required"; exit 1; }
                 do_reset "$browser" "$install_filter" "$target" "$backup_dir" "$encrypt" ;;
        *)       error "No command specified"; show_help; exit 1 ;;
    esac
}

main "$@"
