#!/bin/bash
# Alpine Linux Package Manager
# Author: ZenKiet

set -euo pipefail # Strict error handling

# Project configuration
readonly SOURCE_URL="https://raw.githubusercontent.com/zenkiet/home-server/refs/heads/new"

# Source core modules
source <(curl -fsSL "$SOURCE_URL/core/logger.sh") || {
    echo "Failed to load logger module"
    exit 1
}

source <(curl -fsSL "$SOURCE_URL/utils/system.sh") || {
    echo "Failed to load system utilities"
    exit 1
}

source <(curl -fsSL "$SOURCE_URL/utils/package.sh") || {
    echo "Failed to load package utilities"
    exit 1
}

source <(curl -fsSL "$SOURCE_URL/utils/service.sh") || {
    echo "Failed to load service utilities"
    exit 1
}

source <(curl -fsSL "$SOURCE_URL/core/config.sh") || {
    echo "Failed to load config module"
    exit 1
}

source <(curl -fsSL "$SOURCE_URL/core/menu.sh") || {
    echo "Failed to load menu module"
    exit 1
}

source <(curl -fsSL "$SOURCE_URL/core/installer.sh") || {
    echo "Failed to load installer module"
    exit 1
}

# Global variables
declare -g CONFIG_FILE="${CONFIG_FILE:-$SOURCE_URL/configs/components.yaml}"
declare -ga SELECTED_COMPONENTS=()

# Main function
main() {
    trap cleanup EXIT ERR
    
    # Initialize logger
    logger_init
    
    # Show header
    print_header
    
    # Validate environment
    validate_environment || {
        logger_error "Environment validation failed!"
        exit 1
    }
    
    # Initialize configuration
    config_init "$CONFIG_FILE" || {
        logger_error "Configuration initialization failed!"
        exit 1
    }
    
    # Show configuration summary
    config_summary
    
    # Show interactive menu
    menu_show || {
        log_info "Installation cancelled by user"
        exit 0
    }
    
    # Install selected components
    installer_run "${SELECTED_COMPONENTS[@]}" || {
        log_error "Installation failed"
        exit 1
    }
    
    log_success "Installation completed successfully!"
}

# Environment validation
validate_environment() {
    log_info "Validating environment..."
    
    # Check if running as root
    check_root || return 1
    
    # Check if running on Alpine Linux
    check_alpine || return 1
    
    # Check internet connectivity
    check_internet || return 1
    
    # Check required dependencies
    check_dependencies || return 1
    
    log_success "Environment validation passed"
    return 0
}

# Cleanup function
cleanup() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script exited with error code: $exit_code"
    fi
    
    # Cleanup temporary files
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        cleanup_temp_dir "$TEMP_DIR"
    fi
    
    # Cleanup any downloaded config files
    if [[ "$CONFIG_FILE" =~ ^/tmp/ && -f "$CONFIG_FILE" ]]; then
        rm -f "$CONFIG_FILE" 2>/dev/null || true
    fi
    
    return $exit_code
}

# Show usage information
usage() {
    cat << EOF
Alpine Linux Package Manager

USAGE:
    $0 [OPTIONS] [COMMAND]

OPTIONS:
    -h, --help          Show this help message
    -v, --version       Show version information
    -c, --config FILE   Use custom configuration file
    -l, --log-level LVL Set log level (debug|info|warning|error)
    -q, --quiet         Quiet mode (minimal output)
    --no-color          Disable colored output

COMMANDS:
    install             Interactive installation (default)
    list                List available components
    installed           List installed components
    uninstall COMP      Uninstall a component
    validate            Validate all components
    stats               Show system statistics
    export FORMAT       Export configuration (json|env)

EXAMPLES:
    $0                          # Interactive installation
    $0 list                     # List all components
    $0 installed                # List installed components
    $0 uninstall nano-editor    # Uninstall nano editor
    $0 --config /path/to.yaml   # Use custom config
    $0 --log-level debug        # Enable debug logging

EOF
}

# Show version information
version() {
    cat << EOF
Alpine Linux Package Manager v1.0.0
Author: ZenKiet
Source: $SOURCE_URL

System Information:
  OS: $(cat /etc/alpine-release 2>/dev/null || echo "Unknown")
  Architecture: $(uname -m)
  Kernel: $(uname -r)
  
Loaded Modules:
  ✓ Logger
  ✓ System utilities
  ✓ Package utilities  
  ✓ Service utilities
  ✓ Configuration manager
  ✓ Menu system
  ✓ Installer
EOF
}

# List available components
list_components() {
    log_info "Available components:"
    
    local components
    components=$(config_get_components)
    
    if [[ -z "$components" ]]; then
        log_warning "No components found"
        return 1
    fi
    
    # Group by category
    local categories
    categories=$(config_get_categories)
    
    while IFS= read -r category; do
        printf "\n${PURPLE}${BOLD}%s:${NC}\n" "$(echo "$category" | tr '[:lower:]' '[:upper:]')"
        
        local cat_components
        cat_components=$(config_get_components_by_category "$category")
        
        while IFS= read -r component; do
            if [[ -n "$component" ]]; then
                local name description priority
                name=$(config_get_component_name "$component")
                description=$(config_get_component_description "$component")
                priority=$(config_get_component_priority "$component")
                
                # Check if installed
                local status_icon="${RED}○${NC}"
                if installer_is_component_installed "$component" 2>/dev/null; then
                    status_icon="${GREEN}●${NC}"
                fi
                
                printf "  %s ${BOLD}%-20s${NC} %s ${DIM}(priority: %s)${NC}\n" \
                    "$status_icon" "$name" "$description" "$priority"
            fi
        done <<< "$cat_components"
    done <<< "$categories"
    
    printf "\n${DIM}Legend: ${GREEN}●${NC} Installed, ${RED}○${NC} Not installed${NC}\n"
}

# Command line argument parsing
parse_args() {
    local command="install"
    local config_file=""
    local log_level=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                version
                exit 0
                ;;
            -c|--config)
                config_file="$2"
                shift 2
                ;;
            -l|--log-level)
                log_level="$2"
                shift 2
                ;;
            -q|--quiet)
                export LOG_LEVEL=$LOG_LEVEL_WARNING
                shift
                ;;
            --no-color)
                # Disable colors
                RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' WHITE='' BOLD='' DIM='' NC=''
                shift
                ;;
            list|installed|validate|stats)
                command="$1"
                shift
                ;;
            uninstall)
                command="uninstall"
                if [[ -n "${2:-}" ]]; then
                    UNINSTALL_COMPONENT="$2"
                    shift 2
                else
                    log_error "Component name required for uninstall command"
                    exit 1
                fi
                ;;
            export)
                command="export"
                if [[ -n "${2:-}" ]]; then
                    EXPORT_FORMAT="$2"
                    shift 2
                else
                    EXPORT_FORMAT="json"
                    shift
                fi
                ;;
            install)
                command="install"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Set configuration file if provided
    if [[ -n "$config_file" ]]; then
        CONFIG_FILE="$config_file"
    fi
    
    # Set log level if provided
    if [[ -n "$log_level" ]]; then
        logger_set_level "$log_level"
    fi
    
    # Execute command
    case "$command" in
        install)
            main
            ;;
        list)
            logger_init
            config_init "$CONFIG_FILE" || exit 1
            list_components
            ;;
        installed)
            logger_init
            installer_list_installed
            ;;
        uninstall)
            logger_init
            config_init "$CONFIG_FILE" || exit 1
            installer_uninstall_component "$UNINSTALL_COMPONENT"
            ;;
        validate)
            logger_init
            config_init "$CONFIG_FILE" || exit 1
            installer_validate_all
            ;;
        stats)
            logger_init
            config_init "$CONFIG_FILE" || exit 1
            print_system_stats
            ;;
        export)
            logger_init
            config_init "$CONFIG_FILE" || exit 1
            config_export "$EXPORT_FORMAT"
            ;;
    esac
}

# Print system statistics
print_system_stats() {
    print_header
    printf "${WHITE}${BOLD}System Statistics${NC}\n\n"
    
    # System information
    printf "${CYAN}${BOLD}System Information:${NC}\n"
    printf "  OS Version: %s\n" "$(get_alpine_version)"
    printf "  Architecture: %s\n" "$(get_arch)"
    printf "  Memory: %d MB\n" "$(get_memory_mb)"
    printf "  Available Disk: %d MB\n" "$(get_disk_space_mb)"
    printf "\n"
    
    # Package statistics
    printf "${CYAN}${BOLD}Package Statistics:${NC}\n"
    package_stats
    printf "\n"
    
    # Component statistics
    printf "${CYAN}${BOLD}Component Statistics:${NC}\n"
    installer_get_stats
    printf "\n"
    
    # Configuration summary
    config_summary
}

# Main entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -eq 0 ]]; then
        main
    else
        parse_args "$@"
    fi
fi