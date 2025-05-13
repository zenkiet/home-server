#!/bin/sh

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' 

# Color functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Function update repositories
update_repositories() {
    print_step "Updating Alpine repositories to edge version..."
    
    # Backup original repositories file
    if [ -f /etc/apk/repositories ]; then
        cp /etc/apk/repositories /etc/apk/repositories.backup
        print_info "Backup created at /etc/apk/repositories.backup"
    fi
    
    # Create new repositories file with edge repositories
    cat > /etc/apk/repositories << EOF
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Repositories file updated successfully!"
        
        # Update package index
        print_step "Updating package index..."
        if apk update; then
            print_success "Package index updated successfully!"
        else
            print_error "Failed to update package index!"
            # Restore backup if update fails
            mv /etc/apk/repositories.backup /etc/apk/repositories
            print_info "Restored original repositories from backup"
            exit 1
        fi
    else
        print_error "Failed to update repositories file!"
        exit 1
    fi
}

# Function to update packages
update_packages() {
    print_step "Updating packages..."
    if apk update && apk upgrade --no-cache; then
        print_success "Packages updated successfully!"
    else
        print_error "Failed to update packages!"
    fi
}

# Function to install fish shell
install_fish() {
    # check fish exist 
    if ! command -v fish &> /dev/null; then 
        print_info "Fish shell not found, installing..."
        if apk add fish; then
            print_success "Fish shell installed successfully!"
        else
            print_error "Failed to install fish shell!"
        fi
    else
        print_info "Fish shell already installed."
    fi
}

# Function to install nano editor
install_nano() {
    if ! command -v nano &> /dev/null; then
        print_info "Nano editor not found, installing..."
        if apk add nano; then
            print_success "Nano editor installed successfully!"
        else
            print_error "Failed to install nano editor!"
        fi
    else
        print_info "Nano editor already installed."
    fi
}

# Function to install dropbear
install_dropbear() {
    if ! command -v dropbear &> /dev/null; then
        print_info "Dropbear not found, installing..."
        if apk add dropbear; then
            print_success "Dropbear installed successfully!"
            # enable dropbear service
            print_step "Configuring dropbear service..."
            if rc-update add dropbear && rc-service dropbear start && rc-service dropbear enable; then
                print_success "Dropbear service enabled and started successfully!"
            else
                print_error "Failed to configure dropbear service!"
            fi
        else
            print_error "Failed to install dropbear!"
        fi
    else
        print_info "Dropbear already installed."
    fi
}

# Main function
main() {
    # Update package index
    update_repositories
    update_packages
    
    # Install packages
    install_fish
    install_nano
    install_dropbear
    
    print_success "Base installation completed!"
}

# Run main function
main
