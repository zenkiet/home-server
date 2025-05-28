#!/bin/bash

# Source required files
SOURCE_URL="${SOURCE_URL:-https://raw.githubusercontent.com/zenkiet/home-server/refs/heads/main}"
source <(curl -fsSL $SOURCE_URL/source/colors.sh)
source <(curl -fsSL $SOURCE_URL/source/utils.sh)

# Function to install fish shell
install_fish() {
    print_step "Installing Fish shell..."
    
    # Install fish package
    if ! install_package "fish" "Fish shell"; then
        return 1
    fi
    
    # Ask user if they want to configure fish as default shell
    if ask_yes_no "Do you want to configure Fish shell?" "y"; then
        source <(curl -fsSL $SOURCE_URL/app/fish-shell/config.sh)
        configure_fish
    else
        print_info "Fish shell configuration skipped"
    fi
    
    return 0
}

# Main execution when script is run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    check_root
    install_fish
fi