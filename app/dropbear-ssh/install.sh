#!/bin/bash

# Source required files
SOURCE_URL="${SOURCE_URL:-https://raw.githubusercontent.com/zenkiet/home-server/refs/heads/main}"
source <(curl -fsSL $SOURCE_URL/source/colors.sh)
source <(curl -fsSL $SOURCE_URL/source/utils.sh)

# Function to install dropbear SSH
install_dropbear() {
    print_step "Installing Dropbear SSH server..."
    
    # Install dropbear package
    if ! install_package "dropbear" "Dropbear SSH server"; then
        return 1
    fi
    
    # Ask user if they want to configure and start dropbear
    if ask_yes_no "Do you want to configure and start Dropbear SSH server?" "y"; then
        source <(curl -fsSL $SOURCE_URL/app/dropbear-ssh/config.sh)
        configure_dropbear
    else
        print_info "Dropbear SSH server configuration skipped"
    fi
    
    return 0
}

# Main execution when script is run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    check_root
    install_dropbear
fi
