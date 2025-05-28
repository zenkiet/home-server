#!/bin/bash
# Menu System
# Author: ZenKiet

source <(curl -fsSL "$SOURCE_URL/utils/system.sh") || {
    echo "Failed to load system module"
    exit 1
}

# Global menu variables
declare -ga MENU_ITEMS=()
declare -ga SELECTED_ITEMS=()
declare -gi CURRENT_SELECTION=0

# Initialize menu from configuration
menu_init() {
    local components
    components=$(config_get_components) || {
        log_error "Failed to get components from configuration"
        return 1
    }
    
    # Clear existing menu items
    MENU_ITEMS=()
    
    # Build menu items from components
    while IFS= read -r component; do
        if [[ -n "$component" ]]; then
            local name description category
            name=$(config_get_component_name "$component")
            description=$(config_get_component_description "$component")
            category=$(config_get_component_category "$component")
            
            MENU_ITEMS+=("$component:$name:$description:$category")
            log_debug "Added menu item: $component ($name)"
        fi
    done <<< "$components"
    
    if [[ ${#MENU_ITEMS[@]} -eq 0 ]]; then
        log_error "No components found in configuration"
        return 1
    fi
    
    log_debug "Menu initialized with ${#MENU_ITEMS[@]} items"
    return 0
}

# Display menu interface
menu_show() {
    # Initialize menu
    menu_init || return 1
    
    # Clear selected items
    SELECTED_ITEMS=()
    CURRENT_SELECTION=0
    
    local key
    
    while true; do
        menu_render
        
        # Read user input
        read -rsn1 key
        
        case "$key" in
            $'\x1B')  # Escape sequences (arrow keys)
                read -rsn2 key
                case "$key" in
                    "[A") menu_move_up ;;
                    "[B") menu_move_down ;;
                esac
                ;;
            ' '|'c'|'C')  # Space or C to toggle selection
                menu_toggle_selection
                ;;
            $'\n'|$'\r')  # Enter to confirm
                if menu_confirm; then
                    break
                fi
                ;;
            'q'|'Q')  # Quit
                log_info "Installation cancelled by user"
                return 1
                ;;
            'a'|'A')  # Select all
                menu_select_all
                ;;
            'd'|'D')  # Deselect all
                menu_deselect_all
                ;;
            'h'|'H'|'?')  # Help
                menu_show_help
                ;;
        esac
    done
    
    # Set global selected components
    SELECTED_COMPONENTS=()
    for index in "${SELECTED_ITEMS[@]}"; do
        local item="${MENU_ITEMS[$index]}"
        local component="${item%%:*}"
        SELECTED_COMPONENTS+=("$component")
    done
    
    log_debug "Selected components: ${SELECTED_COMPONENTS[*]}"
    return 0
}

# Render menu display
menu_render() {
    clear
    print_header
    
    # Show title and instructions
    printf "${WHITE}${BOLD}Select components to install:${NC}\n\n"
    
    # Group components by category
    local categories=()
    local category_items=()
    
    # Get all categories
    for item in "${MENU_ITEMS[@]}"; do
        IFS=':' read -r component name description category <<< "$item"
        if ! array_contains "$category" "${categories[@]}"; then
            categories+=("$category")
        fi
    done
    
    # Sort categories
    IFS=$'\n' categories=($(sort <<<"${categories[*]}"))
    
    local display_index=0
    
    # Display items grouped by category
    for cat in "${categories[@]}"; do
        # Category header
        printf "${PURPLE}${BOLD}┌─ %s ────────────────────────────────────────────────────┐${NC}\n" "$(echo "$cat" | tr '[:lower:]' '[:upper:]')"
        
        # Items in this category
        for i in "${!MENU_ITEMS[@]}"; do
            local item="${MENU_ITEMS[$i]}"
            IFS=':' read -r component name description item_category <<< "$item"
            
            if [[ "$item_category" == "$cat" ]]; then
                # Highlight current selection
                if [[ $display_index -eq $CURRENT_SELECTION ]]; then
                    printf "${PURPLE}│${CYAN}${BOLD} ➤ ${NC}"
                else
                    printf "${PURPLE}│${NC}   "
                fi
                
                # Show checkbox
                if array_contains "$display_index" "${SELECTED_ITEMS[@]}"; then
                    printf "${GREEN}[✓]${NC} "
                else
                    printf "${WHITE}[ ]${NC} "
                fi
                
                # Show component info
                printf "${BOLD}%-20s${NC} ${YELLOW}%s${NC}\n" "$name" "$description"
                
                ((display_index++))
            fi
        done
        
        printf "${PURPLE}└────────────────────────────────────────────────────────────┘${NC}\n\n"
    done
    
    menu_render_help
    menu_render_status
}

# Move selection up
menu_move_up() {
    if [[ $CURRENT_SELECTION -gt 0 ]]; then
        ((CURRENT_SELECTION--))
    else
        CURRENT_SELECTION=$((${#MENU_ITEMS[@]} - 1))
    fi
}

# Move selection down
menu_move_down() {
    if [[ $CURRENT_SELECTION -lt $((${#MENU_ITEMS[@]} - 1)) ]]; then
        ((CURRENT_SELECTION++))
    else
        CURRENT_SELECTION=0
    fi
}

# Toggle selection for current item
menu_toggle_selection() {
    if array_contains "$CURRENT_SELECTION" "${SELECTED_ITEMS[@]}"; then
        # Remove from selection
        local new_selected=()
        for item in "${SELECTED_ITEMS[@]}"; do
            [[ "$item" != "$CURRENT_SELECTION" ]] && new_selected+=("$item")
        done
        SELECTED_ITEMS=("${new_selected[@]}")
    else
        # Add to selection
        SELECTED_ITEMS+=("$CURRENT_SELECTION")
    fi
}

# Select all items
menu_select_all() {
    SELECTED_ITEMS=()
    for i in "${!MENU_ITEMS[@]}"; do
        SELECTED_ITEMS+=("$i")
    done
}

# Deselect all items
menu_deselect_all() {
    SELECTED_ITEMS=()
}

# Confirm selection
menu_confirm() {
    if [[ ${#SELECTED_ITEMS[@]} -eq 0 ]]; then
        clear
        print_error "Please select at least one component!"
        printf "\n${DIM}Press any key to continue...${NC}"
        read -rsn1
        return 1
    fi
    
    # Show confirmation
    clear
    print_header
    
    printf "${WHITE}${BOLD}Confirm Installation${NC}\n\n"
    printf "You have selected ${GREEN}${BOLD}%d${NC} component(s) for installation:\n\n" "${#SELECTED_ITEMS[@]}"
    
    # Show selected items with dependencies
    local total_components=()
    local has_dependencies=false
    
    for index in "${SELECTED_ITEMS[@]}"; do
        local item="${MENU_ITEMS[$index]}"
        IFS=':' read -r component name description category <<< "$item"
        
        printf "  ${GREEN}✓${NC} ${BOLD}%s${NC} - %s\n" "$name" "$description"
        
        # Check dependencies
        local deps
        deps=$(config_get_component_dependencies "$component")
        if [[ -n "$deps" ]]; then
            has_dependencies=true
            printf "    ${DIM}Dependencies: %s${NC}\n" "$deps"
            
            # Add dependencies to installation list
            for dep in $deps; do
                if ! array_contains "$dep" "${total_components[@]}"; then
                    total_components+=("$dep")
                fi
            done
        fi
        
        if ! array_contains "$component" "${total_components[@]}"; then
            total_components+=("$component")
        fi
    done
    
    if [[ "$has_dependencies" == "true" ]]; then
        printf "\n${YELLOW}Total components to install (including dependencies): ${BOLD}%d${NC}\n" "${#total_components[@]}"
    fi
    
    printf "\n${WHITE}Do you want to proceed with the installation? ${NC}"
    printf "${GREEN}[Y]es${NC} / ${RED}[N]o${NC} / ${BLUE}[B]ack${NC}: "
    
    local choice
    read -rsn1 choice
    
    case "${choice,,}" in
        'y'|$'\n'|$'\r')
            printf "\n\n${GREEN}Starting installation...${NC}\n"
            return 0
            ;;
        'n'|'q')
            printf "\n\n${RED}Installation cancelled.${NC}\n"
            exit 0
            ;;
        'b'|$'\x1B')
            return 1
            ;;
        *)
            printf "\n\n${RED}Invalid choice. Please press Y, N, or B.${NC}\n"
            sleep 1
            return 1
            ;;
    esac
}

# Render help text
menu_render_help() {
    print_divider
    printf "${DIM}Navigation: ${NC}${CYAN}↑/↓${NC} Move  ${CYAN}Space/C${NC} Select  ${CYAN}Enter${NC} Confirm  ${CYAN}Q${NC} Quit\n"
    printf "${DIM}Actions:    ${NC}${CYAN}A${NC} Select All  ${CYAN}D${NC} Deselect All  ${CYAN}H/?${NC} Help\n"
    print_divider
}

# Render status bar
menu_render_status() {
    local selected_count=${#SELECTED_ITEMS[@]}
    local total_count=${#MENU_ITEMS[@]}
    
    if [[ $selected_count -gt 0 ]]; then
        printf "${GREEN}Selected: %d/%d components${NC}" "$selected_count" "$total_count"
        
        # Show estimated installation time (rough estimate)
        local estimated_time=$((selected_count * 30))  # 30 seconds per component
        printf " ${DIM}(Est. time: %dm %ds)${NC}\n" $((estimated_time / 60)) $((estimated_time % 60))
    else
        printf "${YELLOW}No components selected${NC}\n"
    fi
}

# Show detailed help
menu_show_help() {
    clear
    print_header
    
    printf "${WHITE}${BOLD}Help - Alpine Package Manager${NC}\n\n"
    
    printf "${CYAN}${BOLD}Navigation:${NC}\n"
    printf "  ${CYAN}↑ / ↓${NC}     Move cursor up/down\n"
    printf "  ${CYAN}Space / C${NC} Toggle selection for current item\n"
    printf "  ${CYAN}Enter${NC}     Confirm selection and start installation\n"
    printf "  ${CYAN}Q${NC}         Quit without installing\n\n"
    
    printf "${CYAN}${BOLD}Actions:${NC}\n"
    printf "  ${CYAN}A${NC}         Select all components\n"
    printf "  ${CYAN}D${NC}         Deselect all components\n"
    printf "  ${CYAN}H / ?${NC}     Show this help screen\n\n"
    
    printf "${CYAN}${BOLD}Component Information:${NC}\n"
    printf "  Components are grouped by category\n"
    printf "  ${GREEN}[✓]${NC} indicates selected components\n"
    printf "  Dependencies will be automatically included\n\n"
    
    printf "${CYAN}${BOLD}Installation Process:${NC}\n"
    printf "  1. Select components using Space or C\n"
    printf "  2. Press Enter to review selection\n"
    printf "  3. Confirm to start installation\n"
    printf "  4. Components will be installed with dependencies\n\n"
    
    printf "${DIM}Press any key to return to menu...${NC}"
    read -rsn1
}

# Get menu statistics
menu_get_stats() {
    local total_components=${#MENU_ITEMS[@]}
    local selected_components=${#SELECTED_ITEMS[@]}
    local categories=()
    
    # Count categories
    for item in "${MENU_ITEMS[@]}"; do
        IFS=':' read -r component name description category <<< "$item"
        if ! array_contains "$category" "${categories[@]}"; then
            categories+=("$category")
        fi
    done
    
    printf "Menu Statistics:\n"
    printf "  Total components: %d\n" "$total_components"
    printf "  Categories: %d\n" "${#categories[@]}"
    printf "  Selected: %d\n" "$selected_components"
}

# Export menu selection to file
menu_export_selection() {
    local output_file="${1:-/tmp/selected-components.txt}"
    
    if [[ ${#SELECTED_ITEMS[@]} -eq 0 ]]; then
        log_warning "No components selected to export"
        return 1
    fi
    
    {
        printf "# Selected components - %s\n" "$(date)"
        printf "# Generated by Alpine Package Manager\n\n"
        
        for index in "${SELECTED_ITEMS[@]}"; do
            local item="${MENU_ITEMS[$index]}"
            IFS=':' read -r component name description category <<< "$item"
            printf "%s  # %s - %s\n" "$component" "$name" "$description"
        done
    } > "$output_file"
    
    log_success "Selection exported to: $output_file"
}

# Import menu selection from file
menu_import_selection() {
    local input_file="$1"
    
    if [[ ! -f "$input_file" ]]; then
        log_error "Selection file not found: $input_file"
        return 1
    fi
    
    local imported_components=()
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Extract component name (first word)
        local component
        component=$(echo "$line" | awk '{print $1}')
        [[ -n "$component" ]] && imported_components+=("$component")
    done < "$input_file"
    
    if [[ ${#imported_components[@]} -eq 0 ]]; then
        log_warning "No components found in selection file"
        return 1
    fi
    
    # Find matching menu items and select them
    SELECTED_ITEMS=()
    for component in "${imported_components[@]}"; do
        for i in "${!MENU_ITEMS[@]}"; do
            local item="${MENU_ITEMS[$i]}"
            local item_component="${item%%:*}"
            if [[ "$item_component" == "$component" ]]; then
                SELECTED_ITEMS+=("$i")
                break
            fi
        done
    done
    
    log_success "Imported ${#SELECTED_ITEMS[@]} components from selection file"
}