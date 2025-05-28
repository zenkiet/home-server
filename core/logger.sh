#!/bin/bash
# Centralized Logging
# Author: ZenKiet

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m' # No Color

# Log levels
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARNING=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_SUCCESS=4

# Global log level (can be overridden by LOG_LEVEL environment variable)
declare -gi CURRENT_LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Log file path
declare -g LOG_FILE="${LOG_FILE:-/var/log/alpine-package-manager.log}"

# Initialize logger
logger_init() {
    # Create log directory if it doesn't exist
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    [[ -d "$log_dir" ]] || mkdir -p "$log_dir"
    
    # Create log file if it doesn't exist
    [[ -f "$LOG_FILE" ]] || touch "$LOG_FILE"
    
    # Log session start
    log_info "=== Alpine Package Manager Session Started ==="
}

# Core logging function
_log() {
    local level="$1"
    local color="$2"
    local icon="$3"
    local message="$4"
    
    # Check if we should log this level
    [[ $level -ge $CURRENT_LOG_LEVEL ]] || return 0
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Console output with colors
    printf "${color}${icon} %s${NC}\n" "$message" >&2
    
    # File output without colors
    printf "[%s] [%s] %s\n" "$timestamp" "${level_names[$level]}" "$message" >> "$LOG_FILE"
}

# Level names for file logging
declare -ra level_names=(
    "DEBUG"
    "INFO"
    "WARNING"
    "ERROR"
    "SUCCESS"
)

# Logging functions
log_debug() {
    _log $LOG_LEVEL_DEBUG "$DIM" "🔍" "$*"
}

log_info() {
    _log $LOG_LEVEL_INFO "$BLUE" "ℹ️ " "$*"
}

log_warning() {
    _log $LOG_LEVEL_WARNING "$YELLOW" "⚠️ " "$*"
}

log_error() {
    _log $LOG_LEVEL_ERROR "$RED" "❌" "$*"
}

log_success() {
    _log $LOG_LEVEL_SUCCESS "$GREEN" "✅" "$*"
}

# Convenience aliases
logger_debug() { log_debug "$@"; }
logger_info() { log_info "$@"; }
logger_warning() { log_warning "$@"; }
logger_error() { log_error "$@"; }
logger_success() { log_success "$@"; }

# Print functions for direct output
print_header() {
    printf "\n${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}${BOLD}║               Alpine Linux Package Manager                  ║${NC}\n"
    printf "${CYAN}${BOLD}║                      by ZenKiet                             ║${NC}\n"
    printf "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}\n\n"
}

print_step() {
    printf "${BLUE}${BOLD}➤ %s${NC}\n" "$*"
}

print_success() {
    printf "${GREEN}${BOLD}✅ %s${NC}\n" "$*"
}

print_error() {
    printf "${RED}${BOLD}❌ %s${NC}\n" "$*" >&2
}

print_warning() {
    printf "${YELLOW}${BOLD}⚠️  %s${NC}\n" "$*" >&2
}

print_info() {
    printf "${WHITE}ℹ️  %s${NC}\n" "$*"
}

print_divider() {
    printf "${DIM}────────────────────────────────────────────────────────────────${NC}\n"
}

# Progress bar function
print_progress() {
    local current="$1"
    local total="$2"
    local desc="${3:-Processing}"
    local width=50
    
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    
    printf "\r${BLUE}%s: [" "$desc"
    printf "%*s" $filled | tr ' ' '█'
    printf "%*s" $((width - filled)) | tr ' ' '░'
    printf "] %d%% (%d/%d)${NC}" "$percent" "$current" "$total"
    
    if [[ $current -eq $total ]]; then
        printf "\n"
    fi
}

# Set log level from string
logger_set_level() {
    case "${1,,}" in
        debug) CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        info) CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
        warning|warn) CURRENT_LOG_LEVEL=$LOG_LEVEL_WARNING ;;
        error) CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        success) CURRENT_LOG_LEVEL=$LOG_LEVEL_SUCCESS ;;
        *) 
            log_error "Invalid log level: $1"
            return 1
            ;;
    esac
    log_info "Log level set to: ${level_names[$CURRENT_LOG_LEVEL]}"
}

# Cleanup old log files
logger_cleanup() {
    local days="${1:-7}"
    find "$(dirname "$LOG_FILE")" -name "*.log" -mtime +$days -delete 2>/dev/null || true
    log_info "Cleaned up log files older than $days days"
}