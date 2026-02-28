#!/usr/bin/env bash
# firefox-profile-manager.sh - Manage Firefox profiles
# List, backup, create, delete, and reset Firefox profiles
# Supports both native and Flatpak installations
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

APP_NAME="Firefox"
NATIVE_PROFILE_DIR="$HOME/.mozilla/firefox"
FLATPAK_APP_ID="org.mozilla.firefox"
FLATPAK_BASE="$HOME/.var/app/$FLATPAK_APP_ID"
FLATPAK_PROFILE_DIR="$FLATPAK_BASE/.mozilla/firefox"

show_help() {
    cat <<EOF
${BOLD}Firefox Profile Manager${NC}

Manage Firefox profiles — list, backup, create, delete, reset, and restore.
Supports both native and Flatpak installations.

Usage: $(basename "$0") <command> [OPTIONS]

Commands:
  list                     List all profiles
  backup [profile_name]    Backup a profile (or all if none specified)
  restore <backup_file>    Restore a profile from a backup archive
  create <profile_name>    Create a new profile
  delete <profile_name>    Delete a profile
  reset  <profile_name>    Reset a profile (backup + clean, keep bookmarks)
  info   [profile_name]    Show size and details of profile(s)

Options:
  --native-only            Only manage native installation
  --flatpak-only           Only manage Flatpak installation
  --backup-dir <path>      Custom backup directory (default: ~/firefox-backups)
  -y, --yes                Skip confirmation prompts
  -h, --help               Show this help message

Examples:
  $(basename "$0") list
  $(basename "$0") backup
  $(basename "$0") backup my-profile --backup-dir /tmp/backups
  $(basename "$0") create work-profile
  $(basename "$0") reset default-release -y
  $(basename "$0") restore ~/firefox-backups/firefox-native-default-20260228.tar.gz
EOF
}

BACKUP_DIR="$HOME/firefox-backups"
NATIVE_ONLY=false
FLATPAK_ONLY=false

# Parse a profiles.ini to get profile info
# Returns lines of: Name|Path|IsRelative|Default
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
    # Print last profile
    if [[ -n "$name" ]]; then
        echo "${name}|${path}|${is_relative}|${is_default}"
    fi
}

# Get the full path to a profile directory
resolve_profile_path() {
    local profiles_dir="$1"
    local path="$2"
    local is_relative="$3"

    if [[ "$is_relative" == "1" ]]; then
        echo "$profiles_dir/$path"
    else
        echo "$path"
    fi
}

# List all profiles for a given profiles directory
list_profiles() {
    local profiles_dir="$1"
    local install_type="$2"
    local ini_file="$profiles_dir/profiles.ini"

    if [[ ! -f "$ini_file" ]]; then
        warn "$install_type $APP_NAME: No profiles.ini found"
        return 1
    fi

    header "$install_type $APP_NAME Profiles"

    local count=0
    while IFS='|' read -r name path is_relative is_default; do
        local full_path
        full_path=$(resolve_profile_path "$profiles_dir" "$path" "$is_relative")
        local size="(not found)"
        local default_marker=""
        if [[ -d "$full_path" ]]; then
            size=$(du -sh "$full_path" 2>/dev/null | cut -f1)
        fi
        if [[ "$is_default" == "1" ]]; then
            default_marker=" ${GREEN}[DEFAULT]${NC}"
        fi
        echo -e "  ${BOLD}$name${NC}${default_marker}"
        echo -e "    Path: $path"
        echo -e "    Size: $size"
        echo ""
        count=$((count + 1))
    done < <(parse_profiles_ini "$ini_file")

    info "Total: $count profile(s)"
}

# Show detailed info for a specific profile
show_profile_info() {
    local profiles_dir="$1"
    local install_type="$2"
    local target_name="$3"
    local ini_file="$profiles_dir/profiles.ini"

    if [[ ! -f "$ini_file" ]]; then
        return 1
    fi

    while IFS='|' read -r name path is_relative is_default; do
        if [[ -n "$target_name" && "$name" != "$target_name" ]]; then
            continue
        fi
        local full_path
        full_path=$(resolve_profile_path "$profiles_dir" "$path" "$is_relative")

        if [[ ! -d "$full_path" ]]; then
            warn "Profile directory not found: $full_path"
            continue
        fi

        header "$install_type $APP_NAME Profile: $name"
        echo -e "  ${BOLD}Directory:${NC} $full_path"
        echo -e "  ${BOLD}Total Size:${NC} $(du -sh "$full_path" 2>/dev/null | cut -f1)"
        echo ""

        # Size breakdown
        echo -e "  ${BOLD}Size Breakdown:${NC}"
        local items=(
            "storage:Site Storage"
            "cache2:Cache"
            "bookmarkbackups:Bookmark Backups"
            "extensions:Extensions"
            "startupCache:Startup Cache"
            "shader-cache:Shader Cache"
            "datareporting:Data Reporting"
            "saved-telemetry-pings:Telemetry Pings"
            "sessionstore-backups:Session Backups"
            "minidumps:Crash Dumps"
        )
        for item in "${items[@]}"; do
            local dir="${item%%:*}"
            local label="${item#*:}"
            local item_path="$full_path/$dir"
            if [[ -d "$item_path" ]]; then
                local item_size
                item_size=$(du -sh "$item_path" 2>/dev/null | cut -f1)
                printf "    %-22s %s\n" "$label:" "$item_size"
            fi
        done

        # Key files
        echo ""
        echo -e "  ${BOLD}Key Files:${NC}"
        for f in places.sqlite favicons.sqlite cookies.sqlite formhistory.sqlite \
                 key4.db logins.json cert9.db prefs.js user.js; do
            local fp="$full_path/$f"
            if [[ -f "$fp" ]]; then
                local fsize
                fsize=$(du -sh "$fp" 2>/dev/null | cut -f1)
                printf "    %-22s %s\n" "$f:" "$fsize"
            fi
        done
        echo ""
    done < <(parse_profiles_ini "$ini_file")
}

# Backup a profile
backup_profile() {
    local profiles_dir="$1"
    local install_type="$2"
    local target_name="$3"
    local ini_file="$profiles_dir/profiles.ini"

    if [[ ! -f "$ini_file" ]]; then
        return 1
    fi

    mkdir -p "$BACKUP_DIR"

    while IFS='|' read -r name path is_relative is_default; do
        if [[ -n "$target_name" && "$name" != "$target_name" ]]; then
            continue
        fi
        local full_path
        full_path=$(resolve_profile_path "$profiles_dir" "$path" "$is_relative")

        if [[ ! -d "$full_path" ]]; then
            warn "Profile directory not found: $full_path"
            continue
        fi

        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_name="${APP_NAME,,}-${install_type,,}-${name}-${timestamp}"
        local backup_path="$BACKUP_DIR/${backup_name}.tar.gz"

        info "Backing up $install_type profile '$name' to $backup_path..."
        tar -czf "$backup_path" -C "$(dirname "$full_path")" "$(basename "$full_path")" 2>/dev/null
        local backup_size
        backup_size=$(du -sh "$backup_path" 2>/dev/null | cut -f1)
        success "Backup created: $backup_path ($backup_size)"
    done < <(parse_profiles_ini "$ini_file")
}

# Create a new profile
create_profile() {
    local profiles_dir="$1"
    local install_type="$2"
    local profile_name="$3"

    if [[ -z "$profile_name" ]]; then
        error "Profile name required"
        return 1
    fi

    # Generate a random directory name like Firefox does
    local random_str
    random_str=$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 8)
    local dir_name="${random_str}.${profile_name}"

    mkdir -p "$profiles_dir/$dir_name"

    # Find the next profile number
    local ini_file="$profiles_dir/profiles.ini"
    local next_num=0
    if [[ -f "$ini_file" ]]; then
        next_num=$(grep -c '^\[Profile' "$ini_file" 2>/dev/null || echo "0")
    else
        # Create a basic profiles.ini
        cat > "$ini_file" <<INIEOF
[General]
StartWithLastProfile=1

INIEOF
    fi

    # Append the new profile
    cat >> "$ini_file" <<INIEOF
[Profile${next_num}]
Name=${profile_name}
IsRelative=1
Path=${dir_name}

INIEOF

    success "Created $install_type profile '$profile_name' at $profiles_dir/$dir_name"
    info "Start $APP_NAME with: firefox -P \"$profile_name\" to use this profile"
}

# Delete a profile
delete_profile() {
    local profiles_dir="$1"
    local install_type="$2"
    local target_name="$3"
    local ini_file="$profiles_dir/profiles.ini"

    if [[ -z "$target_name" ]]; then
        error "Profile name required"
        return 1
    fi

    if [[ ! -f "$ini_file" ]]; then
        error "No profiles.ini found"
        return 1
    fi

    # Find the profile path
    local found=false
    while IFS='|' read -r name path is_relative is_default; do
        if [[ "$name" == "$target_name" ]]; then
            found=true
            local full_path
            full_path=$(resolve_profile_path "$profiles_dir" "$path" "$is_relative")

            if [[ "$is_default" == "1" ]]; then
                warn "This is the default profile!"
            fi

            if confirm "Delete $install_type profile '$name'? This cannot be undone!"; then
                # Backup first
                backup_profile "$profiles_dir" "$install_type" "$target_name"

                # Remove the directory
                if [[ -d "$full_path" ]]; then
                    rm -rf "$full_path"
                    success "Removed profile directory: $full_path"
                fi

                # Remove from profiles.ini (using temp file approach)
                local temp_ini
                temp_ini=$(mktemp)
                local skip=false
                while IFS= read -r line; do
                    if [[ "$line" =~ ^\[Profile ]]; then
                        skip=false
                    fi
                    if [[ "$skip" == "false" ]]; then
                        echo "$line"
                    fi
                    if [[ "$line" == "Name=$target_name" ]]; then
                        skip=true
                        # Remove the [ProfileN] header we just wrote
                        sed -i '$ d' "$temp_ini" 2>/dev/null || true
                    fi
                done < "$ini_file" > "$temp_ini"
                mv "$temp_ini" "$ini_file"

                success "Profile '$target_name' deleted from $install_type $APP_NAME"
            fi
            break
        fi
    done < <(parse_profiles_ini "$ini_file")

    if [[ "$found" == "false" ]]; then
        error "Profile '$target_name' not found in $install_type $APP_NAME"
    fi
}

# Reset a profile (clean but keep important data)
reset_profile() {
    local profiles_dir="$1"
    local install_type="$2"
    local target_name="$3"
    local ini_file="$profiles_dir/profiles.ini"

    if [[ -z "$target_name" ]]; then
        error "Profile name required"
        return 1
    fi

    while IFS='|' read -r name path is_relative is_default; do
        if [[ "$name" == "$target_name" ]]; then
            local full_path
            full_path=$(resolve_profile_path "$profiles_dir" "$path" "$is_relative")

            if [[ ! -d "$full_path" ]]; then
                error "Profile directory not found: $full_path"
                return 1
            fi

            echo -e "\n${YELLOW}Reset will:${NC}"
            echo "  - Backup the profile first"
            echo "  - Remove cache, sessions, site data, cookies"
            echo "  - Keep: bookmarks, passwords, certificates, extensions, preferences"
            echo ""

            if confirm "Reset $install_type profile '$name'?"; then
                # Backup first
                backup_profile "$profiles_dir" "$install_type" "$target_name"

                # Remove resettable data
                safe_remove "$full_path/cache2" "cache"
                safe_remove "$full_path/startupCache" "startup cache"
                safe_remove "$full_path/shader-cache" "shader cache"
                safe_remove "$full_path/thumbnails" "thumbnails"
                safe_remove "$full_path/sessionstore-backups" "session backups"
                safe_remove "$full_path/storage/temporary" "temporary storage"
                safe_remove "$full_path/datareporting" "telemetry data"
                safe_remove "$full_path/saved-telemetry-pings" "telemetry pings"
                safe_remove "$full_path/minidumps" "crash dumps"
                safe_remove "$full_path/Crash Reports" "crash reports"
                safe_remove "$full_path/webappsstore.sqlite" "web app storage"
                safe_remove "$full_path/cookies.sqlite" "cookies"
                safe_remove "$full_path/cookies.sqlite-wal" "cookies WAL"
                safe_remove "$full_path/content-prefs.sqlite" "content prefs"
                safe_remove "$full_path/formhistory.sqlite" "form history"
                safe_remove "$full_path/permissions.sqlite" "site permissions"
                safe_remove_glob "$full_path" "*.sqlite-shm" "shared memory files"
                safe_remove_glob "$full_path" "*.sqlite-wal" "WAL files"

                success "Profile '$name' has been reset!"
                info "Preserved: bookmarks (places.sqlite), passwords (logins.json, key4.db),"
                info "          certificates (cert9.db), extensions, and preferences (prefs.js)"
            fi
            return 0
        fi
    done < <(parse_profiles_ini "$ini_file")

    error "Profile '$target_name' not found in $install_type $APP_NAME"
}

# Run a command against available installations
run_for_installations() {
    local command="$1"
    shift
    local ran=false

    if [[ "$FLATPAK_ONLY" != "true" ]] && [[ -d "$NATIVE_PROFILE_DIR" ]]; then
        "$command" "$NATIVE_PROFILE_DIR" "Native" "$@"
        ran=true
    fi

    if [[ "$NATIVE_ONLY" != "true" ]] && [[ -d "$FLATPAK_PROFILE_DIR" ]]; then
        "$command" "$FLATPAK_PROFILE_DIR" "Flatpak" "$@"
        ran=true
    fi

    if [[ "$ran" == "false" ]]; then
        warn "No $APP_NAME installations found"
    fi
}

# Restore a profile from a backup archive
restore_backup() {
    local backup_file="$1"

    if [[ -z "$backup_file" ]]; then
        # List available backups
        header "Available Backups"
        if [[ ! -d "$BACKUP_DIR" ]]; then
            warn "No backup directory found at $BACKUP_DIR"
            info "Create backups first with: $(basename "$0") backup"
            return 1
        fi

        local backups=()
        while IFS= read -r -d '' f; do
            backups+=("$f")
        done < <(find "$BACKUP_DIR" -name "${APP_NAME,,}-*.tar.gz" -print0 2>/dev/null | sort -z)

        if [[ ${#backups[@]} -eq 0 ]]; then
            warn "No backups found in $BACKUP_DIR"
            return 1
        fi

        echo "Available backups:"
        local i=1
        for b in "${backups[@]}"; do
            local bname
            bname=$(basename "$b")
            local bsize
            bsize=$(du -sh "$b" 2>/dev/null | cut -f1)
            local bdate
            bdate=$(stat -c '%y' "$b" 2>/dev/null | cut -d'.' -f1)
            printf "  ${BOLD}%2d)${NC} %-50s %s  %s\n" "$i" "$bname" "$bsize" "$bdate"
            i=$((i + 1))
        done
        echo ""
        read -rp "$(echo -e "${YELLOW}Enter backup number to restore (or 'q' to quit):${NC} ")" choice
        if [[ "$choice" == "q" || -z "$choice" ]]; then
            return 0
        fi
        if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#backups[@]} ]]; then
            error "Invalid selection"
            return 1
        fi
        backup_file="${backups[$((choice - 1))]}"
    fi

    if [[ ! -f "$backup_file" ]]; then
        error "Backup file not found: $backup_file"
        return 1
    fi

    # Determine which installation to restore to
    local target_dir=""
    if [[ "$FLATPAK_ONLY" == "true" ]] && [[ -d "$FLATPAK_PROFILE_DIR" ]]; then
        target_dir="$FLATPAK_PROFILE_DIR"
    elif [[ "$NATIVE_ONLY" == "true" ]] && [[ -d "$NATIVE_PROFILE_DIR" ]]; then
        target_dir="$NATIVE_PROFILE_DIR"
    elif [[ -d "$NATIVE_PROFILE_DIR" ]]; then
        target_dir="$NATIVE_PROFILE_DIR"
    elif [[ -d "$FLATPAK_PROFILE_DIR" ]]; then
        target_dir="$FLATPAK_PROFILE_DIR"
    else
        error "No $APP_NAME installation found to restore into"
        return 1
    fi

    # Show what's in the backup
    local backup_contents
    backup_contents=$(tar -tzf "$backup_file" 2>/dev/null | head -1)
    local profile_dirname
    profile_dirname=$(echo "$backup_contents" | cut -d'/' -f1)

    local backup_size
    backup_size=$(du -sh "$backup_file" 2>/dev/null | cut -f1)

    echo -e "\n${BOLD}Restore Details:${NC}"
    echo "  Archive: $(basename "$backup_file") ($backup_size)"
    echo "  Profile: $profile_dirname"
    echo "  Target:  $target_dir/"
    echo ""

    local target_profile="$target_dir/$profile_dirname"
    if [[ -d "$target_profile" ]]; then
        warn "Profile directory already exists: $target_profile"
        echo "  Restoring will REPLACE the existing profile."
        echo ""
    fi

    if confirm "Restore this backup?"; then
        # Remove existing profile if present
        if [[ -d "$target_profile" ]]; then
            rm -rf "$target_profile"
        fi

        # Extract
        tar -xzf "$backup_file" -C "$target_dir/" 2>/dev/null
        success "Restored profile to: $target_profile"

        # Check if profile is in profiles.ini
        local ini_file="$target_dir/profiles.ini"
        if [[ -f "$ini_file" ]]; then
            if ! grep -q "Path=$profile_dirname" "$ini_file" 2>/dev/null; then
                warn "Profile not found in profiles.ini — you may need to add it manually"
                info "Or run: $APP_NAME -P to use the built-in profile manager"
            fi
        fi
    fi
}

main() {
    parse_common_flags "$@" || { show_help; exit 0; }

    local command=""
    local target=""

    for arg in "$@"; do
        case "$arg" in
            --native-only)       NATIVE_ONLY=true ;;
            --flatpak-only)      FLATPAK_ONLY=true ;;
            --backup-dir)        :;;  # handled below
            -y|--yes|-h|--help)  ;;
            list|backup|create|delete|reset|info|restore)
                command="$arg" ;;
            *)
                # Check if previous arg was --backup-dir
                local prev=""
                for a in "$@"; do
                    if [[ "$prev" == "--backup-dir" ]]; then
                        BACKUP_DIR="$a"
                        prev="$a"
                        continue
                    fi
                    prev="$a"
                done
                # Otherwise it's the target profile name
                if [[ -z "$target" && "$arg" != "$BACKUP_DIR" ]]; then
                    target="$arg"
                fi
                ;;
        esac
    done

    if [[ -z "$command" ]]; then
        show_help
        exit 0
    fi

    # Check if Firefox is running for write operations
    if [[ "$command" != "list" && "$command" != "info" ]]; then
        if app_is_running "firefox"; then
            error "Firefox appears to be running. Please close it first."
            exit 1
        fi
    fi

    case "$command" in
        list)    run_for_installations list_profiles ;;
        info)    run_for_installations show_profile_info "$target" ;;
        backup)  run_for_installations backup_profile "$target" ;;
        create)  run_for_installations create_profile "$target" ;;
        delete)  run_for_installations delete_profile "$target" ;;
        reset)   run_for_installations reset_profile "$target" ;;
        restore) restore_backup "$target" ;;
        *)       show_help; exit 1 ;;
    esac
}

main "$@"
