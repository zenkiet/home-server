#!/bin/bash
# System utilities
# Author: ZenKiet

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        return 1
    fi
    return 0
}

# Check if running on Alpine Linux
check_alpine() {
    if [[ ! -f /etc/alpine-release ]]; then
        log_error "This script is designed for Alpine Linux only"
        return 1
    fi
    return 0
}

# Check internet connectivity
check_internet() {
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log_debug "Internet connectivity confirmed via ping to 8.8.8.8"
        return 0
    fi
    
    log_error "No internet connectivity detected"
    return 1
}

# Check required commands
check_dependencies() {
    local required_commands=(
        "curl"
        "apk"
        "grep"
        "awk"
        "sed"
    )
    
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        return 1
    fi
    
    return 0
}

# Get Alpine version
get_alpine_version() {
    if [[ -f /etc/alpine-release ]]; then
        cat /etc/alpine-release
    else
        echo "unknown"
    fi
}

# Get system architecture
get_arch() {
    uname -m
}

# Check if package is installed
is_package_installed() {
    local package="$1"
    apk info --installed "$package" >/dev/null 2>&1
}

# Install package with error handling
install_package() {
    local package="$1"
    local description="${2:-$package}"
    
    if is_package_installed "$package"; then
        log_info "$description is already installed"
        return 0
    fi
    
    log_info "Installing $description..."
    if apk add --no-cache "$package" >/dev/null 2>&1; then
        log_success "$description installed successfully"
        return 0
    else
        log_error "Failed to install $description"
        return 1
    fi
}

# Update package repository
update_repository() {
    log_info "Updating package repository..."
    if apk update >/dev/null 2>&1; then
        log_success "Package repository updated"
        return 0
    else
        log_error "Failed to update package repository"
        return 1
    fi
}

# Backup file with timestamp
backup_file() {
    local file="$1"
    local backup_dir="${2:-/tmp/alpine-pm-backup}"
    
    [[ -f "$file" ]] || return 0
    
    mkdir -p "$backup_dir"
    local backup_file="$backup_dir/$(basename "$file").$(date +%Y%m%d_%H%M%S).bak"
    
    if cp "$file" "$backup_file" 2>/dev/null; then
        log_debug "Backed up $file to $backup_file"
        return 0
    else
        log_warning "Failed to backup $file"
        return 1
    fi
}

# Restore file from backup
restore_file() {
    local original_file="$1"
    local backup_file="$2"
    
    if [[ -f "$backup_file" ]]; then
        if cp "$backup_file" "$original_file" 2>/dev/null; then
            log_success "Restored $original_file from backup"
            return 0
        else
            log_error "Failed to restore $original_file"
            return 1
        fi
    else
        log_error "Backup file not found: $backup_file"
        return 1
    fi
}

# Check if array contains element
array_contains() {
    local element="$1"
    shift
    local array=("$@")
    
    for item in "${array[@]}"; do
        [[ "$item" == "$element" ]] && return 0
    done
    return 1
}

# Remove element from array
array_remove() {
    local element="$1"
    local -n array_ref="$2"
    local new_array=()
    
    for item in "${array_ref[@]}"; do
        [[ "$item" != "$element" ]] && new_array+=("$item")
    done
    
    array_ref=("${new_array[@]}")
}

# Create temporary directory
create_temp_dir() {
    local prefix="${1:-alpine-pm}"
    local temp_dir
    temp_dir=$(mktemp -d -t "${prefix}.XXXXXX")
    echo "$temp_dir"
}

# Cleanup temporary directory
cleanup_temp_dir() {
    local temp_dir="$1"
    if [[ -d "$temp_dir" && "$temp_dir" == /tmp/* ]]; then
        rm -rf "$temp_dir"
        log_debug "Cleaned up temporary directory: $temp_dir"
    fi
}

# Download file with retry
download_file() {
    local url="$1"
    local output="$2"
    local max_retries="${3:-3}"
    local retry_delay="${4:-2}"
    
    for ((i = 1; i <= max_retries; i++)); do
        if curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$output"; then
            log_debug "Downloaded $url to $output"
            return 0
        else
            log_warning "Download attempt $i failed for $url"
            [[ $i -lt $max_retries ]] && sleep "$retry_delay"
        fi
    done
    
    log_error "Failed to download $url after $max_retries attempts"
    return 1
}

# Validate URL
validate_url() {
    local url="$1"
    if curl -fsSL --head --connect-timeout 5 "$url" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Service management
start_service() {
    local service="$1"
    if rc-service "$service" start >/dev/null 2>&1; then
        log_success "Service $service started"
        return 0
    else
        log_error "Failed to start service $service"
        return 1
    fi
}

stop_service() {
    local service="$1"
    if rc-service "$service" stop >/dev/null 2>&1; then
        log_success "Service $service stopped"
        return 0
    else
        log_error "Failed to stop service $service"
        return 1
    fi
}

enable_service() {
    local service="$1"
    local runlevel="${2:-default}"
    if rc-update add "$service" "$runlevel" >/dev/null 2>&1; then
        log_success "Service $service enabled for runlevel $runlevel"
        return 0
    else
        log_error "Failed to enable service $service"
        return 1
    fi
}

is_service_running() {
    local service="$1"
    rc-service "$service" status >/dev/null 2>&1
}