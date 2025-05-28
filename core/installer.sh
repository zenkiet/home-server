#!/bin/bash

# Installation Service
# Author: ZenKiet

# Global installer variables
declare -ga COMPONENT_REGISTRY=()
declare -ga INSTALLATION_QUEUE=()
declare -ga INSTALLED_COMPONENTS=()
declare -ga FAILED_COMPONENTS=()

# Main installer function
installer_run() {
    local selected_components=("$@")
    
    if [[ ${#selected_components[@]} -eq 0 ]]; then
        log_error "No components selected for installation"
        return 1
    fi
    
    log_info "Starting installation process for ${#selected_components[@]} component(s)"
    
    # Initialize installer
    installer_init || {
        log_error "Failed to initialize installer"
        return 1
    }
    
    # Build installation queue with dependencies
    if ! installer_build_queue "${selected_components[@]}"; then
        log_error "Failed to build installation queue"
        return 1
    fi
    
    # Execute installation
    if installer_execute_queue; then
        installer_report_success
        return 0
    else
        installer_report_failure
        return 1
    fi
}

# Initialize installer
installer_init() {
    # Clear global arrays
    COMPONENT_REGISTRY=()
    INSTALLATION_QUEUE=()
    INSTALLED_COMPONENTS=()
    FAILED_COMPONENTS=()
    
    # Discover available components
    installer_discover_components || {
        log_error "Component discovery failed"
        return 1
    }
    
    # Validate system prerequisites
    installer_check_prerequisites || {
        log_error "System prerequisites check failed"
        return 1
    }
    
    log_debug "Installer initialized successfully"
    return 0
}

# Discover available components
installer_discover_components() {
    log_info "Discovering available components..."
    
    local components
    components=$(config_get_components) || {
        log_error "Failed to get components from configuration"
        return 1
    }
    
    while IFS= read -r component; do
        if [[ -n "$component" ]]; then
            if installer_validate_component "$component"; then
                COMPONENT_REGISTRY+=("$component")
                log_debug "Discovered component: $component"
            else
                log_warning "Invalid component: $component"
            fi
        fi
    done <<< "$components"
    
    if [[ ${#COMPONENT_REGISTRY[@]} -eq 0 ]]; then
        log_error "No valid components found"
        return 1
    fi
    
    log_success "Discovered ${#COMPONENT_REGISTRY[@]} components"
    return 0
}

# Validate component
installer_validate_component() {
    local component="$1"
    
    # Check if component exists in configuration
    if ! config_component_exists "$component"; then
        log_debug "Component $component not found in configuration"
        return 1
    fi
    
    # Check if component script exists (for remote components)
    local component_url="$SOURCE_URL/components/$component/install.sh"
    if ! validate_url "$component_url"; then
        log_debug "Component script not accessible: $component_url"
        return 1
    fi
    
    return 0
}

# Check system prerequisites
installer_check_prerequisites() {
    log_info "Checking system prerequisites..."
    
    # Check if running as root
    check_root || return 1
    
    # Check if running on Alpine
    check_alpine || return 1
    
    # Check internet connectivity
    check_internet || return 1
    
    # Check required commands
    check_dependencies || return 1
    
    # Check system resources
    check_system_requirements 256 500 || return 1
    
    # Update package repository
    update_repository || return 1
    
    log_success "System prerequisites satisfied"
    return 0
}

# Build installation queue with dependency resolution
installer_build_queue() {
    local selected_components=("$@")
    
    log_info "Building installation queue..."
    
    # Clear installation queue
    INSTALLATION_QUEUE=()
    
    # Process each selected component
    for component in "${selected_components[@]}"; do
        local dependency_tree
        dependency_tree=$(config_get_dependency_tree "$component") || {
            log_error "Failed to resolve dependencies for: $component"
            return 1
        }
        
        # Add components from dependency tree to queue
        while IFS= read -r dep_component; do
            if [[ -n "$dep_component" ]]; then
                if ! array_contains "$dep_component" "${INSTALLATION_QUEUE[@]}"; then
                    INSTALLATION_QUEUE+=("$dep_component")
                fi
            fi
        done <<< "$dependency_tree"
    done
    
    # Sort queue by priority
    local sorted_queue
    sorted_queue=$(config_sort_by_priority "${INSTALLATION_QUEUE[@]}")
    INSTALLATION_QUEUE=()
    while IFS= read -r component; do
        [[ -n "$component" ]] && INSTALLATION_QUEUE+=("$component")
    done <<< "$sorted_queue"
    
    log_success "Installation queue built with ${#INSTALLATION_QUEUE[@]} component(s)"
    log_debug "Installation order: ${INSTALLATION_QUEUE[*]}"
    
    return 0
}

# Execute installation queue
installer_execute_queue() {
    local total_components=${#INSTALLATION_QUEUE[@]}
    local current_component=0
    
    log_info "Executing installation queue (${total_components} components)..."
    
    for component in "${INSTALLATION_QUEUE[@]}"; do
        ((current_component++))
        
        # Show progress
        print_progress "$current_component" "$total_components" "Installing components"
        
        # Install component
        if installer_install_component "$component"; then
            INSTALLED_COMPONENTS+=("$component")
            log_success "[$current_component/$total_components] $component installed successfully"
        else
            FAILED_COMPONENTS+=("$component")
            log_error "[$current_component/$total_components] Failed to install: $component"
            
            # Ask user if they want to continue
            if ! installer_handle_failure "$component"; then
                log_error "Installation aborted by user"
                return 1
            fi
        fi
    done
    
    # Report final results
    local success_count=${#INSTALLED_COMPONENTS[@]}
    local failure_count=${#FAILED_COMPONENTS[@]}
    
    if [[ $failure_count -eq 0 ]]; then
        log_success "All components installed successfully!"
        return 0
    elif [[ $success_count -gt 0 ]]; then
        log_warning "Installation completed with errors: $success_count succeeded, $failure_count failed"
        return 1
    else
        log_error "Installation failed: no components were installed"
        return 1
    fi
}

# Install individual component
installer_install_component() {
    local component="$1"
    
    log_info "Installing component: $component"
    
    # Get component information
    local name description
    name=$(config_get_component_name "$component")
    description=$(config_get_component_description "$component")
    
    log_debug "Component: $name - $description"
    
    # Check if already installed (basic check)
    if installer_is_component_installed "$component"; then
        log_info "Component $component is already installed, skipping..."
        return 0
    fi
    
    # Create temporary directory for installation
    local temp_dir
    temp_dir=$(create_temp_dir "installer-$component")
    
    # Download component installer script
    local install_script="$temp_dir/install.sh"
    local script_url="$SOURCE_URL/components/$component/install.sh"
    
    if ! download_file "$script_url" "$install_script"; then
        log_error "Failed to download installer script for: $component"
        cleanup_temp_dir "$temp_dir"
        return 1
    fi
    
    # Make script executable
    chmod +x "$install_script"
    
    # Set environment variables for the component script
    export COMPONENT_NAME="$component"
    export COMPONENT_DISPLAY_NAME="$name"
    export COMPONENT_DESCRIPTION="$description"
    export TEMP_DIR="$temp_dir"
    
    # Execute installation script
    local install_result=0
    (
        cd "$temp_dir" || exit 1
        
        # Source the install script
        if source "$install_script"; then
            # Look for standard installation function
            if declare -f "install_${component//-/_}" >/dev/null 2>&1; then
                "install_${component//-/_}"
            elif declare -f "install_$component" >/dev/null 2>&1; then
                "install_$component"
            elif declare -f "main" >/dev/null 2>&1; then
                main
            else
                log_error "No installation function found in $component installer"
                exit 1
            fi
        else
            log_error "Failed to source installer script for: $component"
            exit 1
        fi
    )
    install_result=$?
    
    # Cleanup
    cleanup_temp_dir "$temp_dir"
    unset COMPONENT_NAME COMPONENT_DISPLAY_NAME COMPONENT_DESCRIPTION TEMP_DIR
    
    if [[ $install_result -eq 0 ]]; then
        # Mark component as installed
        installer_mark_installed "$component"
        return 0
    else
        return 1
    fi
}

# Check if component is installed (basic implementation)
installer_is_component_installed() {
    local component="$1"
    
    # Check if component is in our installed list
    array_contains "$component" "${INSTALLED_COMPONENTS[@]}" && return 0
    
    # Check if marker file exists
    [[ -f "/etc/alpine-pm/installed/$component" ]] && return 0
    
    # Component-specific checks could be added here
    case "$component" in
        "nano-editor")
            is_package_installed "nano"
            ;;
        "fish-shell")
            is_package_installed "fish"
            ;;
        "dropbear-ssh")
            is_package_installed "dropbear"
            ;;
        *)
            return 1
            ;;
    esac
}

# Mark component as installed
installer_mark_installed() {
    local component="$1"
    local install_dir="/etc/alpine-pm/installed"
    
    # Create directory if it doesn't exist
    mkdir -p "$install_dir"
    
    # Create marker file with installation info
    cat > "$install_dir/$component" << EOF
# Alpine Package Manager - Component Installation Record
component=$component
name=$(config_get_component_name "$component")
description=$(config_get_component_description "$component")
category=$(config_get_component_category "$component")
installed_date=$(date '+%Y-%m-%d %H:%M:%S')
installed_by=$(whoami)
alpine_version=$(get_alpine_version)
EOF
    
    log_debug "Marked component as installed: $component"
}

# Handle installation failure
installer_handle_failure() {
    local component="$1"
    
    printf "\n${RED}Failed to install component: $component${NC}\n"
    printf "Do you want to continue with the remaining components? ${GREEN}[Y]es${NC} / ${RED}[N]o${NC}: "
    
    local choice
    read -rsn1 choice
    printf "\n"
    
    case "${choice,,}" in
        'y'|$'\n'|$'\r'|'')
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Report installation success
installer_report_success() {
    print_header
    printf "${GREEN}${BOLD}Installation Completed Successfully!${NC}\n\n"
    
    printf "Installed components:\n"
    for component in "${INSTALLED_COMPONENTS[@]}"; do
        local name
        name=$(config_get_component_name "$component")
        printf "  ${GREEN}✓${NC} ${BOLD}%s${NC} (%s)\n" "$name" "$component"
    done
    
    printf "\n${WHITE}Total components installed: ${GREEN}${BOLD}%d${NC}\n" "${#INSTALLED_COMPONENTS[@]}"
    
    # Show next steps
    printf "\n${CYAN}${BOLD}Next Steps:${NC}\n"
    printf "  • Review component configurations\n"
    printf "  • Start/enable any services if needed\n"
    printf "  • Check component-specific documentation\n"
    printf "  • Run 'apk list --installed' to see all packages\n"
    
    printf "\n${DIM}Installation log: %s${NC}\n" "$LOG_FILE"
}

# Report installation failure
installer_report_failure() {
    print_header
    printf "${RED}${BOLD}Installation Completed With Errors${NC}\n\n"
    
    if [[ ${#INSTALLED_COMPONENTS[@]} -gt 0 ]]; then
        printf "${GREEN}Successfully installed:${NC}\n"
        for component in "${INSTALLED_COMPONENTS[@]}"; do
            local name
            name=$(config_get_component_name "$component")
            printf "  ${GREEN}✓${NC} ${BOLD}%s${NC} (%s)\n" "$name" "$component"
        done
        printf "\n"
    fi
    
    if [[ ${#FAILED_COMPONENTS[@]} -gt 0 ]]; then
        printf "${RED}Failed to install:${NC}\n"
        for component in "${FAILED_COMPONENTS[@]}"; do
            local name
            name=$(config_get_component_name "$component")
            printf "  ${RED}✗${NC} ${BOLD}%s${NC} (%s)\n" "$name" "$component"
        done
        printf "\n"
    fi
    
    printf "${WHITE}Results: ${GREEN}%d successful${NC}, ${RED}%d failed${NC}\n" \
        "${#INSTALLED_COMPONENTS[@]}" "${#FAILED_COMPONENTS[@]}"
    
    printf "\n${YELLOW}${BOLD}Troubleshooting:${NC}\n"
    printf "  • Check the installation log for details: %s\n" "$LOG_FILE"
    printf "  • Verify internet connectivity\n"
    printf "  • Ensure sufficient disk space\n"
    printf "  • Try running the installer again\n"
}

# List installed components
installer_list_installed() {
    local install_dir="/etc/alpine-pm/installed"
    
    if [[ ! -d "$install_dir" ]]; then
        log_info "No components installed yet"
        return 0
    fi
    
    log_info "Installed components:"
    
    for marker_file in "$install_dir"/*; do
        [[ -f "$marker_file" ]] || continue
        
        local component
        component=$(basename "$marker_file")
        
        # Read installation info
        local name installed_date
        name=$(grep "^name=" "$marker_file" 2>/dev/null | cut -d= -f2-)
        installed_date=$(grep "^installed_date=" "$marker_file" 2>/dev/null | cut -d= -f2-)
        
        printf "  ${GREEN}✓${NC} ${BOLD}%s${NC} (%s) - installed %s\n" \
            "${name:-$component}" "$component" "${installed_date:-unknown}"
    done
}

# Uninstall component
installer_uninstall_component() {
    local component="$1"
    
    if [[ -z "$component" ]]; then
        log_error "Component name is required"
        return 1
    fi
    
    local install_marker="/etc/alpine-pm/installed/$component"
    
    if [[ ! -f "$install_marker" ]]; then
        log_error "Component $component is not installed (no installation record found)"
        return 1
    fi
    
    log_info "Uninstalling component: $component"
    
    # Component-specific uninstallation
    case "$component" in
        "nano-editor")
            package_remove "nano"
            ;;
        "fish-shell")
            package_remove "fish"
            ;;
        "dropbear-ssh")
            stop_service "dropbear" 2>/dev/null || true
            service_disable "dropbear" 2>/dev/null || true
            package_remove "dropbear"
            ;;
        *)
            log_warning "No specific uninstall procedure for: $component"
            ;;
    esac
    
    # Remove installation marker
    rm -f "$install_marker"
    
    log_success "Component $component uninstalled"
}

# Get installer statistics
installer_get_stats() {
    local total_available=${#COMPONENT_REGISTRY[@]}
    local total_installed
    
    if [[ -d "/etc/alpine-pm/installed" ]]; then
        total_installed=$(find /etc/alpine-pm/installed -type f | wc -l)
    else
        total_installed=0
    fi
    
    printf "Installer Statistics:\n"
    printf "  Available components: %d\n" "$total_available"
    printf "  Installed components: %d\n" "$total_installed"
    
    if [[ ${#INSTALLATION_QUEUE[@]} -gt 0 ]]; then
        printf "  Queued for installation: %d\n" "${#INSTALLATION_QUEUE[@]}"
    fi
    
    if [[ ${#FAILED_COMPONENTS[@]} -gt 0 ]]; then
        printf "  Failed components: %d\n" "${#FAILED_COMPONENTS[@]}"
    fi
}

# Validate all components
installer_validate_all() {
    log_info "Validating all components..."
    
    local valid_count=0
    local invalid_count=0
    
    local components
    components=$(config_get_components)
    
    while IFS= read -r component; do
        if [[ -n "$component" ]]; then
            if installer_validate_component "$component"; then
                ((valid_count++))
                log_debug "✓ $component"
            else
                ((invalid_count++))
                log_warning "✗ $component"
            fi
        fi
    done <<< "$components"
    
    log_info "Validation complete: $valid_count valid, $invalid_count invalid"
    
    return $([[ $invalid_count -eq 0 ]])
}