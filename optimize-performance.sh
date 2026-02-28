#!/usr/bin/env bash
# optimize-performance.sh - Apply performance-tuning settings to Firefox/Floorp
# Generates and applies a user.js with performance-optimized preferences
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

# Optimization levels
LEVEL="balanced"
TARGET_BROWSER=""
TARGET_PROFILE=""
DRY_RUN=false
AUTO_YES=false
BACKUP=true

show_help() {
    cat <<EOF
${BOLD}Performance Optimization Tool${NC}

Apply performance-tuning user.js settings to Firefox and Floorp profiles.
Creates a backup of existing user.js before applying changes.

Usage: $(basename "$0") <command> [OPTIONS]

Commands:
  apply                Apply performance settings to a profile
  show                 Display the settings that would be applied
  status               Show current performance-relevant prefs in a profile
  revert               Restore the original user.js from backup
  benchmark            Quick responsiveness/memory check of running browser

Levels:
  --balanced           Moderate optimizations, safe for all hardware (default)
  --aggressive         Push limits for faster rendering and lower latency
  --low-ram            Optimize for systems with ≤ 4 GB RAM

Options:
  --browser <name>     Target browser: firefox or floorp (default: both)
  --profile <name>     Target a specific profile (default: all)
  --no-backup          Don't backup existing user.js before applying
  -n, --dry-run        Show what would be applied without changing anything
  -y, --yes            Skip confirmation prompts
  -h, --help           Show this help message

Examples:
  $(basename "$0") show                            # Preview balanced settings
  $(basename "$0") show --aggressive               # Preview aggressive settings
  $(basename "$0") apply                           # Apply balanced to all profiles
  $(basename "$0") apply --aggressive --browser firefox
  $(basename "$0") apply --low-ram                 # Optimise for low memory
  $(basename "$0") status                          # Check current perf prefs
  $(basename "$0") benchmark                       # Quick browser benchmark
  $(basename "$0") revert                          # Restore backups
EOF
}

# ---- Performance settings by level ----

generate_user_js() {
    local level="$1"

    cat <<'HEADER'
// ============================================================
// Browser Cleanup Tools — Performance Optimization user.js
// https://github.com/chiefgyk3d/Browser_Cleanup_Tools
//
// Auto-generated. To revert, restore user.js.perf-backup or delete
// user.js and restart the browser.
// ============================================================

HEADER

    # ----- Balanced settings (applied at all levels) -----
    cat <<'BALANCED'
// --- BALANCED PERFORMANCE ---

// ── Rendering & Compositing ──
// Enable hardware-accelerated compositing (WebRender)
user_pref("gfx.webrender.all", true);
user_pref("gfx.webrender.enabled", true);

// Prefer GPU compositing
user_pref("layers.acceleration.force-enabled", true);
user_pref("layers.gpu-process.enabled", true);
user_pref("media.hardware-video-decoding.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
user_pref("media.ffmpeg.vaapi.enabled", true);

// ── Network & Loading ──
// Increase concurrent connections (default 6 per server, 256 total)
user_pref("network.http.max-persistent-connections-per-server", 10);
user_pref("network.http.max-persistent-connections-per-proxy", 32);

// Faster TLS handshake
user_pref("security.ssl.enable_false_start", true);
user_pref("network.ssl_tokens_cache_capacity", 32768);

// Enable HTTP/3 (QUIC)
user_pref("network.http.http3.enabled", true);

// Optimise DNS
user_pref("network.dnsCacheEntries", 1000);
user_pref("network.dnsCacheExpiration", 3600);
user_pref("network.dns.disablePrefetchFromHTTPS", false);
user_pref("network.dns.disablePrefetch", false);
user_pref("network.predictor.enabled", true);

// Enable link prefetching for faster navigation
user_pref("network.prefetch-next", true);

// ── Content Process & Threading ──
// Use more content processes for better tab isolation (max 8)
user_pref("dom.ipc.processCount", 8);

// Enable Fission (site isolation — also improves perf for multi-core)
user_pref("fission.autostart", true);

// ── JavaScript Engine ──
// Enable all JIT tiers for maximum JS performance
user_pref("javascript.options.baselinejit", true);
user_pref("javascript.options.ion", true);
user_pref("javascript.options.wasm", true);
user_pref("javascript.options.wasm_baselinejit", true);
user_pref("javascript.options.wasm_optimizedjit", true);

// ── UI Responsiveness ──
// Reduce UI paint delay for snappier feel
user_pref("nglayout.initialpaint.delay", 0);
user_pref("nglayout.initialpaint.delay_in_oopif", 0);

// Prioritize UI thread
user_pref("content.notify.interval", 100000);

// Faster session restore
user_pref("browser.sessionstore.interval", 30000);

// ── Cache ──
// Use disk cache with reasonable limits
user_pref("browser.cache.disk.enable", true);
user_pref("browser.cache.memory.enable", true);

// Decode images immediately instead of on-demand
user_pref("image.mem.decode_bytes_at_a_time", 65536);

// ── Smooth Scrolling ──
user_pref("general.smoothScroll", true);
user_pref("general.smoothScroll.msdPhysics.enabled", true);
user_pref("general.smoothScroll.msdPhysics.continuousMotionMaxDeltaMS", 250);
user_pref("general.smoothScroll.msdPhysics.motionBeginSpringConstant", 400);
user_pref("general.smoothScroll.msdPhysics.regularSpringConstant", 400);
user_pref("general.smoothScroll.msdPhysics.slowdownMinDeltaMS", 120);
user_pref("general.smoothScroll.msdPhysics.slowdownSpringConstant", 5000);
user_pref("general.smoothScroll.currentVelocityWeighting", "0.12");
user_pref("general.smoothScroll.stopDecelerationWeighting", "0.6");

// ── Disable unnecessary features that waste cycles ──
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("app.normandy.enabled", false);
user_pref("browser.ping-centre.telemetry", false);

// Disable Pocket
user_pref("extensions.pocket.enabled", false);

// Disable UI animations for snappier feel
user_pref("toolkit.cosmeticAnimations.enabled", false);
BALANCED

    # ----- Aggressive settings -----
    if [[ "$level" == "aggressive" ]]; then
        cat <<'AGGRESSIVE'

// --- AGGRESSIVE PERFORMANCE ---

// ── Network: push the limits ──
// More aggressive prefetching and speculative connections
user_pref("network.http.speculative-parallel-limit", 20);
user_pref("network.http.pacing.requests.enabled", false);
user_pref("network.http.max-connections", 1800);

// Larger network buffer
user_pref("network.buffer.cache.size", 262144);
user_pref("network.buffer.cache.count", 128);

// Pipeline-style optimization (connection reuse)
user_pref("network.http.request.max-start-delay", 0);

// ── Rendering: maximum throughput ──
// Increase paint frequency
user_pref("layout.frame_rate", -1);

// Larger image cache (256 MB)
user_pref("image.cache.size", 268435456);
user_pref("image.mem.decode_bytes_at_a_time", 131072);
user_pref("image.mem.surfacecache.max_size_kb", 2097152);

// Decode images off main thread
user_pref("image.mem.shared.unmap.min_expiration_ms", 120000);

// Increase GFX buffer sizes
user_pref("gfx.canvas.accelerated.cache-size", 4096);
user_pref("gfx.content.skia-font-cache-size", 80);

// ── JavaScript: max JIT ──
// Increase JIT thresholds and enable optimizations
user_pref("javascript.options.mem.high_water_mark", 256);
user_pref("javascript.options.mem.gc_incremental_slice_ms", 10);

// ── Media ──
// Enable AV1 hardware decode if available
user_pref("media.av1.enabled", true);

// Use more threads for media decoding
user_pref("media.rdd-process.enabled", true);
user_pref("media.utility-process.enabled", true);

// ── Session Store: less frequent writes ──
user_pref("browser.sessionstore.interval", 60000);

// ── Disable more UI overhead ──
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.highlights", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);

// Disable accessibility services detection (slight overhead)
user_pref("accessibility.force_disabled", 1);

// Skip intro and what's-new pages
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("startup.homepage_welcome_url", "");
AGGRESSIVE
    fi

    # ----- Low-RAM settings -----
    if [[ "$level" == "low-ram" ]]; then
        cat <<'LOWRAM'

// --- LOW-RAM OPTIMIZATION (≤ 4 GB) ---

// ── Memory Management ──
// Reduce content processes (each uses ~150-300 MB)
user_pref("dom.ipc.processCount", 4);

// Lower memory cache (32 MB instead of auto)
user_pref("browser.cache.memory.capacity", 32768);
user_pref("browser.cache.memory.max_entry_size", 2048);

// Smaller disk cache (256 MB)
user_pref("browser.cache.disk.capacity", 262144);

// Smaller image cache (64 MB)
user_pref("image.cache.size", 67108864);
user_pref("image.mem.surfacecache.max_size_kb", 131072);
user_pref("image.mem.decode_bytes_at_a_time", 32768);

// ── Aggressive garbage collection ──
user_pref("javascript.options.mem.high_water_mark", 64);
user_pref("javascript.options.mem.gc_incremental_slice_ms", 5);
user_pref("javascript.options.mem.gc_max_empty_chunk_count", 5);

// Free memory on minimize
user_pref("browser.tabs.unloadOnLowMemory", true);

// ── Tab management ──
// Unload background tabs more aggressively
user_pref("browser.tabs.min_inactive_duration_before_unload", 300000);

// ── Reduce network memory usage ──
user_pref("network.buffer.cache.size", 32768);
user_pref("network.buffer.cache.count", 24);
user_pref("network.http.max-connections", 512);
user_pref("network.http.max-persistent-connections-per-server", 6);
user_pref("network.http.speculative-parallel-limit", 4);

// Reduce DNS cache
user_pref("network.dnsCacheEntries", 400);

// ── Session Store: reduce memory pressure ──
user_pref("browser.sessionstore.interval", 60000);
user_pref("browser.sessionstore.max_tabs_undo", 5);
user_pref("browser.sessionstore.max_windows_undo", 1);

// ── Disable heavy features ──
user_pref("media.hardware-video-decoding.enabled", true);
user_pref("accessibility.force_disabled", 1);
user_pref("extensions.pocket.enabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("toolkit.cosmeticAnimations.enabled", false);

// ── Compact mode ──
user_pref("browser.uidensity", 1);

// ── Prefetching: off to save memory ──
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);
LOWRAM
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
        local backup_name="$user_js.perf-backup.$(date +%Y%m%d_%H%M%S)"
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "${MAGENTA}[DRY-RUN]${NC} Would backup $user_js → $backup_name"
        else
            cp "$user_js" "$backup_name"
            success "Backed up existing user.js → $(basename "$backup_name")"
        fi
    fi

    # Check for existing privacy hardening
    if [[ -f "$user_js" ]] && grep -q "Privacy Hardening" "$user_js" 2>/dev/null; then
        warn "Profile $profile_name has privacy hardening applied."
        warn "Performance settings will be appended. Some prefs may overlap."
        echo -e "${DIM}  Tip: Review with 'status' command after applying.${NC}"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${MAGENTA}[DRY-RUN]${NC} Would write ${level} performance settings to $user_js"
    else
        # If privacy hardening exists, append instead of overwrite
        if [[ -f "$user_js" ]] && grep -q "Privacy Hardening\|Performance Optimization" "$user_js" 2>/dev/null; then
            # Remove old performance section if present, keep everything else
            local temp_file
            temp_file=$(mktemp)
            if grep -q "Performance Optimization" "$user_js" 2>/dev/null; then
                # Strip old performance block and append new one
                sed '/Browser Cleanup Tools — Performance Optimization/,/^$/d' "$user_js" > "$temp_file" 2>/dev/null || cp "$user_js" "$temp_file"
                mv "$temp_file" "$user_js"
            fi
            # Append performance settings
            echo "" >> "$user_js"
            generate_user_js "$level" >> "$user_js"
        else
            generate_user_js "$level" > "$user_js"
        fi
        success "Applied ${level} performance settings to profile: $profile_name"
    fi
}

# ---- Show current performance prefs ----

show_profile_status() {
    local profile_dir="$1"
    local profile_name
    profile_name=$(basename "$profile_dir")

    local prefs_file="$profile_dir/prefs.js"
    local user_file="$profile_dir/user.js"

    echo -e "  ${BOLD}Profile: $profile_name${NC}"

    # Check if our perf user.js is applied
    if [[ -f "$user_file" ]] && grep -q "Performance Optimization" "$user_file" 2>/dev/null; then
        local level="unknown"
        grep -q "LOW-RAM OPTIMIZATION" "$user_file" && level="low-ram"
        [[ "$level" == "unknown" ]] && grep -q "AGGRESSIVE PERFORMANCE" "$user_file" && level="aggressive"
        [[ "$level" == "unknown" ]] && grep -q "BALANCED PERFORMANCE" "$user_file" && level="balanced"
        echo -e "    Optimization: ${GREEN}applied${NC} (${level})"
    elif [[ -f "$user_file" ]]; then
        echo -e "    Optimization: ${YELLOW}custom user.js present${NC}"
    else
        echo -e "    Optimization: ${DIM}not applied${NC}"
    fi

    # Check key performance prefs
    if [[ -f "$prefs_file" || -f "$user_file" ]]; then
        local checks=(
            "gfx.webrender.all|WebRender (GPU)|true"
            "layers.acceleration.force-enabled|GPU Acceleration|true"
            "media.hardware-video-decoding.enabled|HW Video Decode|true"
            "media.ffmpeg.vaapi.enabled|VA-API (Linux)|true"
            "dom.ipc.processCount|Content Processes|8"
            "fission.autostart|Fission (Site Isolation)|true"
            "javascript.options.ion|IonMonkey JIT|true"
            "network.http.http3.enabled|HTTP/3 (QUIC)|true"
            "general.smoothScroll.msdPhysics.enabled|Smooth Scrolling|true"
            "toolkit.cosmeticAnimations.enabled|UI Animations|false"
            "browser.cache.memory.enable|Memory Cache|true"
            "browser.sessionstore.interval|Session Save Interval|30000"
        )

        for check in "${checks[@]}"; do
            IFS='|' read -r pref_name label desired <<< "$check"
            local current="default"

            # Check prefs.js first, then user.js overrides
            if [[ -f "$prefs_file" ]]; then
                local val
                val=$(grep -oP "user_pref\\(\"$pref_name\",\\s*\\K[^)]*" "$prefs_file" 2>/dev/null | tr -d ' "' || echo "")
                [[ -n "$val" ]] && current="$val"
            fi
            if [[ -f "$user_file" ]]; then
                local val
                val=$(grep -oP "user_pref\\(\"$pref_name\",\\s*\\K[^)]*" "$user_file" 2>/dev/null | tr -d ' "' || echo "")
                [[ -n "$val" ]] && current="$val"
            fi

            if [[ "$current" == "$desired" ]]; then
                echo -e "    ${GREEN}✓${NC} $label: $current"
            elif [[ "$current" == "default" ]]; then
                echo -e "    ${DIM}○${NC} $label: ${DIM}default${NC} ${DIM}(recommended: $desired)${NC}"
            else
                echo -e "    ${YELLOW}✗${NC} $label: $current ${DIM}(recommended: $desired)${NC}"
            fi
        done
    else
        echo -e "    ${DIM}No prefs.js found${NC}"
    fi

    # Show memory info for context
    if [[ -f "/proc/meminfo" ]]; then
        local total_mem_kb
        total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        local total_mem_gb
        total_mem_gb=$(echo "scale=1; $total_mem_kb / 1048576" | bc)
        echo -e "    ${DIM}System RAM: ${total_mem_gb} GB${NC}"
        if [[ "$total_mem_kb" -lt 4194304 ]]; then
            echo -e "    ${YELLOW}Tip: Consider --low-ram level for this system${NC}"
        fi
    fi
    echo ""
}

# ---- Revert ----

revert_profile() {
    local profile_dir="$1"
    local profile_name
    profile_name=$(basename "$profile_dir")

    local user_js="$profile_dir/user.js"

    # Find the most recent performance backup
    local latest_backup=""
    for backup in "$profile_dir"/user.js.perf-backup.*; do
        [[ -f "$backup" ]] && latest_backup="$backup"
    done

    if [[ -n "$latest_backup" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "${MAGENTA}[DRY-RUN]${NC} Would restore $(basename "$latest_backup") → user.js in $profile_name"
        else
            cp "$latest_backup" "$user_js"
            success "Restored user.js from $(basename "$latest_backup") in profile: $profile_name"
        fi
    elif [[ -f "$user_js" ]] && grep -q "Performance Optimization" "$user_js" 2>/dev/null; then
        # If combined with privacy hardening, only strip perf section
        if grep -q "Privacy Hardening" "$user_js" 2>/dev/null; then
            if [[ "$DRY_RUN" == "true" ]]; then
                echo -e "${MAGENTA}[DRY-RUN]${NC} Would remove performance section from user.js in $profile_name (keeping privacy)"
            else
                local temp_file
                temp_file=$(mktemp)
                # Remove everything from the performance header onward
                sed '/Browser Cleanup Tools — Performance Optimization/,$d' "$user_js" > "$temp_file"
                mv "$temp_file" "$user_js"
                success "Removed performance settings from profile: $profile_name (privacy settings preserved)"
            fi
        else
            if [[ "$DRY_RUN" == "true" ]]; then
                echo -e "${MAGENTA}[DRY-RUN]${NC} Would remove user.js from $profile_name (no backup found)"
            else
                rm "$user_js"
                success "Removed user.js from profile: $profile_name (no backup to restore)"
            fi
        fi
    else
        info "No performance settings found in profile: $profile_name"
    fi
}

# ---- Benchmark ----

do_benchmark() {
    header "Quick Browser Benchmark"

    # System info
    echo -e "${BOLD}System Information${NC}"
    if [[ -f "/proc/cpuinfo" ]]; then
        local cpu_model
        cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        local cpu_cores
        cpu_cores=$(nproc 2>/dev/null || echo "?")
        echo -e "  CPU: $cpu_model ($cpu_cores cores)"
    fi
    if [[ -f "/proc/meminfo" ]]; then
        local total_mem avail_mem used_pct
        total_mem=$(awk '/MemTotal/{print $2}' /proc/meminfo)
        avail_mem=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
        used_pct=$(( ((total_mem - avail_mem) * 100) / total_mem ))
        echo -e "  RAM: $(echo "scale=1; $total_mem/1048576" | bc)G total, $(echo "scale=1; $avail_mem/1048576" | bc)G available (${used_pct}% used)"
        if [[ "$total_mem" -lt 4194304 ]]; then
            echo -e "  ${YELLOW}⚠ Low RAM — consider --low-ram optimization level${NC}"
        fi
    fi

    # GPU info
    if command -v lspci &>/dev/null; then
        local gpu
        gpu=$(lspci 2>/dev/null | grep -i "vga\|3d\|display" | head -1 | sed 's/.*: //')
        [[ -n "$gpu" ]] && echo -e "  GPU: $gpu"
    fi

    # Check for VA-API
    if command -v vainfo &>/dev/null; then
        local vaapi_profiles
        vaapi_profiles=$(vainfo 2>/dev/null | grep -c "VAProfile" || echo "0")
        if [[ "$vaapi_profiles" -gt 0 ]]; then
            echo -e "  VA-API: ${GREEN}available${NC} ($vaapi_profiles profiles)"
        else
            echo -e "  VA-API: ${YELLOW}not working${NC}"
        fi
    else
        echo -e "  VA-API: ${DIM}vainfo not installed${NC}"
    fi
    echo ""

    # Browser processes
    echo -e "${BOLD}Running Browsers${NC}"
    local found_browser=false

    for proc in firefox floorp chromium brave chrome; do
        local pids
        pids=$(pgrep -x "$proc" 2>/dev/null || pgrep -f "$proc" 2>/dev/null | head -20)
        [[ -z "$pids" ]] && continue
        found_browser=true

        local proc_count mem_total_kb=0 cpu_total=0
        proc_count=$(echo "$pids" | wc -l)

        while read -r pid; do
            [[ -z "$pid" ]] && continue
            if [[ -f "/proc/$pid/status" ]]; then
                local rss
                rss=$(awk '/VmRSS/{print $2}' "/proc/$pid/status" 2>/dev/null || echo "0")
                mem_total_kb=$((mem_total_kb + rss))
            fi
            local cpu
            cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | xargs || echo "0")
            cpu_total=$(echo "$cpu_total + $cpu" | bc 2>/dev/null || echo "$cpu_total")
        done <<< "$pids"

        local mem_human
        if [[ "$mem_total_kb" -ge 1048576 ]]; then
            mem_human="$(echo "scale=1; $mem_total_kb / 1048576" | bc)G"
        elif [[ "$mem_total_kb" -ge 1024 ]]; then
            mem_human="$(echo "scale=0; $mem_total_kb / 1024" | bc)M"
        else
            mem_human="${mem_total_kb}K"
        fi

        local mem_color="$GREEN"
        [[ "$mem_total_kb" -gt 2097152 ]] && mem_color="$YELLOW"  # > 2GB
        [[ "$mem_total_kb" -gt 4194304 ]] && mem_color="$RED"     # > 4GB

        echo -e "  ${BOLD}$proc${NC}: $proc_count processes, ${mem_color}${mem_human} RAM${NC}, ${cpu_total}% CPU"
    done

    if [[ "$found_browser" == "false" ]]; then
        info "No browsers currently running"
    fi
    echo ""

    # Recommendations
    echo -e "${BOLD}Recommendations${NC}"
    if [[ -f "/proc/meminfo" ]]; then
        local total_mem
        total_mem=$(awk '/MemTotal/{print $2}' /proc/meminfo)
        if [[ "$total_mem" -lt 4194304 ]]; then
            echo -e "  ${CYAN}●${NC} Use ${BOLD}--low-ram${NC} optimization level"
            echo -e "  ${CYAN}●${NC} Limit open tabs to < 20"
            echo -e "  ${CYAN}●${NC} Consider using fewer extensions"
        elif [[ "$total_mem" -lt 8388608 ]]; then
            echo -e "  ${CYAN}●${NC} Use ${BOLD}--balanced${NC} optimization level"
            echo -e "  ${CYAN}●${NC} Keep extensions under control"
        else
            echo -e "  ${CYAN}●${NC} Use ${BOLD}--aggressive${NC} for maximum performance"
            echo -e "  ${CYAN}●${NC} Plenty of RAM for many tabs and extensions"
        fi
    fi

    # Check if VA-API is enabled in Firefox prefs
    local suggest_vaapi=false
    if command -v vainfo &>/dev/null && vainfo &>/dev/null; then
        for base in "${FIREFOX_PATHS[@]}" "${FLOORP_PATHS[@]}"; do
            [[ ! -d "$base" ]] && continue
            local ini="$base/profiles.ini"
            [[ ! -f "$ini" ]] && continue
            while IFS= read -r line; do
                if [[ "$line" =~ ^Path= ]]; then
                    local rel="${line#Path=}"
                    local pdir
                    [[ "$rel" == /* ]] && pdir="$rel" || pdir="$base/$rel"
                    if [[ -f "$pdir/prefs.js" ]]; then
                        if ! grep -q '"media.ffmpeg.vaapi.enabled", true' "$pdir/prefs.js" 2>/dev/null; then
                            suggest_vaapi=true
                        fi
                    fi
                fi
            done < "$ini"
        done
    fi
    if [[ "$suggest_vaapi" == "true" ]]; then
        echo -e "  ${YELLOW}●${NC} VA-API available but not enabled — apply optimization to enable HW video decode"
    fi
    echo ""
    echo -e "${DIM}Apply settings: $(basename "$0") apply [--balanced|--aggressive|--low-ram]${NC}"
}

# ---- Main ----

main() {
    local command=""

    for arg in "$@"; do
        case "$arg" in
            apply|show|status|revert|benchmark) command="$arg" ;;
            --balanced)    LEVEL="balanced" ;;
            --aggressive)  LEVEL="aggressive" ;;
            --low-ram)     LEVEL="low-ram" ;;
            --no-backup)   BACKUP=false ;;
            -n|--dry-run)  DRY_RUN=true ;;
            -y|--yes)      AUTO_YES=true ;;
            -h|--help)     show_help; exit 0 ;;
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
            header "Performance Settings (${LEVEL})"
            generate_user_js "$LEVEL"
            ;;
        apply)
            header "Applying ${LEVEL} Performance Optimization"
            echo -e "${BOLD}Level: ${LEVEL}${NC}"
            case "$LEVEL" in
                balanced)   echo -e "Moderate optimizations, safe for all hardware\n" ;;
                aggressive) echo -e "${YELLOW}Pushing limits — max rendering and network performance${NC}\n" ;;
                low-ram)    echo -e "${CYAN}Optimized for systems with ≤ 4 GB RAM${NC}\n" ;;
            esac

            if [[ "$AUTO_YES" != "true" && "$DRY_RUN" != "true" ]]; then
                confirm "Apply ${LEVEL} performance settings?" || { info "Cancelled."; exit 0; }
            fi

            local applied=0

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
            header "Performance Status"

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
            header "Reverting Performance Optimization"

            if [[ "$AUTO_YES" != "true" && "$DRY_RUN" != "true" ]]; then
                confirm "Revert performance settings (restore original user.js)?" || { info "Cancelled."; exit 0; }
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
        benchmark)
            do_benchmark
            ;;
        *)
            show_help
            exit 0
            ;;
    esac
}

main "$@"
