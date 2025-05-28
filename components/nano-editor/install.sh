#!/bin/bash

# Source required files
SOURCE_URL="${SOURCE_URL:-https://raw.githubusercontent.com/zenkiet/home-server/refs/heads/main}"
source <(curl -fsSL $SOURCE_URL/source/colors.sh)
source <(curl -fsSL $SOURCE_URL/source/utils.sh)

# Function to install nano editor
install_nano() {
    print_step "Installing Nano editor..."
    
    # Install nano package
    if ! install_package "nano" "Nano editor"; then
        return 1
    fi
    
    # Create basic nano configuration
    create_nano_config
    
    print_success "Nano editor installation completed!"
    return 0
}

# Function to create basic nano configuration
create_nano_config() {
    local nano_config_file="/etc/nanorc"
    
    if [ ! -f "$nano_config_file" ] || ! grep -q "# ZenKiet nano config" "$nano_config_file" 2>/dev/null; then
        print_step "Creating basic Nano configuration..."
        
        # Backup existing config if it exists
        backup_file "$nano_config_file"
        
        cat >> "$nano_config_file" << 'EOF'

# ZenKiet nano config
# Enable syntax highlighting
include "/usr/share/nano/*.nanorc"

# Enable line numbers
set linenumbers

# Enable mouse support
set mouse

# Set tab size to 4
set tabsize 4

# Convert tabs to spaces
set tabstospaces

# Enable auto-indentation
set autoindent

# Enable smooth scrolling
set smooth

# Show cursor position
set constantshow

# Enable word wrapping
set softwrap

# Highlight current line
set cursorpos

# Enable search highlighting
set casesensitive

# Enable backup files
set backup
set backupdir "/tmp"

# Enable undo
set undo
EOF
        
        print_success "Basic Nano configuration created"
    else
        print_info "Nano configuration already exists"
    fi
}

# Main execution when script is run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    check_root
    install_nano
fi
