#!/usr/bin/env bash
# schedule-cleanup.sh - Set up automatic scheduled browser cache cleaning
# Creates a systemd user timer or cron job
# https://github.com/chiefgyk3d/Browser_Cleanup_Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

SERVICE_NAME="browser-cleanup"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

show_help() {
    cat <<EOF
${BOLD}Scheduled Cleanup Setup${NC}

Set up automatic periodic browser cache cleaning using systemd timers
or cron jobs.

Usage: $(basename "$0") <command> [OPTIONS]

Commands:
  install              Install the scheduled cleanup timer
  uninstall            Remove the scheduled cleanup timer
  status               Show current timer status
  run-now              Trigger an immediate cleanup run

Options:
  --interval <spec>    How often to run (default: weekly)
                       Systemd: daily, weekly, monthly, or OnCalendar spec
                       Cron: daily, weekly, monthly
  --use-cron           Use cron instead of systemd timer
  --deep               Enable deep cleaning on scheduled runs
  --with-oauth         Include OAuth token reset (Thunderbird) on scheduled runs
  -h, --help           Show this help message

Examples:
  $(basename "$0") install                        # Weekly systemd timer
  $(basename "$0") install --interval daily       # Daily cleanup
  $(basename "$0") install --interval monthly     # Monthly cleanup
  $(basename "$0") install --deep                 # Weekly deep clean
  $(basename "$0") install --use-cron             # Use cron instead
  $(basename "$0") status                         # Check timer status
  $(basename "$0") uninstall                      # Remove timer
EOF
}

# Convert interval name to systemd OnCalendar spec
interval_to_calendar() {
    case "$1" in
        daily)   echo "daily" ;;
        weekly)  echo "weekly" ;;
        monthly) echo "monthly" ;;
        *)       echo "$1" ;;  # Allow raw OnCalendar specs
    esac
}

# Convert interval to cron schedule
interval_to_cron() {
    case "$1" in
        daily)   echo "0 3 * * *" ;;      # 3 AM daily
        weekly)  echo "0 3 * * 0" ;;      # 3 AM Sunday
        monthly) echo "0 3 1 * *" ;;      # 3 AM 1st of month
        *)       echo "0 3 * * 0" ;;      # Default weekly
    esac
}

install_systemd() {
    local interval="$1"
    local extra_args="$2"
    local calendar_spec
    calendar_spec=$(interval_to_calendar "$interval")

    mkdir -p "$SYSTEMD_USER_DIR"

    # Create the service unit
    cat > "$SYSTEMD_USER_DIR/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Browser Cleanup Tools - Automatic Cache Cleaning
Documentation=https://github.com/chiefgyk3d/Browser_Cleanup_Tools

[Service]
Type=oneshot
ExecStart=/bin/bash ${SCRIPT_DIR}/clean-all.sh -y ${extra_args}
Environment=HOME=${HOME}
Nice=19
IOSchedulingClass=idle

[Install]
WantedBy=default.target
EOF

    # Create the timer unit
    cat > "$SYSTEMD_USER_DIR/${SERVICE_NAME}.timer" <<EOF
[Unit]
Description=Browser Cleanup Tools - Scheduled Timer
Documentation=https://github.com/chiefgyk3d/Browser_Cleanup_Tools

[Timer]
OnCalendar=${calendar_spec}
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF

    # Enable and start the timer
    systemctl --user daemon-reload
    systemctl --user enable "${SERVICE_NAME}.timer"
    systemctl --user start "${SERVICE_NAME}.timer"

    success "Systemd timer installed and started!"
    echo ""
    info "Timer schedule: $calendar_spec"
    info "Cleanup args: -y $extra_args"
    echo ""
    info "Useful commands:"
    echo "  systemctl --user status ${SERVICE_NAME}.timer    # Check timer"
    echo "  systemctl --user list-timers                     # List all timers"
    echo "  journalctl --user -u ${SERVICE_NAME}.service     # View logs"
    echo "  systemctl --user start ${SERVICE_NAME}.service   # Run now"
}

install_cron() {
    local interval="$1"
    local extra_args="$2"
    local cron_schedule
    cron_schedule=$(interval_to_cron "$interval")

    local cron_line="${cron_schedule} /bin/bash ${SCRIPT_DIR}/clean-all.sh -y ${extra_args} >> ${HOME}/.local/log/browser-cleanup.log 2>&1"

    # Create log directory
    mkdir -p "$HOME/.local/log"

    # Check if already installed
    if crontab -l 2>/dev/null | grep -q "browser-cleanup\|clean-all.sh"; then
        warn "Existing browser cleanup cron job found. Replacing..."
        crontab -l 2>/dev/null | grep -v "browser-cleanup\|clean-all.sh" | crontab -
    fi

    # Add new cron entry
    (crontab -l 2>/dev/null; echo "# Browser Cleanup Tools - automatic cache cleaning"; echo "$cron_line") | crontab -

    success "Cron job installed!"
    echo ""
    info "Schedule: $cron_schedule"
    info "Cleanup args: -y $extra_args"
    info "Log file: $HOME/.local/log/browser-cleanup.log"
    echo ""
    info "View with: crontab -l"
}

uninstall_systemd() {
    if [[ -f "$SYSTEMD_USER_DIR/${SERVICE_NAME}.timer" ]]; then
        systemctl --user stop "${SERVICE_NAME}.timer" 2>/dev/null || true
        systemctl --user disable "${SERVICE_NAME}.timer" 2>/dev/null || true
        rm -f "$SYSTEMD_USER_DIR/${SERVICE_NAME}.timer"
        rm -f "$SYSTEMD_USER_DIR/${SERVICE_NAME}.service"
        systemctl --user daemon-reload
        success "Systemd timer removed"
    else
        info "No systemd timer found"
    fi
}

uninstall_cron() {
    if crontab -l 2>/dev/null | grep -q "browser-cleanup\|clean-all.sh"; then
        crontab -l 2>/dev/null | grep -v "browser-cleanup\|clean-all.sh\|# Browser Cleanup" | crontab -
        success "Cron job removed"
    else
        info "No cron job found"
    fi
}

show_status() {
    header "Scheduled Cleanup Status"

    # Check systemd timer
    if [[ -f "$SYSTEMD_USER_DIR/${SERVICE_NAME}.timer" ]]; then
        echo -e "${BOLD}Systemd Timer:${NC} ${GREEN}Installed${NC}"
        echo ""
        systemctl --user status "${SERVICE_NAME}.timer" --no-pager 2>/dev/null || true
        echo ""
        echo -e "${BOLD}Next run:${NC}"
        systemctl --user list-timers "${SERVICE_NAME}.timer" --no-pager 2>/dev/null || true
        echo ""
        echo -e "${BOLD}Last run log:${NC}"
        journalctl --user -u "${SERVICE_NAME}.service" --no-pager -n 10 2>/dev/null || info "No logs yet"
    else
        echo -e "${BOLD}Systemd Timer:${NC} Not installed"
    fi

    echo ""

    # Check cron
    if crontab -l 2>/dev/null | grep -q "browser-cleanup\|clean-all.sh"; then
        echo -e "${BOLD}Cron Job:${NC} ${GREEN}Installed${NC}"
        echo ""
        crontab -l 2>/dev/null | grep -A1 "browser-cleanup\|Browser Cleanup\|clean-all.sh"
        if [[ -f "$HOME/.local/log/browser-cleanup.log" ]]; then
            echo ""
            echo -e "${BOLD}Last log entries:${NC}"
            tail -20 "$HOME/.local/log/browser-cleanup.log" 2>/dev/null || true
        fi
    else
        echo -e "${BOLD}Cron Job:${NC} Not installed"
    fi
}

run_now() {
    if [[ -f "$SYSTEMD_USER_DIR/${SERVICE_NAME}.service" ]]; then
        info "Triggering systemd service..."
        systemctl --user start "${SERVICE_NAME}.service"
        success "Cleanup triggered. Check logs with: journalctl --user -u ${SERVICE_NAME}.service -f"
    else
        info "No systemd service found. Running clean-all.sh directly..."
        bash "$SCRIPT_DIR/clean-all.sh" -y
    fi
}

main() {
    local command=""
    local interval="weekly"
    local use_cron=false
    local extra_args=""

    for arg in "$@"; do
        case "$arg" in
            install|uninstall|status|run-now) command="$arg" ;;
            --use-cron) use_cron=true ;;
            --deep)     extra_args="$extra_args --deep" ;;
            --with-oauth) extra_args="$extra_args --thunderbird-oauth" ;;
            -h|--help)  show_help; exit 0 ;;
        esac
    done

    # Parse --interval
    local prev=""
    for arg in "$@"; do
        if [[ "$prev" == "--interval" ]]; then
            interval="$arg"
        fi
        prev="$arg"
    done

    extra_args=$(echo "$extra_args" | xargs)  # trim whitespace

    case "$command" in
        install)
            header "Installing Scheduled Cleanup"
            if [[ "$use_cron" == "true" ]]; then
                install_cron "$interval" "$extra_args"
            else
                # Check if systemd user session is available
                if systemctl --user status >/dev/null 2>&1; then
                    install_systemd "$interval" "$extra_args"
                else
                    warn "Systemd user session not available. Falling back to cron."
                    install_cron "$interval" "$extra_args"
                fi
            fi
            ;;
        uninstall)
            header "Removing Scheduled Cleanup"
            uninstall_systemd
            uninstall_cron
            ;;
        status)
            show_status
            ;;
        run-now)
            run_now
            ;;
        *)
            show_help
            exit 0
            ;;
    esac
}

main "$@"
