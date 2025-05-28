#!/bin/bash
# Edge Repositories Component
# Author: ZenKiet

# Component information
component_name() {
    echo "Edge Repositories"
}

component_description() {
    echo "Configure Alpine Linux to use edge repositories for latest packages"
}

component_dependencies() {
    echo ""  # No dependencies
}

component_category() {
    echo "system"
}

# Installation function
install_edge_repositories() {
    print_step "Installing Edge Repositories..."
    
    # Check if repositories are already configured correctly
    if is_edge_configured; then
        print_info "Edge repositories are already configured!"
        return 0
    fi
    
    print_step "Configuring Alpine repositories to edge version..."
    
    # Backup original repositories file
    if ! backup_file "/etc/apk/repositories"; then
        print_error "Failed to backup repositories file!"
        return 1
    fi
    
    # Create new repositories file with edge repositories
    cat > /etc/apk/repositories << 'EOF'
# Alpine Edge repositories - configured by Alpine Package Manager
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
#http://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF
    
    if [[ $? -eq 0 ]]; then
        print_success "Repositories file updated successfully!"
        
        # Update package index
        if update_repository; then
            print_success "Edge repositories configured successfully!"
            
            # Show available packages count
            local package_count
            package_count=$(apk search 2>/dev/null | wc -l)
            print_info "Available packages: $package_count"
            
            return 0
        else
            print_error "Failed to update package index with new repositories!"
            # Restore backup if update fails
            restore_backup "/etc/apk/repositories"
            return 1
        fi
    else
        print_error "Failed to update repositories file!"
        restore_backup "/etc/apk/repositories"
        return 1
    fi
}

# Check if edge repositories are configured
is_edge_configured() {
    grep -q "http://dl-cdn.alpinelinux.org/alpine/edge/main" /etc/apk/repositories 2>/dev/null && \
    grep -q "http://dl-cdn.alpinelinux.org/alpine/edge/community" /etc/apk/repositories 2>/dev/null
}

# Show current repository configuration
show_repository_status() {
    print_info "Current repository configuration:"
    if [[ -f /etc/apk/repositories ]]; then
        while IFS= read -r line; do
            if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
                print_info "  ✓ $line"
            fi
        done < /etc/apk/repositories
    else
        print_warning "No repositories file found"
    fi
}

# Enable testing repository
enable_testing_repository() {
    print_step "Enabling testing repository..."
    
    if grep -q "^http://dl-cdn.alpinelinux.org/alpine/edge/testing" /etc/apk/repositories 2>/dev/null; then
        print_info "Testing repository is already enabled"
        return 0
    fi
    
    # Backup current file
    backup_file "/etc/apk/repositories"
    
    # Add testing repository
    sed -i 's|^#http://dl-cdn.alpinelinux.org/alpine/edge/testing|http://dl-cdn.alpinelinux.org/alpine/edge/testing|' /etc/apk/repositories
    
    # If not found, add it
    if ! grep -q "testing" /etc/apk/repositories; then
        echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
    fi
    
    # Update package index
    if update_repository; then
        print_success "Testing repository enabled successfully!"
        return 0
    else
        print_error "Failed to update package index"
        return 1
    fi
}

# Restore stable repositories
restore_stable_repositories() {
    print_step "Restoring stable repositories..."
    
    # Get Alpine version
    local alpine_version
    alpine_version=$(get_alpine_version | cut -d. -f1-2)
    
    if [[ -z "$alpine_version" ]]; then
        alpine_version="3.18"  # Default to latest stable
    fi
    
    # Backup current file
    backup_file "/etc/apk/repositories"
    
    # Create stable repositories file
    cat > /etc/apk/repositories << EOF
# Alpine stable repositories - v${alpine_version}
http://dl-cdn.alpinelinux.org/alpine/v${alpine_version}/main
http://dl-cdn.alpinelinux.org/alpine/v${alpine_version}/community
EOF
    
    if update_repository; then
        print_success "Stable repositories restored (v${alpine_version})"
        return 0
    else
        print_error "Failed to restore stable repositories"
        return 1
    fi
}

# Component status check
component_status() {
    if is_edge_configured; then
        echo "installed"
    else
        echo "not-installed"
    fi
}

# Component validation
component_validate() {
    # Check internet connectivity
    if ! curl -fsSL --head "http://dl-cdn.alpinelinux.org/alpine/edge/main" >/dev/null 2>&1; then
        print_error "Cannot reach Alpine edge repositories"
        return 1
    fi
    
    return 0
}

# Component uninstall
component_uninstall() {
    print_step "Uninstalling edge repositories configuration..."
    restore_stable_repositories
}

# Main installation function (compatible with installer)
main() {
    install_edge_repositories
}

# Legacy function name for compatibility
update_repositories() {
    install_edge_repositories
}

# Main execution when script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Source required dependencies if available
    if declare -f check_root >/dev/null 2>&1; then
        check_root || exit 1
    fi
    
    install_edge_repositories
fi