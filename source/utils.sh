#!/bin/bash

# Common utility functions for Alpine Linux package management

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a package is installed
package_installed() {
    apk info -e "$1" >/dev/null 2>&1
}

# Function to check if a service exists
service_exists() {
    [ -f "/etc/init.d/$1" ]
}

# Function to check if a service is enabled
service_enabled() {
    rc-status -s | grep -q "$1"
}

# Function to check if a service is running
service_running() {
    rc-status | grep -q "$1.*started"
}

# Function to install package if not already installed
install_package() {
    local package_name="$1"
    local display_name="${2:-$package_name}"
    
    if package_installed "$package_name"; then
        print_info "$display_name is already installed"
        return 0
    fi
    
    print_step "Installing $display_name..."
    if apk add --no-cache "$package_name"; then
        print_success "$display_name installed successfully!"
        return 0
    else
        print_error "Failed to install $display_name!"
        return 1
    fi
}

# Function to enable and start service
enable_service() {
    local service_name="$1"
    local display_name="${2:-$service_name}"
    
    if ! service_exists "$service_name"; then
        print_error "Service $service_name does not exist!"
        return 1
    fi
    
    print_step "Configuring $display_name service..."
    
    # Enable service
    if ! service_enabled "$service_name"; then
        if rc-update add "$service_name"; then
            print_info "$display_name service enabled"
        else
            print_error "Failed to enable $display_name service!"
            return 1
        fi
    else
        print_info "$display_name service is already enabled"
    fi
    
    # Start service
    if ! service_running "$service_name"; then
        if rc-service "$service_name" start; then
            print_success "$display_name service started successfully!"
        else
            print_error "Failed to start $display_name service!"
            return 1
        fi
    else
        print_info "$display_name service is already running"
    fi
    
    return 0
}

# Function to ask yes/no question
ask_yes_no() {
    local question="$1"
    local default="${2:-n}"
    local answer
    
    while true; do
        if [ "$default" = "y" ]; then
            printf "${CYAN}$question [Y/n]: ${NC}"
        else
            printf "${CYAN}$question [y/N]: ${NC}"
        fi
        
        read -r answer
        
        # Use default if empty
        if [ -z "$answer" ]; then
            answer="$default"
        fi
        
        case "$answer" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                print_warning "Please answer yes or no"
                ;;
        esac
    done
}

# Function to backup file
backup_file() {
    local file_path="$1"
    local backup_suffix="${2:-.backup}"
    
    if [ -f "$file_path" ]; then
        local backup_path="${file_path}${backup_suffix}"
        if cp "$file_path" "$backup_path"; then
            print_info "Backup created: $backup_path"
            return 0
        else
            print_error "Failed to create backup: $backup_path"
            return 1
        fi
    fi
    
    return 0
}

# Function to restore file from backup
restore_backup() {
    local file_path="$1"
    local backup_suffix="${2:-.backup}"
    local backup_path="${file_path}${backup_suffix}"
    
    if [ -f "$backup_path" ]; then
        if mv "$backup_path" "$file_path"; then
            print_info "Restored from backup: $file_path"
            return 0
        else
            print_error "Failed to restore from backup: $backup_path"
            return 1
        fi
    else
        print_warning "Backup file not found: $backup_path"
        return 1
    fi
}

# Function to check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script must be run as root!"
        exit 1
    fi
}

# Function to update package index
update_package_index() {
    print_step "Updating package index..."
    if apk update; then
        print_success "Package index updated successfully!"
        return 0
    else
        print_error "Failed to update package index!"
        return 1
    fi
} 