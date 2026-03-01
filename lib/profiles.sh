#!/usr/bin/env bash
# profiles.sh - Shared profile discovery and management functions
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools
#
# Provides centralized profile parsing, discovery, and management
# for both Mozilla and Chromium-based browsers.

# Prevent double-sourcing
[[ -n "${_PROFILES_SH_LOADED:-}" ]] && return 0
_PROFILES_SH_LOADED=1

# ===========================================================================
# MOZILLA PROFILE DISCOVERY
# ===========================================================================

# Parse profiles.ini and return profile entries
# Usage: parse_profiles_ini "/path/to/profiles.ini"
# Output: Name|Path|IsRelative|Default (one per line)
parse_profiles_ini() {
    local ini_file="$1"
    [[ ! -f "$ini_file" ]] && return 1

    local name="" path="" is_relative="1" is_default="0"
    local in_profile=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%$'\r'}" # strip CR
        if [[ "$line" =~ ^\[Profile ]]; then
            if $in_profile && [[ -n "$name" && -n "$path" ]]; then
                echo "${name}|${path}|${is_relative}|${is_default}"
            fi
            in_profile=true
            name="" path="" is_relative="1" is_default="0"
        elif $in_profile; then
            case "$line" in
                Name=*)       name="${line#Name=}" ;;
                Path=*)       path="${line#Path=}" ;;
                IsRelative=*) is_relative="${line#IsRelative=}" ;;
                Default=1)    is_default="1" ;;
            esac
        fi
    done < "$ini_file"
    # Emit last profile
    if $in_profile && [[ -n "$name" && -n "$path" ]]; then
        echo "${name}|${path}|${is_relative}|${is_default}"
    fi
}

# Resolve a profile path (handles relative paths)
# Usage: resolve_profile_path "/base/dir" "path" "is_relative"
resolve_profile_path() {
    local base_dir="$1"
    local profile_path="$2"
    local is_relative="${3:-1}"

    if [[ "$is_relative" == "1" ]]; then
        echo "$base_dir/$profile_path"
    else
        echo "$profile_path"
    fi
}

# Find all profiles for a Mozilla browser across install types
# Usage: find_mozilla_profiles "FIREFOX" [install_filter]
# Output: install_type|profile_name|profile_path (one per line)
find_mozilla_profiles() {
    local browser="$1"
    local filter="${2:-}"
    local found=0

    local profiles_var="${browser}_PROFILES"
    local -n profiles_ref="$profiles_var"

    for install_type in "${!profiles_ref[@]}"; do
        # Apply install filter
        case "$filter" in
            native-only)  [[ "$install_type" != "native" ]] && continue ;;
            flatpak-only) [[ "$install_type" != "flatpak" ]] && continue ;;
            snap-only)    [[ "$install_type" != "snap" ]] && continue ;;
        esac

        local base_dir="${profiles_ref[$install_type]}"
        [[ ! -d "$base_dir" ]] && continue

        local ini_file="$base_dir/profiles.ini"
        if [[ -f "$ini_file" ]]; then
            while IFS='|' read -r name path is_relative is_default; do
                local full_path
                full_path=$(resolve_profile_path "$base_dir" "$path" "$is_relative")
                [[ ! -d "$full_path" ]] && continue
                echo "${install_type}|${name}|${full_path}"
                found=1
            done < <(parse_profiles_ini "$ini_file")
        else
            # Fallback: scan for profile directories
            while IFS= read -r -d '' pdir; do
                local pname
                pname=$(basename "$pdir")
                echo "${install_type}|${pname}|${pdir}"
                found=1
            done < <(find "$base_dir" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
        fi
    done

    [[ "$found" -eq 1 ]]
}

# ===========================================================================
# CHROMIUM PROFILE DISCOVERY
# ===========================================================================

# Find all profiles for a Chromium browser across install types
# Usage: find_chromium_profiles "CHROME" [install_filter]
# Output: install_type|profile_name|profile_path (one per line)
find_chromium_profiles() {
    local browser="$1"
    local filter="${2:-}"
    local found=0

    local profiles_var="${browser}_PROFILES"
    local -n profiles_ref="$profiles_var"

    for install_type in "${!profiles_ref[@]}"; do
        case "$filter" in
            native-only)  [[ "$install_type" != "native" ]] && continue ;;
            flatpak-only) [[ "$install_type" != "flatpak" ]] && continue ;;
            snap-only)    [[ "$install_type" != "snap" ]] && continue ;;
        esac

        local base_dir="${profiles_ref[$install_type]}"
        [[ ! -d "$base_dir" ]] && continue

        # Chromium profiles: Default, Profile 1, Profile 2, etc.
        for pdir in "$base_dir"/Default "$base_dir"/Profile\ *; do
            [[ -d "$pdir" ]] || continue
            local pname
            pname=$(basename "$pdir")
            echo "${install_type}|${pname}|${pdir}"
            found=1
        done
    done

    [[ "$found" -eq 1 ]]
}

# ===========================================================================
# UNIFIED PROFILE FINDER
# ===========================================================================

# Find profiles for any browser (auto-detects type)
# Usage: find_profiles "FIREFOX" [install_filter]
find_profiles() {
    local browser="$1"
    local filter="${2:-}"

    if is_mozilla_browser "$browser"; then
        find_mozilla_profiles "$browser" "$filter"
    elif is_chromium_browser "$browser"; then
        find_chromium_profiles "$browser" "$filter"
    else
        # Try Mozilla first, then Chromium
        find_mozilla_profiles "$browser" "$filter" 2>/dev/null || \
        find_chromium_profiles "$browser" "$filter" 2>/dev/null
    fi
}

# ===========================================================================
# PROFILE INFO FUNCTIONS
# ===========================================================================

# Get detailed info about a Mozilla profile
# Returns JSON-like key=value pairs
get_mozilla_profile_info() {
    local profile_path="$1"
    [[ ! -d "$profile_path" ]] && return 1

    local total_size cache_size data_size file_count last_modified
    local has_bookmarks=false has_passwords=false has_history=false has_extensions=false

    total_size=$(get_size_bytes "$profile_path")
    cache_size=0
    [[ -d "$profile_path/cache2" ]] && cache_size=$(get_size_bytes "$profile_path/cache2")
    data_size=$((total_size - cache_size))
    file_count=$(find "$profile_path" -type f 2>/dev/null | wc -l)
    last_modified=$(find "$profile_path" -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1 | cut -d. -f1)

    [[ -f "$profile_path/places.sqlite" ]] && {
        has_bookmarks=true
        has_history=true
    }
    [[ -f "$profile_path/key4.db" || -f "$profile_path/logins.json" ]] && has_passwords=true
    [[ -d "$profile_path/extensions" ]] && has_extensions=true

    echo "total_size=$total_size"
    echo "cache_size=$cache_size"
    echo "data_size=$data_size"
    echo "file_count=$file_count"
    echo "last_modified=${last_modified:-0}"
    echo "has_bookmarks=$has_bookmarks"
    echo "has_passwords=$has_passwords"
    echo "has_history=$has_history"
    echo "has_extensions=$has_extensions"
}

# Get detailed info about a Chromium profile
get_chromium_profile_info() {
    local profile_path="$1"
    [[ ! -d "$profile_path" ]] && return 1

    local total_size cache_size data_size file_count last_modified
    local has_bookmarks=false has_passwords=false has_history=false

    total_size=$(get_size_bytes "$profile_path")
    cache_size=0
    for cdir in Cache "Code Cache" GPUCache DawnCache; do
        [[ -d "$profile_path/$cdir" ]] && cache_size=$((cache_size + $(get_size_bytes "$profile_path/$cdir")))
    done
    data_size=$((total_size - cache_size))
    file_count=$(find "$profile_path" -type f 2>/dev/null | wc -l)
    last_modified=$(find "$profile_path" -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1 | cut -d. -f1)

    [[ -f "$profile_path/Bookmarks" ]] && has_bookmarks=true
    [[ -f "$profile_path/Login Data" ]] && has_passwords=true
    [[ -f "$profile_path/History" ]] && has_history=true

    echo "total_size=$total_size"
    echo "cache_size=$cache_size"
    echo "data_size=$data_size"
    echo "file_count=$file_count"
    echo "last_modified=${last_modified:-0}"
    echo "has_bookmarks=$has_bookmarks"
    echo "has_passwords=$has_passwords"
    echo "has_history=$has_history"
}

# ===========================================================================
# PROFILE BACKUP FUNCTIONS
# ===========================================================================

# Backup a profile to a tar.gz archive
# Usage: backup_profile "/path/to/profile" "/path/to/backup/dir" "profile_name" [--encrypt]
backup_profile() {
    local profile_path="$1"
    local backup_dir="$2"
    local profile_name="$3"
    local encrypt="${4:-false}"

    [[ ! -d "$profile_path" ]] && { error "Profile not found: $profile_path"; return 1; }

    mkdir -p "$backup_dir"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local archive_name="${profile_name}_${timestamp}.tar.gz"
    local archive_path="$backup_dir/$archive_name"

    info "Backing up profile '$profile_name'..."
    local parent_dir
    parent_dir=$(dirname "$profile_path")
    local dir_name
    dir_name=$(basename "$profile_path")

    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run "Would create backup: $archive_path"
        return 0
    fi

    tar -czf "$archive_path" -C "$parent_dir" "$dir_name" 2>/dev/null
    local archive_size
    archive_size=$(get_size "$archive_path")

    # Optionally encrypt with GPG
    if [[ "$encrypt" == "true" || "$encrypt" == "--encrypt" ]]; then
        if command -v gpg &>/dev/null; then
            info "Encrypting backup with GPG..."
            gpg --symmetric --cipher-algo AES256 --batch --yes \
                --output "${archive_path}.gpg" "$archive_path" && {
                rm -f "$archive_path"
                archive_path="${archive_path}.gpg"
                success "Encrypted backup created: $archive_path ($archive_size)"
                return 0
            }
            warn "GPG encryption failed, keeping unencrypted backup"
        else
            warn "GPG not available, skipping encryption"
        fi
    fi

    success "Backup created: $archive_path ($archive_size)"

    # Warn about sensitive data in unencrypted backups
    if [[ -f "$profile_path/key4.db" || -f "$profile_path/logins.json" || -f "$profile_path/Login Data" ]]; then
        warn "Backup contains password data. Consider using --encrypt for sensitive backups."
    fi
}

# Restore a profile from backup
# Usage: restore_profile "/path/to/backup.tar.gz" "/path/to/target"
restore_profile() {
    local archive_path="$1"
    local target_dir="$2"

    [[ ! -f "$archive_path" ]] && { error "Backup not found: $archive_path"; return 1; }

    # Handle encrypted backups
    if [[ "$archive_path" == *.gpg ]]; then
        if ! command -v gpg &>/dev/null; then
            error "GPG required to decrypt backup"
            return 1
        fi
        local decrypted="${archive_path%.gpg}"
        info "Decrypting backup..."
        gpg --decrypt --batch --output "$decrypted" "$archive_path" || {
            error "Decryption failed"
            return 1
        }
        archive_path="$decrypted"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run "Would restore backup to: $target_dir"
        return 0
    fi

    mkdir -p "$target_dir"
    tar -xzf "$archive_path" -C "$target_dir" 2>/dev/null
    local size
    size=$(get_size "$target_dir")
    success "Restored profile to: $target_dir ($size)"
}

# List available backups for a browser
# Usage: list_backups "/path/to/backup/dir"
list_backups() {
    local backup_dir="$1"
    [[ ! -d "$backup_dir" ]] && { info "No backups found in $backup_dir"; return 1; }

    local count=0
    while IFS= read -r -d '' archive; do
        local name size date
        name=$(basename "$archive")
        size=$(get_size "$archive")
        date=$(stat -c '%y' "$archive" 2>/dev/null | cut -d. -f1)
        echo "  $name ($size, $date)"
        ((count++))
    done < <(find "$backup_dir" -name "*.tar.gz" -o -name "*.tar.gz.gpg" -print0 2>/dev/null | sort -z)

    [[ "$count" -eq 0 ]] && info "No backups found in $backup_dir"
    return 0
}
