#!/bin/bash
# Package management utilities
# Author: ZenKiet

# Search for package
package_search() {
    local query="$1"
    log_info "Searching for packages matching: $query"
    apk search "$query" 2>/dev/null || {
        log_warning "No packages found matching: $query"
        return 1
    }
}

# Get package information
package_info() {
    local package="$1"
    if is_package_installed "$package"; then
        apk info "$package" 2>/dev/null
    else
        log_warning "Package $package is not installed"
        return 1
    fi
}

# List installed packages
package_list_installed() {
    log_info "Listing installed packages..."
    apk info --installed 2>/dev/null
}

# List available packages
package_list_available() {
    log_info "Listing available packages..."
    apk search 2>/dev/null
}

# Check package dependencies
package_dependencies() {
    local package="$1"
    log_info "Checking dependencies for: $package"
    apk info --depends "$package" 2>/dev/null || {
        log_warning "Could not retrieve dependencies for: $package"
        return 1
    }
}

# Check which packages depend on this package
package_reverse_dependencies() {
    local package="$1"
    log_info "Checking reverse dependencies for: $package"
    apk info --who-owns "$package" 2>/dev/null || {
        log_warning "No packages depend on: $package"
        return 1
    }
}

# Remove package
package_remove() {
    local package="$1"
    local force="${2:-false}"
    
    if ! is_package_installed "$package"; then
        log_warning "Package $package is not installed"
        return 1
    fi
    
    log_info "Removing package: $package"
    
    if [[ "$force" == "true" ]]; then
        apk del --force "$package" >/dev/null 2>&1
    else
        apk del "$package" >/dev/null 2>&1
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "Package $package removed successfully"
        return 0
    else
        log_error "Failed to remove package: $package"
        return 1
    fi
}

# Upgrade package
package_upgrade() {
    local package="$1"
    
    if [[ -n "$package" ]]; then
        log_info "Upgrading package: $package"
        apk upgrade "$package" >/dev/null 2>&1
    else
        log_info "Upgrading all packages..."
        apk upgrade >/dev/null 2>&1
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "Package upgrade completed"
        return 0
    else
        log_error "Package upgrade failed"
        return 1
    fi
}

# Clean package cache
package_clean_cache() {
    log_info "Cleaning package cache..."
    if apk cache clean >/dev/null 2>&1; then
        log_success "Package cache cleaned"
        return 0
    else
        log_error "Failed to clean package cache"
        return 1
    fi
}

# Fix broken packages
package_fix() {
    log_info "Fixing broken packages..."
    if apk fix >/dev/null 2>&1; then
        log_success "Package fixes applied"
        return 0
    else
        log_error "Failed to fix packages"
        return 1
    fi
}

# Verify package integrity
package_verify() {
    local package="$1"
    
    if [[ -n "$package" ]]; then
        log_info "Verifying package: $package"
        apk verify "$package" >/dev/null 2>&1
    else
        log_info "Verifying all packages..."
        apk verify >/dev/null 2>&1
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "Package verification completed"
        return 0
    else
        log_error "Package verification failed"
        return 1
    fi
}

# Get package size
package_size() {
    local package="$1"
    if is_package_installed "$package"; then
        apk info --size "$package" 2>/dev/null | awk '{print $1}'
    else
        log_warning "Package $package is not installed"
        return 1
    fi
}

# Get package version
package_version() {
    local package="$1"
    if is_package_installed "$package"; then
        apk info "$package" 2>/dev/null | head -1 | awk '{print $1}'
    else
        # Try to get version from available packages
        apk search "$package" 2>/dev/null | grep "^$package-" | head -1 | awk '{print $1}'
    fi
}

# List package files
package_files() {
    local package="$1"
    if is_package_installed "$package"; then
        log_info "Files installed by package: $package"
        apk info --contents "$package" 2>/dev/null
    else
        log_warning "Package $package is not installed"
        return 1
    fi
}

# Find which package owns a file
package_owns_file() {
    local file="$1"
    log_info "Finding package that owns: $file"
    apk info --who-owns "$file" 2>/dev/null || {
        log_warning "No package owns file: $file"
        return 1
    }
}

# Check if package is available in repositories
package_is_available() {
    local package="$1"
    apk search "^$package$" >/dev/null 2>&1
}

# Add repository
package_add_repository() {
    local repo_url="$1"
    local repo_file="/etc/apk/repositories"
    
    # Backup original repositories file
    backup_file "$repo_file"
    
    # Check if repository already exists
    if grep -q "$repo_url" "$repo_file" 2>/dev/null; then
        log_info "Repository already exists: $repo_url"
        return 0
    fi
    
    # Add repository
    echo "$repo_url" >> "$repo_file"
    log_success "Repository added: $repo_url"
    
    # Update package index
    update_repository
}

# Remove repository
package_remove_repository() {
    local repo_url="$1"
    local repo_file="/etc/apk/repositories"
    
    # Backup original repositories file
    backup_file "$repo_file"
    
    # Remove repository
    if grep -q "$repo_url" "$repo_file" 2>/dev/null; then
        sed -i "\|$repo_url|d" "$repo_file"
        log_success "Repository removed: $repo_url"
        update_repository
    else
        log_warning "Repository not found: $repo_url"
        return 1
    fi
}

# List repositories
package_list_repositories() {
    log_info "Current repositories:"
    cat /etc/apk/repositories 2>/dev/null || {
        log_error "Could not read repositories file"
        return 1
    }
}

# Batch install packages
package_batch_install() {
    local packages=("$@")
    local failed_packages=()
    local success_count=0
    
    log_info "Installing ${#packages[@]} packages..."
    
    for package in "${packages[@]}"; do
        if install_package "$package"; then
            ((success_count++))
        else
            failed_packages+=("$package")
        fi
    done
    
    log_info "Installation completed: $success_count/${#packages[@]} packages successful"
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warning "Failed packages: ${failed_packages[*]}"
        return 1
    fi
    
    return 0
}

# Get package statistics
package_stats() {
    local total_installed
    local total_available
    local cache_size
    
    total_installed=$(apk info --installed 2>/dev/null | wc -l)
    total_available=$(apk search 2>/dev/null | wc -l)
    cache_size=$(du -sh /var/cache/apk 2>/dev/null | awk '{print $1}')
    
    log_info "Package Statistics:"
    log_info "  Installed packages: $total_installed"
    log_info "  Available packages: $total_available"
    log_info "  Cache size: ${cache_size:-unknown}"
}

# Export installed packages list
package_export_list() {
    local output_file="${1:-/tmp/installed-packages.txt}"
    
    log_info "Exporting installed packages to: $output_file"
    
    if apk info --installed 2>/dev/null > "$output_file"; then
        log_success "Package list exported to: $output_file"
        return 0
    else
        log_error "Failed to export package list"
        return 1
    fi
}

# Import and install packages from list
package_import_list() {
    local input_file="$1"
    
    if [[ ! -f "$input_file" ]]; then
        log_error "Package list file not found: $input_file"
        return 1
    fi
    
    log_info "Importing packages from: $input_file"
    
    local packages=()
    while IFS= read -r package; do
        [[ -n "$package" && ! "$package" =~ ^[[:space:]]*# ]] && packages+=("$package")
    done < "$input_file"
    
    if [[ ${#packages[@]} -gt 0 ]]; then
        package_batch_install "${packages[@]}"
    else
        log_warning "No packages found in: $input_file"
        return 1
    fi
}