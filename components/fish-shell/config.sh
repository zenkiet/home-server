#!/bin/bash

# Source required files
SOURCE_URL="${SOURCE_URL:-https://raw.githubusercontent.com/zenkiet/home-server/refs/heads/main}"
source <(curl -fsSL $SOURCE_URL/source/colors.sh)
source <(curl -fsSL $SOURCE_URL/source/utils.sh)

# Function to configure fish shell
configure_fish() {
    print_step "Configuring Fish shell..."
    
    # Check if fish is installed
    if ! command_exists "fish"; then
        print_error "Fish shell is not installed!"
        return 1
    fi
    # Get fish path
    local fish_path=$(which fish)
    
    # Check if fish is already in /etc/shells
    if ! grep -q "$fish_path" /etc/shells 2>/dev/null; then
        print_step "Adding Fish shell to /etc/shells..."
        echo "$fish_path" >> /etc/shells
        print_success "Fish shell added to /etc/shells"
    else
        print_info "Fish shell is already in /etc/shells"
    fi
    
    # Ask if user wants to set fish as default shell for root
    if ask_yes_no "Do you want to set Fish as the default shell for root user?" "y"; then
        if chsh -s "$fish_path" root; then
            print_success "Fish shell set as default for root user"
        else
            print_error "Failed to set Fish as default shell for root user"
        fi
    fi
    
    # Create fish config directory
    local fish_config_dir="/root/.config/fish"
    if [ ! -d "$fish_config_dir" ]; then
        print_step "Creating Fish configuration directory..."
        mkdir -p "$fish_config_dir"
        print_success "Fish configuration directory created"
    fi
    
    # Create basic fish configuration
    local fish_config_file="$fish_config_dir/config.fish"
    if [ ! -f "$fish_config_file" ]; then
        print_step "Creating basic Fish configuration..."
        cat > "$fish_config_file" << 'EOF'
# Fish shell configuration

# Set greeting
set fish_greeting "Welcome to Fish shell on Alpine Linux!"

# Enable vi mode
fish_vi_key_bindings

# Set some useful aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Set PATH
set -gx PATH /usr/local/bin /usr/bin /bin /usr/local/sbin /usr/sbin /sbin

# Enable syntax highlighting
set fish_color_command blue
set fish_color_param cyan
set fish_color_redirection yellow
set fish_color_comment red
set fish_color_error red --bold
set fish_color_escape cyan
set fish_color_operator yellow
set fish_color_quote green
set fish_color_autosuggestion 555
set fish_color_valid_path --underline
set fish_color_cwd green
set fish_color_cwd_root red

# Function to show current git branch in prompt
function fish_prompt
    set_color $fish_color_cwd
    echo -n (basename (prompt_pwd))
    set_color normal
    echo -n ' $ '
end
EOF
        print_success "Basic Fish configuration created"
    else
        print_info "Fish configuration file already exists"
    fi
    
    # Ask if user wants to install fish plugins
    if ask_yes_no "Do you want to install useful Fish plugins (fisher package manager)?" "y"; then
        install_fish_plugins
    fi
    
    print_success "Fish shell configuration completed!"
}

# Function to install fish plugins
install_fish_plugins() {
    print_step "Installing Fisher package manager for Fish..."
    
    # Install fisher
    if fish -c "curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher"; then
        print_success "Fisher package manager installed"
        
        # Install some useful plugins
        print_step "Installing useful Fish plugins..."
        fish -c "fisher install jethrokuan/z" 2>/dev/null || true
        fish -c "fisher install franciscolourenco/done" 2>/dev/null || true
        fish -c "fisher install PatrickF1/fzf.fish" 2>/dev/null || true
        
        print_success "Fish plugins installed"
    else
        print_warning "Failed to install Fisher package manager"
    fi
}

# Main execution when script is run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    configure_fish
fi
