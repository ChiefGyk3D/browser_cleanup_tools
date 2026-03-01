#!/usr/bin/env bash
# optimize-performance.sh - Apply performance-tuning settings to Mozilla browsers
# Generates and applies a user.js with performance-optimized preferences
# Incorporates settings from Betterfox Fastfox/Smoothfox and nvidia-capture-card
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/paths.sh"
source "$SCRIPT_DIR/lib/profiles.sh"
source "$SCRIPT_DIR/lib/config.sh"

# Optimization levels
LEVEL="${DEFAULT_PERF_LEVEL:-balanced}"
TARGET_BROWSER=""
TARGET_PROFILE=""
BACKUP=true
SCROLL_PRESET="${SCROLL_STYLE:-sharpen}"
GPU_TWEAKS="${ENABLE_GPU_TWEAKS:-auto}"

show_help() {
    cat <<EOF
${BOLD}Performance Optimization Tool${NC}

Apply performance-tuning user.js settings to Mozilla browser profiles.
Supports Firefox, Floorp, LibreWolf, Waterfox, and Zen Browser.
Incorporates Betterfox Fastfox/Smoothfox and GPU acceleration from nvidia-capture-card.

Usage: $(basename "$0") <command> [OPTIONS]

Commands:
  apply                Apply performance settings to a profile
  show                 Display the settings that would be applied
  status               Show current performance-relevant prefs in a profile
  revert               Restore the original user.js from backup
  benchmark            Quick responsiveness/memory check of running browser
  gpu-info             Show detected GPU and recommended settings
  launch-env           Print env vars for optimal browser launch (source-able)

Levels:
  --balanced           Moderate optimizations, safe for all hardware (default)
  --aggressive         Push limits for faster rendering and lower latency
  --low-ram            Optimize for systems with ≤ 4 GB RAM

Scroll Presets (from Betterfox Smoothfox):
  --scroll-sharpen     Sharpen scrolling (default) — crisp, minimal inertia
  --scroll-instant     Instant scrolling — no smooth, 60Hz+
  --scroll-smooth      Smooth scrolling — 90Hz+ msdPhysics
  --scroll-natural     Natural smooth V3 — 120Hz+, Chrome-like feel

Options:
  --browser <name>     Target browser: firefox, floorp, librewolf, waterfox, zen
  --profile <name>     Target a specific profile (default: all)
  --gpu-tweaks         Force enable GPU/NVIDIA optimizations
  --no-gpu-tweaks      Disable GPU/NVIDIA optimizations
  --no-backup          Don't backup existing user.js before applying
  -n, --dry-run        Show what would be applied without changing anything
  -y, --yes            Skip confirmation prompts
  -V, --version        Show version
  -h, --help           Show this help message

Examples:
  $(basename "$0") show                            # Preview balanced settings
  $(basename "$0") apply --aggressive --scroll-natural
  $(basename "$0") apply --low-ram --browser firefox
  $(basename "$0") gpu-info                        # Check GPU detection
  $(basename "$0") launch-env                      # Get NVIDIA launch env vars
  $(basename "$0") benchmark                       # Quick browser benchmark
EOF
}

# ---- Performance settings by level ----

generate_user_js() {
    local level="$1"

    cat <<'HEADER'
// ============================================================
// Browser Cleanup Tools — Performance Optimization user.js
// https://github.com/chiefgyk3d/Browser_Cleanup_Tools
// Incorporates Betterfox Fastfox/Smoothfox + nvidia-capture-card GPU tuning
//
// Auto-generated. To revert, restore user.js.perf-backup or delete
// user.js and restart the browser.
// ============================================================

HEADER

    # ----- Balanced settings (applied at all levels) -----
    cat <<'BALANCED'
// --- BALANCED PERFORMANCE ---

// ── Rendering & Compositing [Betterfox Fastfox + nvidia-capture-card] ──
user_pref("gfx.webrender.all", true);
user_pref("gfx.webrender.enabled", true);
user_pref("gfx.webrender.precache-shaders", true);
user_pref("gfx.webrender.layer-compositor", true);

// GPU acceleration
user_pref("layers.acceleration.force-enabled", true);
user_pref("layers.gpu-process.enabled", true);
user_pref("gfx.canvas.accelerated", true);

// Hardware video decoding
user_pref("media.hardware-video-decoding.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.rdd-process.enabled", true);
user_pref("media.av1.enabled", true);

// ── Network & Loading [Betterfox Fastfox] ──
user_pref("network.http.max-persistent-connections-per-server", 10);
user_pref("network.http.max-persistent-connections-per-proxy", 32);

// TLS session cache [Betterfox]
user_pref("security.ssl.enable_false_start", true);
user_pref("network.ssl_tokens_cache_capacity", 10240);

// HTTP/3 (QUIC)
user_pref("network.http.http3.enabled", true);

// DNS cache [Betterfox]
user_pref("network.dnsCacheEntries", 10000);
user_pref("network.dnsCacheExpiration", 3600);

// Prefetching (perf mode — enable for speed)
user_pref("network.dns.disablePrefetchFromHTTPS", false);
user_pref("network.dns.disablePrefetch", false);
user_pref("network.predictor.enabled", true);
user_pref("network.prefetch-next", true);

// ── Content Processes & Threading ──
user_pref("dom.ipc.processCount", 8);
user_pref("fission.autostart", true);

// ── JavaScript Engine — all JIT tiers ──
user_pref("javascript.options.baselinejit", true);
user_pref("javascript.options.ion", true);
user_pref("javascript.options.wasm", true);
user_pref("javascript.options.wasm_baselinejit", true);
user_pref("javascript.options.wasm_optimizingjit", true);

// ── UI Responsiveness [Betterfox Fastfox] ──
user_pref("nglayout.initialpaint.delay", 0);
user_pref("nglayout.initialpaint.delay_in_oopif", 0);
user_pref("content.notify.interval", 100000);

// Session save interval
user_pref("browser.sessionstore.interval", 30000);

// ── Cache ──
user_pref("browser.cache.disk.enable", true);
user_pref("browser.cache.memory.enable", true);
user_pref("image.mem.decode_bytes_at_a_time", 65536);

// ── Disable overhead ──
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("app.normandy.enabled", false);
user_pref("browser.ping-centre.telemetry", false);
user_pref("extensions.pocket.enabled", false);
user_pref("toolkit.cosmeticAnimations.enabled", false);
BALANCED

    # ----- Scroll preset (from Betterfox Smoothfox) -----
    case "$SCROLL_PRESET" in
        sharpen)
            cat <<'SCROLL_SHARPEN'

// ── Scroll: Sharpen [Betterfox Smoothfox] ──
// Crisp, minimal inertia — good for any refresh rate
user_pref("apz.overscroll.enabled", true);
user_pref("general.smoothScroll", true);
user_pref("mousewheel.min_line_scroll_amount", 10);
user_pref("general.smoothScroll.mouseWheel.durationMinMS", 80);
user_pref("general.smoothScroll.currentVelocityWeighting", "0.15");
user_pref("general.smoothScroll.stopDecelerationWeighting", "0.6");
user_pref("general.smoothScroll.msdPhysics.enabled", false);
SCROLL_SHARPEN
            ;;
        instant)
            cat <<'SCROLL_INSTANT'

// ── Scroll: Instant [Betterfox Smoothfox] ──
// Recommended for 60Hz+ displays — simple fast scrolling
user_pref("apz.overscroll.enabled", true);
user_pref("general.smoothScroll", true);
user_pref("mousewheel.default.delta_multiplier_y", 275);
user_pref("general.smoothScroll.msdPhysics.enabled", false);
SCROLL_INSTANT
            ;;
        smooth)
            cat <<'SCROLL_SMOOTH'

// ── Scroll: Smooth [Betterfox Smoothfox] ──
// Recommended for 90Hz+ displays — msdPhysics enabled
user_pref("apz.overscroll.enabled", true);
user_pref("general.smoothScroll", true);
user_pref("general.smoothScroll.msdPhysics.enabled", true);
user_pref("mousewheel.default.delta_multiplier_y", 300);
SCROLL_SMOOTH
            ;;
        natural)
            cat <<'SCROLL_NATURAL'

// ── Scroll: Natural Smooth V3 [Betterfox Smoothfox] ──
// Recommended for 120Hz+ — Chrome-like scrolling feel
user_pref("apz.overscroll.enabled", true);
user_pref("general.smoothScroll", true);
user_pref("general.smoothScroll.msdPhysics.continuousMotionMaxDeltaMS", 12);
user_pref("general.smoothScroll.msdPhysics.enabled", true);
user_pref("general.smoothScroll.msdPhysics.motionBeginSpringConstant", 600);
user_pref("general.smoothScroll.msdPhysics.regularSpringConstant", 650);
user_pref("general.smoothScroll.msdPhysics.slowdownMinDeltaMS", 25);
user_pref("general.smoothScroll.msdPhysics.slowdownMinDeltaRatio", "2");
user_pref("general.smoothScroll.msdPhysics.slowdownSpringConstant", 250);
user_pref("general.smoothScroll.currentVelocityWeighting", "1");
user_pref("general.smoothScroll.stopDecelerationWeighting", "1");
user_pref("mousewheel.default.delta_multiplier_y", 300);
SCROLL_NATURAL
            ;;
    esac

    # ----- GPU/NVIDIA tweaks (from nvidia-capture-card) -----
    if [[ "$GPU_TWEAKS" == "true" ]] || { [[ "$GPU_TWEAKS" == "auto" ]] && detect_gpu_vendor &>/dev/null; }; then
        local gpu_vendor
        gpu_vendor=$(detect_gpu_vendor 2>/dev/null || echo "unknown")

        cat <<'GPU_COMMON'

// ── GPU Acceleration [nvidia-capture-card] ──
user_pref("gfx.webrender.compositor", true);
user_pref("gfx.webrender.compositor.force-enabled", true);
user_pref("gfx.webrender.program-binary-disk-cache", true);
user_pref("gfx.webrender.worker-count", 4);
user_pref("gfx.webrender.max-partial-present-rects", 1);
user_pref("gfx.webrender.all.async-scene-builder", true);
user_pref("widget.dmabuf.force-enabled", true);
user_pref("gfx.x11-egl.force-enabled", true);
user_pref("layers.gpu-process.force-enabled", true);
user_pref("layers.gpu-process.max_restarts", 0);
user_pref("gfx.compositor.glcontext.opaque", true);

// Auto-detect frame rate for mixed refresh rate setups
user_pref("layout.frame_rate", -1);

// Media decode pipeline
user_pref("media.rdd-ffmpeg.enabled", true);
user_pref("media.rdd-vpx.enabled", true);
user_pref("media.gpu-process-decoder", true);
user_pref("media.mediasource.vp9.enabled", true);
user_pref("media.ffvpx.enabled", true);
user_pref("media.utility-process.enabled", true);
GPU_COMMON

        # Detect refresh rate and set max-frame-rate
        local max_hz
        max_hz=$(detect_refresh_rate 2>/dev/null || echo "")
        if [[ -n "$max_hz" && "$max_hz" -gt 60 ]]; then
            echo ""
            echo "// Auto-detected max refresh rate: ${max_hz}Hz"
            echo "user_pref(\"gfx.display.max-frame-rate\", ${max_hz});"
        fi

        if [[ "$gpu_vendor" == "nvidia" ]]; then
            cat <<'GPU_NVIDIA'

// ── NVIDIA-specific optimizations ──
// NOTE: For best results, also set these env vars when launching:
//   MOZ_X11_EGL=1 MOZ_DISABLE_RDD_SANDBOX=1 MOZ_WEBRENDER=1
//   LIBVA_DRIVER_NAME=nvidia NVD_BACKEND=direct
//   __GL_SYNC_TO_VBLANK=0 __GL_YIELD=USLEEP MOZ_USE_XINPUT2=1
GPU_NVIDIA
        elif [[ "$gpu_vendor" == "amd" ]]; then
            cat <<'GPU_AMD'

// ── AMD-specific optimizations ──
user_pref("media.wmf.zero-copy-nv12-textures-force-enabled", true);
GPU_AMD
        fi
    fi

    # ----- Aggressive settings -----
    if [[ "$level" == "aggressive" ]]; then
        cat <<'AGGRESSIVE'

// --- AGGRESSIVE PERFORMANCE ---

// ── Network: push the limits [Betterfox Fastfox] ──
user_pref("network.http.speculative-parallel-limit", 20);
user_pref("network.http.pacing.requests.enabled", false);
user_pref("network.http.max-connections", 1800);

// Larger network buffer [Betterfox]
user_pref("network.buffer.cache.size", 65535);
user_pref("network.buffer.cache.count", 48);
user_pref("network.http.request.max-start-delay", 0);

// ── Rendering: maximum throughput ──
user_pref("image.cache.size", 268435456);
user_pref("image.mem.decode_bytes_at_a_time", 131072);
user_pref("image.mem.surfacecache.max_size_kb", 2097152);
user_pref("image.mem.shared.unmap.min_expiration_ms", 120000);

// GFX buffers [Betterfox]
user_pref("gfx.canvas.accelerated.cache-size", 512);
user_pref("gfx.content.skia-font-cache-size", 32);

// ── Memory cache [Betterfox Fastfox] ──
user_pref("browser.cache.memory.capacity", 131072);
user_pref("browser.cache.memory.max_entry_size", 20480);

// ── JavaScript: max JIT ──
user_pref("javascript.options.mem.high_water_mark", 256);
user_pref("javascript.options.mem.gc_incremental_slice_ms", 10);

// ── Media ──
user_pref("media.utility-process.enabled", true);
user_pref("media.memory_caches_combined_limit_kb", 1048576);

// ── Session Store ──
user_pref("browser.sessionstore.interval", 60000);

// ── Tab unloading [Betterfox Fastfox] ──
user_pref("browser.tabs.min_inactive_duration_before_unload", 300000);
user_pref("browser.low_commit_space_threshold_percent", 20);

// ── Disable UI overhead ──
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.highlights", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("accessibility.force_disabled", 1);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("startup.homepage_welcome_url", "");
AGGRESSIVE
    fi

    # ----- Low-RAM settings -----
    if [[ "$level" == "low-ram" ]]; then
        cat <<'LOWRAM'

// --- LOW-RAM OPTIMIZATION (≤ 4 GB) ---

// ── Memory Management ──
user_pref("dom.ipc.processCount", 4);
user_pref("browser.cache.memory.capacity", 32768);
user_pref("browser.cache.memory.max_entry_size", 2048);
user_pref("browser.cache.disk.capacity", 262144);

// Smaller image cache
user_pref("image.cache.size", 67108864);
user_pref("image.mem.surfacecache.max_size_kb", 131072);
user_pref("image.mem.decode_bytes_at_a_time", 32768);

// ── Aggressive GC ──
user_pref("javascript.options.mem.high_water_mark", 64);
user_pref("javascript.options.mem.gc_incremental_slice_ms", 5);
user_pref("javascript.options.mem.gc_max_empty_chunk_count", 5);
user_pref("browser.tabs.unloadOnLowMemory", true);

// ── Tab management [Betterfox] ──
user_pref("browser.tabs.min_inactive_duration_before_unload", 300000);
user_pref("browser.low_commit_space_threshold_percent", 20);

// ── Reduce network memory ──
user_pref("network.buffer.cache.size", 32768);
user_pref("network.buffer.cache.count", 24);
user_pref("network.http.max-connections", 512);
user_pref("network.http.max-persistent-connections-per-server", 6);
user_pref("network.http.speculative-parallel-limit", 4);
user_pref("network.dnsCacheEntries", 400);

// ── Session Store ──
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
user_pref("browser.uidensity", 1);

// ── Prefetching: off to save memory ──
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);
LOWRAM
    fi
}

# ---- Helper functions ----

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

get_target_browsers() {
    if [[ -n "$TARGET_BROWSER" ]]; then
        echo "$TARGET_BROWSER"
    else
        printf '%s\n' "${MOZILLA_BROWSERS[@]}"
    fi
}

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
        if [[ -f "$user_js" ]] && grep -q "Privacy Hardening\|Performance Optimization" "$user_js" 2>/dev/null; then
            local temp_file
            temp_file=$(mktemp)
            if grep -q "Performance Optimization" "$user_js" 2>/dev/null; then
                sed '/Browser Cleanup Tools — Performance Optimization/,/^$/d' "$user_js" > "$temp_file" 2>/dev/null || cp "$user_js" "$temp_file"
                mv "$temp_file" "$user_js"
            fi
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

    # Check applied level
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

    if [[ -f "$prefs_file" || -f "$user_file" ]]; then
        local checks=(
            "gfx.webrender.all|WebRender (GPU)|true"
            "layers.acceleration.force-enabled|GPU Acceleration|true"
            "media.hardware-video-decoding.enabled|HW Video Decode|true"
            "media.ffmpeg.vaapi.enabled|VA-API (Linux)|true"
            "gfx.webrender.compositor.force-enabled|GPU Compositor|true"
            "widget.dmabuf.force-enabled|DMA-BUF|true"
            "gfx.x11-egl.force-enabled|X11 EGL|true"
            "dom.ipc.processCount|Content Processes|8"
            "fission.autostart|Fission (Site Isolation)|true"
            "javascript.options.ion|IonMonkey JIT|true"
            "network.http.http3.enabled|HTTP/3 (QUIC)|true"
            "general.smoothScroll.msdPhysics.enabled|Smooth Scrolling|true"
            "browser.cache.memory.enable|Memory Cache|true"
            "browser.sessionstore.interval|Session Save Interval|30000"
        )

        for check in "${checks[@]}"; do
            IFS='|' read -r pref_name label desired <<< "$check"
            local current="default"

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
        if grep -q "Privacy Hardening" "$user_js" 2>/dev/null; then
            if [[ "$DRY_RUN" == "true" ]]; then
                echo -e "${MAGENTA}[DRY-RUN]${NC} Would remove performance section from user.js in $profile_name (keeping privacy)"
            else
                local temp_file
                temp_file=$(mktemp)
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

# ---- GPU Info ----

show_gpu_info() {
    header "GPU / Display Information"

    local gpu_vendor
    gpu_vendor=$(detect_gpu_vendor 2>/dev/null || echo "unknown")

    # GPU hardware
    echo -e "${BOLD}GPU Hardware${NC}"
    if command -v lspci &>/dev/null; then
        lspci 2>/dev/null | grep -i "vga\|3d\|display" | while read -r line; do
            echo -e "  $line"
        done
    fi
    echo -e "  Detected vendor: ${BOLD}${gpu_vendor}${NC}"
    echo ""

    # Display / refresh rate
    echo -e "${BOLD}Display${NC}"
    local hz
    hz=$(detect_refresh_rate 2>/dev/null || echo "")
    if [[ -n "$hz" ]]; then
        echo -e "  Detected refresh rate: ${GREEN}${hz}Hz${NC}"
    else
        echo -e "  Refresh rate: ${DIM}unable to detect${NC}"
    fi

    if command -v xrandr &>/dev/null; then
        echo -e "  ${DIM}Active outputs:${NC}"
        xrandr --current 2>/dev/null | grep " connected" | while read -r line; do
            echo -e "    $line"
        done
    fi
    echo ""

    # VA-API
    echo -e "${BOLD}Hardware Decode (VA-API)${NC}"
    if command -v vainfo &>/dev/null; then
        local vaapi_status
        if vaapi_status=$(vainfo 2>&1); then
            local profiles
            profiles=$(echo "$vaapi_status" | grep -c "VAProfile" || echo "0")
            echo -e "  Status: ${GREEN}available${NC} ($profiles profiles)"
            echo "$vaapi_status" | grep "VAProfile" | head -5 | while read -r line; do
                echo -e "    ${DIM}$line${NC}"
            done
            local total
            total=$(echo "$vaapi_status" | grep -c "VAProfile" || echo "0")
            if [[ "$total" -gt 5 ]]; then
                echo -e "    ${DIM}... and $((total-5)) more${NC}"
            fi
        else
            echo -e "  Status: ${YELLOW}not working${NC}"
            echo -e "  ${DIM}$(echo "$vaapi_status" | head -2)${NC}"
        fi
    else
        echo -e "  Status: ${DIM}vainfo not installed (sudo apt install vainfo)${NC}"
    fi
    echo ""

    # Recommended env vars
    if [[ "$gpu_vendor" == "nvidia" ]]; then
        echo -e "${BOLD}Recommended NVIDIA Launch Environment${NC}"
        echo -e "  ${DIM}Use these env vars when launching your browser:${NC}"
        echo -e "  MOZ_X11_EGL=1"
        echo -e "  MOZ_DISABLE_RDD_SANDBOX=1"
        echo -e "  MOZ_WEBRENDER=1"
        echo -e "  LIBVA_DRIVER_NAME=nvidia"
        echo -e "  NVD_BACKEND=direct"
        echo -e "  __GL_SYNC_TO_VBLANK=0"
        echo -e "  __GL_YIELD=USLEEP"
        echo -e "  MOZ_USE_XINPUT2=1"
        echo ""
        echo -e "  ${DIM}Or use: $(basename "$0") launch-env | source /dev/stdin${NC}"
    fi
}

# ---- Launch env ----

print_launch_env() {
    local gpu_vendor
    gpu_vendor=$(detect_gpu_vendor 2>/dev/null || echo "unknown")

    # Common for all GPU-accelerated setups
    echo "export MOZ_WEBRENDER=1"
    echo "export MOZ_USE_XINPUT2=1"

    if [[ "$gpu_vendor" == "nvidia" ]]; then
        echo "export MOZ_X11_EGL=1"
        echo "export MOZ_DISABLE_RDD_SANDBOX=1"
        echo "export LIBVA_DRIVER_NAME=nvidia"
        echo "export NVD_BACKEND=direct"
        echo "export __GL_SYNC_TO_VBLANK=0"
        echo "export __GL_YIELD=USLEEP"
    elif [[ "$gpu_vendor" == "amd" ]]; then
        echo "export LIBVA_DRIVER_NAME=radeonsi"
        echo "export MOZ_X11_EGL=1"
    elif [[ "$gpu_vendor" == "intel" ]]; then
        echo "export LIBVA_DRIVER_NAME=iHD"
        echo "export MOZ_X11_EGL=1"
    fi

    local hz
    hz=$(detect_refresh_rate 2>/dev/null || echo "")
    if [[ -n "$hz" && "$hz" -gt 60 ]]; then
        echo "# Detected refresh rate: ${hz}Hz"
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
    local gpu_vendor
    gpu_vendor=$(detect_gpu_vendor 2>/dev/null || echo "unknown")
    if command -v lspci &>/dev/null; then
        local gpu
        gpu=$(lspci 2>/dev/null | grep -i "vga\|3d\|display" | head -1 | sed 's/.*: //')
        [[ -n "$gpu" ]] && echo -e "  GPU: $gpu (${gpu_vendor})"
    fi

    # VA-API check
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

    # Refresh rate
    local hz
    hz=$(detect_refresh_rate 2>/dev/null || echo "")
    [[ -n "$hz" ]] && echo -e "  Display: ${hz}Hz"
    echo ""

    # Browser processes
    echo -e "${BOLD}Running Browsers${NC}"
    local found_browser=false

    for browser_key in "${ALL_BROWSERS[@]}"; do
        local -a procs
        IFS=' ' read -ra procs <<< "$(get_process_names "$browser_key" 2>/dev/null)"
        [[ ${#procs[@]} -eq 0 ]] && continue

        for proc in "${procs[@]}"; do
            local pids
            pids=$(pgrep -x "$proc" 2>/dev/null || true)
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
            [[ "$mem_total_kb" -gt 2097152 ]] && mem_color="$YELLOW"
            [[ "$mem_total_kb" -gt 4194304 ]] && mem_color="$RED"

            local display_name
            display_name=$(get_display_name "$browser_key" 2>/dev/null || echo "$proc")
            echo -e "  ${BOLD}${display_name}${NC}: $proc_count processes, ${mem_color}${mem_human} RAM${NC}, ${cpu_total}% CPU"
            break  # Only show first matching process name per browser
        done
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
        elif [[ "$total_mem" -lt 8388608 ]]; then
            echo -e "  ${CYAN}●${NC} Use ${BOLD}--balanced${NC} optimization level"
        else
            echo -e "  ${CYAN}●${NC} Use ${BOLD}--aggressive${NC} for maximum performance"
        fi
    fi

    if [[ "$gpu_vendor" != "unknown" ]]; then
        echo -e "  ${CYAN}●${NC} GPU detected (${gpu_vendor}) — use ${BOLD}--gpu-tweaks${NC} for GPU acceleration"
    fi
    if [[ -n "$hz" && "$hz" -gt 60 ]]; then
        echo -e "  ${CYAN}●${NC} ${hz}Hz display — try ${BOLD}--scroll-smooth${NC} or ${BOLD}--scroll-natural${NC}"
    fi
    echo ""
    echo -e "${DIM}Apply settings: $(basename "$0") apply [--balanced|--aggressive|--low-ram] [--gpu-tweaks] [--scroll-smooth]${NC}"
}

# ---- Iterate over matching profiles ----

for_each_profile() {
    local callback="$1"
    shift
    local applied=0

    while read -r browser_key; do
        [[ -z "$browser_key" ]] && continue

        # Only process Mozilla browsers (Chromium is handled by harden-chromium.sh)
        is_mozilla_browser "$browser_key" 2>/dev/null || continue

        local display_name
        display_name=$(get_display_name "$browser_key" 2>/dev/null || echo "$browser_key")

        local has_profiles=false
        while IFS='|' read -r install_type profile_dir; do
            [[ -z "$profile_dir" ]] && continue
            local pname
            pname=$(basename "$profile_dir")
            if [[ -n "$TARGET_PROFILE" && "$pname" != *"$TARGET_PROFILE"* ]]; then
                continue
            fi
            if [[ "$has_profiles" == "false" ]]; then
                echo -e "\n${BOLD}${display_name}${NC}"
                has_profiles=true
            fi
            echo -e "  ${DIM}[$install_type]${NC} $pname"
            "$callback" "$profile_dir" "$@"
            ((applied++))
        done < <(find_browser_profiles "$browser_key")
    done < <(get_target_browsers)

    echo "$applied"
}

# ---- Main ----

main() {
    check_version_flag "$@" 2>/dev/null || true
    local command=""

    for arg in "$@"; do
        case "$arg" in
            apply|show|status|revert|benchmark|gpu-info|launch-env) command="$arg" ;;
            --balanced)      LEVEL="balanced" ;;
            --aggressive)    LEVEL="aggressive" ;;
            --low-ram)       LEVEL="low-ram" ;;
            --no-backup)     BACKUP=false ;;
            -n|--dry-run)    DRY_RUN=true ;;
            -y|--yes)        AUTO_YES=true ;;
            --gpu-tweaks)    GPU_TWEAKS="true" ;;
            --no-gpu-tweaks) GPU_TWEAKS="false" ;;
            --scroll-sharpen) SCROLL_PRESET="sharpen" ;;
            --scroll-instant) SCROLL_PRESET="instant" ;;
            --scroll-smooth)  SCROLL_PRESET="smooth" ;;
            --scroll-natural) SCROLL_PRESET="natural" ;;
            -h|--help)       show_help; exit 0 ;;
        esac
    done

    # Parse --browser and --profile args
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
            header "Performance Settings (${LEVEL})"
            generate_user_js "$LEVEL"
            ;;
        apply)
            header "Applying ${LEVEL} Performance Optimization"
            echo -e "${BOLD}Level: ${LEVEL}${NC}"
            case "$LEVEL" in
                balanced)   echo -e "Moderate optimizations, safe for all hardware" ;;
                aggressive) echo -e "${YELLOW}Pushing limits — max rendering and network performance${NC}" ;;
                low-ram)    echo -e "${CYAN}Optimized for systems with ≤ 4 GB RAM${NC}" ;;
            esac
            [[ "$GPU_TWEAKS" == "true" ]] && echo -e "GPU tweaks: ${GREEN}enabled${NC}"
            [[ -n "$SCROLL_PRESET" ]] && echo -e "Scroll preset: ${CYAN}${SCROLL_PRESET}${NC}"
            echo ""

            if [[ "$AUTO_YES" != "true" && "$DRY_RUN" != "true" ]]; then
                confirm "Apply ${LEVEL} performance settings?" || { info "Cancelled."; exit 0; }
            fi

            local applied
            applied=$(for_each_profile apply_to_profile "$LEVEL")

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
            for_each_profile show_profile_status > /dev/null
            ;;
        revert)
            header "Reverting Performance Optimization"
            if [[ "$AUTO_YES" != "true" && "$DRY_RUN" != "true" ]]; then
                confirm "Revert performance settings (restore original user.js)?" || { info "Cancelled."; exit 0; }
            fi
            for_each_profile revert_profile > /dev/null
            echo -e "\n${DIM}Restart your browser for changes to take effect.${NC}"
            ;;
        gpu-info)
            show_gpu_info
            ;;
        launch-env)
            print_launch_env
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
