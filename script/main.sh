#!/bin/bash

# Declare var
SOURCE_URL="https://raw.githubusercontent.com/zenkiet/home-server/refs/heads/main"

# Source required files
source <(curl -fsSL $SOURCE_URL/source/colors.sh)
source <(curl -fsSL $SOURCE_URL/source/utils.sh)

declare -A menu_items=(
    ["Edge Repositories"]="Update Alpine repositories to edge version"
    ["Fish Shell"]="Install and configure Fish shell"
    ["Nano Editor"]="Install Nano text editor"
    ["Dropbear SSH"]="Install and configure Dropbear SSH server"
)

# Selected items array
declare -a selected_items=()

# Function to display menu
show_menu() {
    clear
    print_header

    # Print menu title
    echo -e "${WHITE}Select components to install:${NC}\n"

    # Get array of menu keys
    local -a menu_keys=("${!menu_items[@]}")

    # Display menu items
    for i in "${!menu_keys[@]}"; do
        local item="${menu_keys[$i]}"
        local desc="${menu_items[$item]}"

        # Create menu line with proper alignment
        if [ $i -eq $selected ]; then
            printf "${CYAN}➤${NC} "
        else
            printf "  "
        fi

        # Show checkbox and item name
        if [[ " ${selected_items[@]} " =~ " $i " ]]; then
            printf "${GREEN}[✓]${NC} ${BOLD}${item}${NC}"
        else
            printf "${WHITE}[ ]${NC} ${item}"
        fi

        # Add description on the same line
        printf "  ${YELLOW}${desc}${NC}\n"
    done

    # Print help text
    echo -e "\n${WHITE}Navigation:${NC}"
    echo -e "  ${CYAN}↑/↓${NC} - Move selection"
    echo -e "  ${CYAN}C${NC} - Select/deselect item"
    echo -e "  ${CYAN}ENTER${NC} - Confirm selection"
    echo -e "  ${CYAN}q${NC} - Quit\n"

    # Print selection status
    if [ ${#selected_items[@]} -gt 0 ]; then
        echo -e "${GREEN}Selected items: ${#selected_items[@]}${NC}"
    else
        echo -e "${YELLOW}No items selected${NC}"
    fi
}

# Function to toggle selection
toggle_selection() {
    local index=$1
    if [[ " ${selected_items[@]} " =~ " $index " ]]; then
        # Remove item from array
        selected_items=(${selected_items[@]/$index})
    else
        # Add item to array
        selected_items+=($index)
    fi
}

# Function to handle menu interaction
handle_menu() {
    local key
    local selected=0
    local menu_size=${#menu_items[@]}

    while true; do
        show_menu

        # Read a single character
        read -rsn1 key

        case "$key" in
            'c'|'C'|' ') # Selected or Space
                toggle_selection $selected
                ;;
            '') # Enter
                if [ ${#selected_items[@]} -gt 0 ]; then
                    break
                else
                    print_warning "Please select at least one item"
                    sleep 1
                fi
                ;;
            'q'|'Q') # Quit
                print_warning "Installation cancelled by user"
                exit 0
                ;;
            $'\x1B') # Escape sequence
                read -rsn2 key
                case "$key" in
                    "[A") # Up arrow
                        if [ $selected -gt 0 ]; then
                            selected=$((selected - 1))
                        else
                            selected=$((menu_size - 1))
                        fi
                        ;;
                    "[B") # Down arrow
                        if [ $selected -lt $((menu_size - 1)) ]; then
                            selected=$((selected + 1))
                        else
                            selected=0
                        fi
                        ;;
                esac
                ;;
        esac
    done
}

# Function to execute selected items
execute_selected() {
    if [ ${#selected_items[@]} -eq 0 ]; then
        print_warning "No items selected. Exiting..."
        exit 0
    fi

    print_step "Starting installation of selected components..."

    # Get array of menu keys
    local -a menu_keys=("${!menu_items[@]}")

    for index in "${selected_items[@]}"; do
        local item="${menu_keys[$index]}"
        print_step "Installing: $item"

        case $index in
            0) # Update Repositories
                source <(curl -fsSL $SOURCE_URL/app/edge-repositories/install.sh)
                update_repositories
                ;;
            1) # Install Fish
                source <(curl -fsSL $SOURCE_URL/app/fish-shell/install.sh)
                install_fish
                ;;
            2) # Install Nano
                source <(curl -fsSL $SOURCE_URL/app/nano-editor/install.sh)
                install_nano
                ;;
            3) # Install Dropbear
                source <(curl -fsSL $SOURCE_URL/app/dropbear-ssh/install.sh)
                install_dropbear
                ;;
        esac
    done

    print_success "Installation completed!"
}

# Main function
main() {
    # Check if running as root
    check_root
    
    # Handle menu interaction
    handle_menu
    
    # Execute selected components
    execute_selected
}

# Run main function
main
