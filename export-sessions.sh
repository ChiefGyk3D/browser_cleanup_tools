#!/usr/bin/env bash
# export-sessions.sh - Export and restore browser tab sessions
# Saves open tabs from Firefox, Floorp, Chromium, Brave, and Chrome
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

EXPORT_DIR="$SCRIPT_DIR/session-exports"
OUTPUT_FORMAT="text"

show_help() {
    cat <<EOF
${BOLD}Browser Session Export Tool${NC}

Export open tabs from all browsers into portable formats, and restore
them later or in a different browser.

Usage: $(basename "$0") <command> [OPTIONS]

Commands:
  export               Export/save open tabs from browsers
  list                 List saved session exports
  restore              Open saved tabs in a browser
  convert              Convert a session export between formats

Options:
  --browser <name>     Target browser: firefox, floorp, chromium, brave, chrome
  --profile <name>     Target a specific profile
  --format <fmt>       Export format: text (default), json, html, markdown
  --output <file>      Output file path (default: session-exports/<timestamp>)
  --all                Export from all browsers
  -h, --help           Show this help message

Examples:
  $(basename "$0") export                               # Export all browsers
  $(basename "$0") export --browser firefox --format json
  $(basename "$0") export --format html --output ~/tabs.html
  $(basename "$0") list                                 # List saved exports
  $(basename "$0") restore latest                       # Open latest export
  $(basename "$0") restore ~/tabs.json --browser firefox
  $(basename "$0") convert session.json --format html

Formats:
  text       One URL per line with tab title as comment
  json       Structured JSON with browser, profile, tabs, timestamps
  html       Clickable HTML bookmarks page
  markdown   Markdown list grouped by browser/window

EOF
}

# ---- Mozilla session extraction ----
# Firefox/Floorp store sessions in sessionstore-backups/recovery.jsonlz4

extract_mozilla_tabs() {
    local profile_dir="$1"
    local app_name="$2"
    local install_type="$3"
    local profile_name
    profile_name=$(basename "$profile_dir")

    # Try recovery.jsonlz4 first (current session), then previous.jsonlz4
    local session_files=(
        "$profile_dir/sessionstore-backups/recovery.jsonlz4"
        "$profile_dir/sessionstore-backups/recovery.baklz4"
        "$profile_dir/sessionstore-backups/previous.jsonlz4"
        "$profile_dir/sessionstore.jsonlz4"
    )

    local session_file=""
    for sf in "${session_files[@]}"; do
        if [[ -f "$sf" ]]; then
            session_file="$sf"
            break
        fi
    done

    if [[ -z "$session_file" ]]; then
        return
    fi

    # Mozilla uses mozlz4 format (lz4 with a custom header)
    # We need python3 with lz4 or a fallback approach
    if command -v python3 &>/dev/null; then
        python3 -c "
import json, sys

def read_mozlz4(path):
    '''Read Mozilla's mozLz4 compressed files'''
    import struct
    try:
        import lz4.block
        with open(path, 'rb') as f:
            magic = f.read(8)
            if magic[:4] != b'mozLz40\x00'[:4] and magic != b'mozLz40\x00':
                # Try reading first 8 bytes as magic
                pass
            data = f.read()
            return lz4.block.decompress(data)
    except ImportError:
        pass
    # Fallback: try reading as plain JSON (sessionstore.js)
    try:
        with open(path, 'r') as f:
            return f.read().encode()
    except:
        return None

def read_session(path):
    '''Try to read session file in various formats'''
    # Try mozlz4 first
    data = read_mozlz4(path)
    if data:
        try:
            return json.loads(data)
        except:
            pass
    # Try plain JSON
    try:
        with open(path, 'r') as f:
            return json.load(f)
    except:
        pass
    return None

session = read_session('$session_file')
if not session:
    sys.exit(0)

windows = session.get('windows', [])
for wi, window in enumerate(windows):
    tabs = window.get('tabs', [])
    for tab in tabs:
        entries = tab.get('entries', [])
        if entries:
            current = tab.get('index', len(entries)) - 1
            if 0 <= current < len(entries):
                entry = entries[current]
                url = entry.get('url', '')
                title = entry.get('title', url)
                # Skip internal pages
                if url.startswith('about:') or url.startswith('chrome:'):
                    continue
                print(f'TAB|{wi}|{title}|{url}')
" 2>/dev/null
    else
        # No python3 — try basic approach with strings
        if command -v strings &>/dev/null; then
            strings "$session_file" 2>/dev/null | grep -oP 'https?://[^\s"<>]+' | sort -u | while read -r url; do
                echo "TAB|0||$url"
            done
        fi
    fi
}

# ---- Chromium session extraction ----
# Chromium browsers have sessions in "Current Session" and "Current Tabs" (SNSS format)
# Easier to read from "Tabs" file or use Preferences

extract_chromium_tabs() {
    local profile_dir="$1"
    local app_name="$2"
    local install_type="$3"
    local profile_name
    profile_name=$(basename "$profile_dir")

    # Chromium stores the last session data; we can try multiple approaches
    # 1. Parse "Sessions/Tabs*" or "Current Tabs" (binary SNSS — complex)
    # 2. Read from Preferences (has some tab info)
    # 3. Try "Session Storage" / History for recent URLs

    # Best approach: parse the Session Buddy or use the SNSS format
    # For reliability, we'll read from "Current Tabs" via python if available

    local current_tabs="$profile_dir/Current Tabs"
    local current_session="$profile_dir/Current Session"
    local last_tabs="$profile_dir/Last Tabs"
    local last_session="$profile_dir/Last Session"

    local target_file=""
    for f in "$current_tabs" "$current_session" "$last_tabs" "$last_session"; do
        [[ -f "$f" ]] && target_file="$f" && break
    done

    if [[ -n "$target_file" ]] && command -v python3 &>/dev/null; then
        python3 -c "
import sys

def extract_urls_from_snss(path):
    '''Extract URLs from Chromium SNSS session files'''
    urls = set()
    try:
        with open(path, 'rb') as f:
            data = f.read()
        # SNSS files contain URL strings — scan for them
        i = 0
        while i < len(data):
            # Look for http:// or https:// patterns
            for proto in [b'http://', b'https://']:
                idx = data.find(proto, i)
                if idx != -1 and idx == i:
                    # Extract until we hit a non-URL character
                    end = idx
                    while end < len(data) and data[end] > 31 and data[end] < 127 and chr(data[end]) not in ' \"<>{}|\\\\^':
                        end += 1
                    url = data[idx:end].decode('ascii', errors='ignore')
                    if len(url) > 10 and '.' in url:
                        # Skip Chrome internal URLs
                        if not any(url.startswith(p) for p in ['https://chrome.', 'chrome://', 'chrome-extension://', 'https://new-tab-page', 'https://ntp.']):
                            urls.add(url)
                    i = end
                    break
            else:
                i += 1
    except Exception as e:
        pass
    return urls

urls = extract_urls_from_snss('$target_file')
for url in sorted(urls):
    print(f'TAB|0||{url}')
" 2>/dev/null
    elif [[ -n "$target_file" ]]; then
        # Fallback: use strings to extract URLs
        strings "$target_file" 2>/dev/null | grep -oP 'https?://[^\s"<>]+' | \
            grep -v '^https\?://chrome\.' | \
            grep -v '^chrome://' | \
            grep -v '^chrome-extension://' | \
            sort -u | while read -r url; do
            echo "TAB|0||$url"
        done
    fi

    # Also try to get tab info from Preferences/Secure Preferences
    local prefs_file="$profile_dir/Preferences"
    if [[ -f "$prefs_file" ]] && command -v python3 &>/dev/null; then
        python3 -c "
import json
try:
    with open('$prefs_file') as f:
        data = json.load(f)
    # Some Chromium builds store pinned tabs here
    pinned = data.get('pinned_tabs', [])
    for tab in pinned:
        url = tab.get('url', '')
        if url and not url.startswith('chrome://'):
            print(f'TAB|-1|Pinned|{url}')
except:
    pass
" 2>/dev/null
    fi
}

# ---- Output formatters ----

format_text() {
    local tab_data="$1"
    while IFS='|' read -r browser install_type profile_name window_id title url; do
        [[ -z "$url" ]] && continue
        if [[ -n "$title" ]]; then
            echo "# $title"
        fi
        echo "$url"
    done <<< "$tab_data"
}

format_json() {
    local tab_data="$1"

    if command -v python3 &>/dev/null; then
        echo "$tab_data" | python3 -c "
import json, sys
from datetime import datetime

tabs = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split('|', 6)
    if len(parts) < 7:
        continue
    browser, install, profile, window, title, url = parts[0], parts[1], parts[2], parts[3], parts[4], parts[5] if len(parts) > 5 else ''
    # Handle the case where url might contain the rest
    if len(parts) == 7:
        url = parts[6]
    elif len(parts) == 6:
        url = parts[5]
    tabs.append({
        'browser': browser,
        'install_type': install,
        'profile': profile,
        'window': int(window) if window.lstrip('-').isdigit() else 0,
        'title': title,
        'url': url
    })

output = {
    'exported': datetime.now().isoformat(),
    'tool': 'Browser Cleanup Tools - Session Export',
    'total_tabs': len(tabs),
    'tabs': tabs
}
print(json.dumps(output, indent=2))
"
    else
        echo '{"error": "python3 required for JSON output"}'
    fi
}

format_html() {
    local tab_data="$1"

    cat <<'HTML_HEADER'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Browser Session Export</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 900px; margin: 40px auto; padding: 0 20px; background: #1a1a2e; color: #e0e0e0; }
        h1 { color: #64ffda; border-bottom: 2px solid #333; padding-bottom: 10px; }
        h2 { color: #82b1ff; margin-top: 30px; }
        .tab { padding: 8px 0; border-bottom: 1px solid #2a2a3e; }
        .tab a { color: #64b5f6; text-decoration: none; }
        .tab a:hover { text-decoration: underline; color: #90caf9; }
        .title { color: #aaa; font-size: 0.9em; }
        .meta { color: #666; font-size: 0.8em; margin-top: 5px; }
        .count { color: #64ffda; font-weight: bold; }
        .open-all { background: #64ffda; color: #1a1a2e; border: none; padding: 8px 16px; border-radius: 4px; cursor: pointer; font-weight: bold; margin: 5px; }
        .open-all:hover { background: #4dd0b0; }
    </style>
</head>
<body>
HTML_HEADER

    echo "<h1>Browser Session Export</h1>"
    echo "<p>Exported: $(date '+%Y-%m-%d %H:%M:%S')</p>"

    local current_browser=""
    local tab_count=0
    local urls_js="["

    while IFS='|' read -r browser install_type profile_name window_id title url; do
        [[ -z "$url" ]] && continue
        ((tab_count++))

        if [[ "$browser" != "$current_browser" ]]; then
            [[ -n "$current_browser" ]] && echo "</div>"
            current_browser="$browser"
            echo "<h2>$browser ($install_type - $profile_name)</h2>"
            echo "<div class='browser-section'>"
        fi

        local display_title="${title:-$url}"
        echo "<div class='tab'>"
        echo "  <a href='$url' target='_blank'>$display_title</a>"
        if [[ -n "$title" && "$title" != "$url" ]]; then
            echo "  <div class='meta'>$url</div>"
        fi
        echo "</div>"

        urls_js="$urls_js\"$(echo "$url" | sed 's/"/\\"/g')\","
    done <<< "$tab_data"

    [[ -n "$current_browser" ]] && echo "</div>"
    urls_js="${urls_js%,}]"

    cat <<HTML_FOOTER
<p>Total tabs: <span class="count">$tab_count</span></p>
<button class="open-all" onclick="openAll()">Open All Tabs</button>
<script>
var urls = $urls_js;
function openAll() {
    if (confirm('Open ' + urls.length + ' tabs?')) {
        urls.forEach(function(url) { window.open(url, '_blank'); });
    }
}
</script>
</body>
</html>
HTML_FOOTER
}

format_markdown() {
    local tab_data="$1"

    echo "# Browser Session Export"
    echo ""
    echo "Exported: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    local current_browser=""
    local tab_count=0

    while IFS='|' read -r browser install_type profile_name window_id title url; do
        [[ -z "$url" ]] && continue
        ((tab_count++))

        if [[ "$browser" != "$current_browser" ]]; then
            current_browser="$browser"
            echo ""
            echo "## $browser ($install_type - $profile_name)"
            echo ""
        fi

        local display_title="${title:-$url}"
        echo "- [$display_title]($url)"
    done <<< "$tab_data"

    echo ""
    echo "---"
    echo "Total tabs: $tab_count"
}

# ---- Export command ----

do_export() {
    local format="$1"
    local target_browser="$2"
    local target_profile="$3"
    local output_file="$4"
    local all_tabs=""

    local collect_browser_tabs() {
        local -n paths=$1
        local browser_name="$2"
        local extract_func="$3"

        for install_type in "${!paths[@]}"; do
            local base_dir="${paths[$install_type]}"
            [[ ! -d "$base_dir" ]] && continue

            if [[ "$extract_func" == "extract_mozilla_tabs" ]]; then
                # Find profiles via profiles.ini
                local profiles_ini="$base_dir/profiles.ini"
                if [[ -f "$profiles_ini" ]]; then
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
                            [[ -n "$target_profile" && "$pname" != *"$target_profile"* ]] && continue

                            local tabs
                            tabs=$($extract_func "$profile_dir" "$browser_name" "$install_type")
                            while IFS= read -r tab_line; do
                                [[ -z "$tab_line" ]] && continue
                                # Prepend browser info: browser|install|profile|window|title|url
                                local rest="${tab_line#TAB|}"
                                echo "$browser_name|$install_type|$pname|$rest"
                            done <<< "$tabs"
                        fi
                    done < "$profiles_ini"
                fi
            else
                # Chromium-based — scan Default and Profile* dirs
                for profile_dir in "$base_dir"/Default "$base_dir"/Profile\ *; do
                    [[ ! -d "$profile_dir" ]] && continue
                    local pname
                    pname=$(basename "$profile_dir")
                    [[ -n "$target_profile" && "$pname" != *"$target_profile"* ]] && continue

                    local tabs
                    tabs=$($extract_func "$profile_dir" "$browser_name" "$install_type")
                    while IFS= read -r tab_line; do
                        [[ -z "$tab_line" ]] && continue
                        local rest="${tab_line#TAB|}"
                        echo "$browser_name|$install_type|$pname|$rest"
                    done <<< "$tabs"
                done
            fi
        done
    }

    # Collect tabs from all browsers
    if [[ -z "$target_browser" || "$target_browser" == "firefox" ]]; then
        local firefox_tabs
        firefox_tabs=$(collect_browser_tabs FIREFOX_PATHS "Firefox" "extract_mozilla_tabs")
        all_tabs+="$firefox_tabs"$'\n'
    fi

    if [[ -z "$target_browser" || "$target_browser" == "floorp" ]]; then
        local floorp_tabs
        floorp_tabs=$(collect_browser_tabs FLOORP_PATHS "Floorp" "extract_mozilla_tabs")
        all_tabs+="$floorp_tabs"$'\n'
    fi

    if [[ -z "$target_browser" || "$target_browser" == "chromium" ]]; then
        local chromium_tabs
        chromium_tabs=$(collect_browser_tabs CHROMIUM_PATHS "Chromium" "extract_chromium_tabs")
        all_tabs+="$chromium_tabs"$'\n'
    fi

    if [[ -z "$target_browser" || "$target_browser" == "brave" ]]; then
        local brave_tabs
        brave_tabs=$(collect_browser_tabs BRAVE_PATHS "Brave" "extract_chromium_tabs")
        all_tabs+="$brave_tabs"$'\n'
    fi

    if [[ -z "$target_browser" || "$target_browser" == "chrome" ]]; then
        local chrome_tabs
        chrome_tabs=$(collect_browser_tabs CHROME_PATHS "Chrome" "extract_chromium_tabs")
        all_tabs+="$chrome_tabs"$'\n'
    fi

    # Remove empty lines
    all_tabs=$(echo "$all_tabs" | grep -v '^$')

    if [[ -z "$all_tabs" ]]; then
        warn "No tabs found. Browsers may need to be running or have session data."
        exit 0
    fi

    local tab_count
    tab_count=$(echo "$all_tabs" | wc -l)

    # Generate output
    local output
    case "$format" in
        json)     output=$(format_json "$all_tabs") ;;
        html)     output=$(format_html "$all_tabs") ;;
        markdown) output=$(format_markdown "$all_tabs") ;;
        *)        output=$(format_text "$all_tabs") ;;
    esac

    # Write to file or stdout
    if [[ -n "$output_file" ]]; then
        mkdir -p "$(dirname "$output_file")"
        echo "$output" > "$output_file"
        success "Exported $tab_count tabs to $output_file"
    else
        # Auto-generate output filename
        mkdir -p "$EXPORT_DIR"
        local ext
        case "$format" in
            json)     ext="json" ;;
            html)     ext="html" ;;
            markdown) ext="md" ;;
            *)        ext="txt" ;;
        esac
        local auto_file="$EXPORT_DIR/session_$(date +%Y%m%d_%H%M%S).$ext"
        echo "$output" > "$auto_file"
        success "Exported $tab_count tabs to $auto_file"
    fi
}

# ---- List exports ----

do_list() {
    header "Saved Session Exports"

    if [[ ! -d "$EXPORT_DIR" ]]; then
        info "No exports found. Run 'export' first."
        return
    fi

    local count=0
    for f in "$EXPORT_DIR"/session_*; do
        [[ ! -f "$f" ]] && continue
        ((count++))
        local fname
        fname=$(basename "$f")
        local fsize
        fsize=$(du -h "$f" | cut -f1)
        local fdate
        fdate=$(stat -c '%y' "$f" 2>/dev/null | cut -d. -f1)

        # Count tabs in file
        local tab_count="?"
        case "$f" in
            *.json) tab_count=$(python3 -c "import json; d=json.load(open('$f')); print(d.get('total_tabs','?'))" 2>/dev/null || echo "?") ;;
            *.txt)  tab_count=$(grep -c '^http' "$f" 2>/dev/null || echo "?") ;;
            *.html) tab_count=$(grep -c 'class="tab"' "$f" 2>/dev/null || echo "?") ;;
            *.md)   tab_count=$(grep -c '^\- \[' "$f" 2>/dev/null || echo "?") ;;
        esac

        echo -e "  ${BOLD}$fname${NC}  ${DIM}($fsize, $tab_count tabs, $fdate)${NC}"
    done

    if [[ "$count" -eq 0 ]]; then
        info "No exports found."
    else
        echo ""
        info "$count export(s) found in $EXPORT_DIR"
    fi
}

# ---- Restore command ----

do_restore() {
    local input_file="$1"
    local target_browser="$2"

    # Handle "latest" keyword
    if [[ "$input_file" == "latest" ]]; then
        input_file=$(ls -t "$EXPORT_DIR"/session_* 2>/dev/null | head -1)
        if [[ -z "$input_file" ]]; then
            error "No exports found"
            exit 1
        fi
        info "Using latest export: $(basename "$input_file")"
    fi

    if [[ ! -f "$input_file" ]]; then
        error "File not found: $input_file"
        exit 1
    fi

    # Extract URLs from the file
    local urls=()
    case "$input_file" in
        *.json)
            if command -v python3 &>/dev/null; then
                while IFS= read -r url; do
                    urls+=("$url")
                done < <(python3 -c "
import json
with open('$input_file') as f:
    data = json.load(f)
for tab in data.get('tabs', []):
    print(tab.get('url', ''))
" 2>/dev/null)
            fi
            ;;
        *.html)
            while IFS= read -r url; do
                urls+=("$url")
            done < <(grep -oP 'href="\Khttps?://[^"]+' "$input_file" 2>/dev/null)
            ;;
        *.md)
            while IFS= read -r url; do
                urls+=("$url")
            done < <(grep -oP '\]\(\Khttps?://[^)]+' "$input_file" 2>/dev/null)
            ;;
        *)
            while IFS= read -r url; do
                [[ "$url" =~ ^https?:// ]] && urls+=("$url")
            done < "$input_file"
            ;;
    esac

    if [[ ${#urls[@]} -eq 0 ]]; then
        error "No URLs found in $input_file"
        exit 1
    fi

    echo -e "Found ${BOLD}${#urls[@]}${NC} tabs to restore"

    # Determine which browser to open with
    local browser_cmd=""
    if [[ -n "$target_browser" ]]; then
        case "$target_browser" in
            firefox)  browser_cmd="firefox" ;;
            floorp)   browser_cmd="floorp" ;;
            chromium) browser_cmd="chromium-browser" ;;
            brave)    browser_cmd="brave-browser" ;;
            chrome)   browser_cmd="google-chrome" ;;
        esac
    else
        # Auto-detect default browser
        if command -v xdg-settings &>/dev/null; then
            local default
            default=$(xdg-settings get default-web-browser 2>/dev/null || echo "")
            case "$default" in
                *firefox*)  browser_cmd="firefox" ;;
                *floorp*)   browser_cmd="floorp" ;;
                *chromium*) browser_cmd="chromium-browser" ;;
                *brave*)    browser_cmd="brave-browser" ;;
                *chrome*)   browser_cmd="google-chrome" ;;
            esac
        fi
        # Fallback
        if [[ -z "$browser_cmd" ]]; then
            browser_cmd="xdg-open"
        fi
    fi

    if ! command -v "$browser_cmd" &>/dev/null; then
        # Try flatpak variants
        warn "$browser_cmd not found in PATH. Falling back to xdg-open."
        browser_cmd="xdg-open"
    fi

    echo -e "Using browser: ${BOLD}$browser_cmd${NC}"
    confirm "Open ${#urls[@]} tabs?" || { info "Cancelled."; exit 0; }

    # Open URLs
    for url in "${urls[@]}"; do
        "$browser_cmd" "$url" &>/dev/null &
        sleep 0.3  # Small delay to avoid overwhelming the browser
    done

    success "Opened ${#urls[@]} tabs"
}

# ---- Main ----

main() {
    local command=""
    local format="text"
    local target_browser=""
    local target_profile=""
    local output_file=""
    local restore_file=""
    AUTO_YES=false

    # Parse arguments
    local args=("$@")
    local i=0
    while [[ $i -lt ${#args[@]} ]]; do
        case "${args[$i]}" in
            export|list|restore|convert) command="${args[$i]}" ;;
            --format)    ((i++)); format="${args[$i]}" ;;
            --browser)   ((i++)); target_browser="${args[$i]}" ;;
            --profile)   ((i++)); target_profile="${args[$i]}" ;;
            --output)    ((i++)); output_file="${args[$i]}" ;;
            --all)       target_browser="" ;;
            -y|--yes)    AUTO_YES=true ;;
            -h|--help)   show_help; exit 0 ;;
            *)
                # For restore, the next positional arg is the file
                if [[ "$command" == "restore" && -z "$restore_file" && ! "${args[$i]}" == --* ]]; then
                    restore_file="${args[$i]}"
                fi
                ;;
        esac
        ((i++))
    done

    case "$command" in
        export)
            header "Exporting Browser Sessions"
            do_export "$format" "$target_browser" "$target_profile" "$output_file"
            ;;
        list)
            do_list
            ;;
        restore)
            header "Restoring Browser Session"
            if [[ -z "$restore_file" ]]; then
                restore_file="latest"
            fi
            do_restore "$restore_file" "$target_browser"
            ;;
        convert)
            if [[ -z "$restore_file" ]]; then
                error "Specify a file to convert"
                exit 1
            fi
            header "Converting Session Export"
            # Read the file and re-export in new format
            info "Converting to $format format..."
            # Extract URLs and re-format
            local urls=""
            case "$restore_file" in
                *.json)
                    urls=$(python3 -c "
import json
with open('$restore_file') as f:
    data = json.load(f)
for tab in data.get('tabs', []):
    b = tab.get('browser','')
    i = tab.get('install_type','')
    p = tab.get('profile','')
    w = tab.get('window',0)
    t = tab.get('title','')
    u = tab.get('url','')
    print(f'{b}|{i}|{p}|{w}|{t}|{u}')
" 2>/dev/null)
                    ;;
                *)
                    error "Conversion currently supports JSON input. Export as JSON first."
                    exit 1
                    ;;
            esac

            local output
            case "$format" in
                html)     output=$(format_html "$urls") ;;
                markdown) output=$(format_markdown "$urls") ;;
                text)     output=$(format_text "$urls") ;;
                *)        error "Unknown format: $format"; exit 1 ;;
            esac

            if [[ -n "$output_file" ]]; then
                echo "$output" > "$output_file"
                success "Converted to $output_file"
            else
                echo "$output"
            fi
            ;;
        *)
            show_help
            ;;
    esac
}

main "$@"
