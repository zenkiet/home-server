#!/bin/bash

# Source required files
SOURCE_URL="${SOURCE_URL:-https://raw.githubusercontent.com/zenkiet/home-server/refs/heads/main}"
source <(curl -fsSL $SOURCE_URL/source/colors.sh)
source <(curl -fsSL $SOURCE_URL/source/utils.sh)

# Function to update repositories to edge version
update_repositories() {
    print_step "Checking Alpine repositories configuration..."
    
    # Check if repositories are already configured correctly
    if grep -q "http://dl-cdn.alpinelinux.org/alpine/edge/main" /etc/apk/repositories 2>/dev/null && \
       grep -q "http://dl-cdn.alpinelinux.org/alpine/edge/community" /etc/apk/repositories 2>/dev/null; then
        print_info "Repositories are already configured for edge version!"
        return 0
    fi
    
    print_step "Updating Alpine repositories to edge version..."
    
    # Backup original repositories file
    if ! backup_file "/etc/apk/repositories"; then
        print_error "Failed to backup repositories file!"
        return 1
    fi
    
    # Create new repositories file with edge repositories
    cat > /etc/apk/repositories << 'EOF'
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Repositories file updated successfully!"
        
        # Update package index
        if update_package_index; then
            print_success "Edge repositories configured successfully!"
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

# Main execution when script is run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    check_root
    update_repositories
fi
