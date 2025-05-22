#!/bin/bash

# Source required files
SOURCE_URL="${SOURCE_URL:-https://raw.githubusercontent.com/zenkiet/home-server/refs/heads/main}"
source <(curl -fsSL $SOURCE_URL/source/colors.sh)
source <(curl -fsSL $SOURCE_URL/source/utils.sh)

# Function to configure dropbear SSH
configure_dropbear() {
    print_step "Configuring Dropbear SSH server..."
    
    # Check if dropbear is installed
    if ! command_exists "dropbear"; then
        print_error "Dropbear SSH server is not installed!"
        return 1
    fi
    
    # Create dropbear configuration directory
    local dropbear_config_dir="/etc/dropbear"
    if [ ! -d "$dropbear_config_dir" ]; then
        print_step "Creating Dropbear configuration directory..."
        mkdir -p "$dropbear_config_dir"
        print_success "Dropbear configuration directory created"
    fi
    
    # Generate host keys if they don't exist
    generate_host_keys
    
    # Configure dropbear settings
    configure_dropbear_settings
    
    # Ask if user wants to enable and start the service
    if ask_yes_no "Do you want to enable and start Dropbear SSH service?" "y"; then
        if enable_service "dropbear" "Dropbear SSH"; then
            print_success "Dropbear SSH service is now running"
            
            # Show connection information
            show_connection_info
        else
            print_error "Failed to start Dropbear SSH service"
            return 1
        fi
    else
        print_info "Dropbear SSH service not started"
    fi
    
    print_success "Dropbear SSH configuration completed!"
}

# Function to generate host keys
generate_host_keys() {
    local dropbear_config_dir="/etc/dropbear"
    local rsa_key="$dropbear_config_dir/dropbear_rsa_host_key"
    local dss_key="$dropbear_config_dir/dropbear_dss_host_key"
    local ecdsa_key="$dropbear_config_dir/dropbear_ecdsa_host_key"
    
    print_step "Generating Dropbear host keys..."
    
    # Generate RSA key
    if [ ! -f "$rsa_key" ]; then
        print_info "Generating RSA host key..."
        if dropbearkey -t rsa -f "$rsa_key" -s 2048; then
            print_success "RSA host key generated"
        else
            print_error "Failed to generate RSA host key"
        fi
    else
        print_info "RSA host key already exists"
    fi
    
    # Generate DSS key
    if [ ! -f "$dss_key" ]; then
        print_info "Generating DSS host key..."
        if dropbearkey -t dss -f "$dss_key"; then
            print_success "DSS host key generated"
        else
            print_error "Failed to generate DSS host key"
        fi
    else
        print_info "DSS host key already exists"
    fi
    
    # Generate ECDSA key
    if [ ! -f "$ecdsa_key" ]; then
        print_info "Generating ECDSA host key..."
        if dropbearkey -t ecdsa -f "$ecdsa_key" -s 256; then
            print_success "ECDSA host key generated"
        else
            print_error "Failed to generate ECDSA host key"
        fi
    else
        print_info "ECDSA host key already exists"
    fi
    
    # Set proper permissions
    chmod 600 "$dropbear_config_dir"/dropbear_*_host_key 2>/dev/null || true
}

# Function to configure dropbear settings
configure_dropbear_settings() {
    local dropbear_conf="/etc/conf.d/dropbear"
    
    print_step "Configuring Dropbear settings..."
    
    # Backup existing configuration
    backup_file "$dropbear_conf"
    
    # Create dropbear configuration
    cat > "$dropbear_conf" << 'EOF'
# Dropbear SSH server configuration

# Port to listen on (default: 22)
DROPBEAR_PORT="22"

# Additional options
# -w: Disable root login
# -s: Disable password authentication (key-only)
# -g: Disable password authentication for root
# -B: Allow blank passwords (NOT RECOMMENDED)
# -T: Maximum authentication tries before disconnecting (default: 10)
# -c: Force a command to be executed
# -m: Don't display the motd on login
# -p: Listen on specified address and port

# Basic secure configuration
DROPBEAR_OPTS="-p ${DROPBEAR_PORT}"

# Uncomment the following line to disable root password login (recommended)
# DROPBEAR_OPTS="${DROPBEAR_OPTS} -g"

# Uncomment the following line to disable all password authentication (key-only)
# DROPBEAR_OPTS="${DROPBEAR_OPTS} -s"

# Uncomment the following line to disable root login completely
# DROPBEAR_OPTS="${DROPBEAR_OPTS} -w"
EOF
    
    print_success "Dropbear configuration created"
    
    # Ask about security settings
    configure_security_settings
}

# Function to configure security settings
configure_security_settings() {
    print_step "Configuring security settings..."
    
    local dropbear_conf="/etc/conf.d/dropbear"
    
    # Ask about root password login
    if ask_yes_no "Do you want to disable root password login? (recommended for security)" "y"; then
        sed -i 's/# DROPBEAR_OPTS="${DROPBEAR_OPTS} -g"/DROPBEAR_OPTS="${DROPBEAR_OPTS} -g"/' "$dropbear_conf"
        print_success "Root password login disabled"
    fi
    
    # Ask about password authentication
    if ask_yes_no "Do you want to disable all password authentication (key-only)?" "n"; then
        sed -i 's/# DROPBEAR_OPTS="${DROPBEAR_OPTS} -s"/DROPBEAR_OPTS="${DROPBEAR_OPTS} -s"/' "$dropbear_conf"
        print_success "Password authentication disabled (key-only)"
        print_warning "Make sure you have SSH keys configured before enabling this!"
    fi
    
    # Ask about root login
    if ask_yes_no "Do you want to disable root login completely?" "n"; then
        sed -i 's/# DROPBEAR_OPTS="${DROPBEAR_OPTS} -w"/DROPBEAR_OPTS="${DROPBEAR_OPTS} -w"/' "$dropbear_conf"
        print_success "Root login disabled"
        print_warning "Make sure you have another user account configured!"
    fi
    
    # Ask about custom port
    if ask_yes_no "Do you want to change the SSH port from default (22)?" "n"; then
        printf "${CYAN}Enter the new SSH port (1024-65535): ${NC}"
        read -r new_port
        
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1024 ] && [ "$new_port" -le 65535 ]; then
            sed -i "s/DROPBEAR_PORT=\"22\"/DROPBEAR_PORT=\"$new_port\"/" "$dropbear_conf"
            print_success "SSH port changed to $new_port"
        else
            print_warning "Invalid port number. Using default port 22"
        fi
    fi
}

# Function to show connection information
show_connection_info() {
    print_step "Connection Information:"
    
    # Get IP addresses
    local ip_addresses=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1)
    
    # Get SSH port
    local ssh_port=$(grep 'DROPBEAR_PORT=' /etc/conf.d/dropbear | cut -d'"' -f2)
    
    echo -e "${WHITE}SSH Server Information:${NC}"
    echo -e "${CYAN}  Service Status:${NC} $(rc-status | grep dropbear | awk '{print $NF}')"
    echo -e "${CYAN}  Port:${NC} $ssh_port"
    echo -e "${CYAN}  Available IP addresses:${NC}"
    
    for ip in $ip_addresses; do
        echo -e "    ssh root@${ip} -p ${ssh_port}"
    done
    
    echo -e "\n${YELLOW}Security Notes:${NC}"
    echo -e "  - Consider using SSH keys instead of passwords"
    echo -e "  - Change default port if exposed to internet"
    echo -e "  - Use fail2ban for additional protection"
    echo -e "  - Regularly update the system"
}

# Main execution when script is run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    configure_dropbear
fi
