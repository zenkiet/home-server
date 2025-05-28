# Alpine Linux Package Manager

A modern, interactive package manager for Alpine Linux that simplifies the installation and management of software components.

![Alpine Package Manager](https://img.shields.io/badge/Alpine-Linux-blue?logo=alpine-linux)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.0.0-blue)

## 🌟 Features

- **Interactive Menu System**: Beautiful, terminal-based interface for component selection
- **Dependency Management**: Automatic resolution and installation of dependencies
- **Configuration Management**: YAML-based component configuration
- **Modular Architecture**: Clean, maintainable codebase with separate modules
- **Comprehensive Logging**: Detailed logging with multiple levels and colors
- **System Validation**: Pre-installation system checks and validation
- **Component Categories**: Organized components by function (system, shell, editor, etc.)
- **Installation Tracking**: Keep track of installed components
- **Remote Components**: Load components directly from GitHub repository

## 🚀 Quick Start

### One-line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/zenkiet/home-server/refs/heads/main/main.sh | sudo bash
```

### Manual Installation

1. Download the main script:
```bash
wget https://raw.githubusercontent.com/zenkiet/home-server/refs/heads/main/main.sh
chmod +x main.sh
```

2. Run with root privileges:
```bash
sudo ./main.sh
```

## 📋 Requirements

- **Alpine Linux** (any recent version)
- **Root privileges** (sudo or direct root access)
- **Internet connection** (for downloading components)
- **Basic utilities**: curl, apk, grep, awk, sed

## 🎯 Usage

### Interactive Mode (Default)

Simply run the script to enter interactive mode:

```bash
sudo ./main.sh
```

Navigate using:
- **↑/↓**: Move cursor
- **Space/C**: Toggle selection
- **Enter**: Confirm and install
- **A**: Select all components
- **D**: Deselect all components
- **Q**: Quit
- **H/?**: Show help

### Command Line Options

```bash
# Show help
./main.sh --help

# Show version information
./main.sh --version

# List available components
./main.sh list

# List installed components
./main.sh installed

# Show system statistics
./main.sh stats

# Validate all components
./main.sh validate

# Uninstall a component
./main.sh uninstall nano-editor

# Use custom configuration
./main.sh --config /path/to/config.yaml

# Set log level
./main.sh --log-level debug

# Quiet mode
./main.sh --quiet

# Disable colors
./main.sh --no-color
```

### Export Configuration

```bash
# Export to JSON
./main.sh export json > components.json

# Export to environment variables
./main.sh export env > components.env
```

## 📦 Available Components

### System Components
- **Edge Repositories**: Configure Alpine to use edge repositories for latest packages

### Shell Components  
- **Fish Shell**: Modern, user-friendly shell with autocompletion and syntax highlighting

### Editor Components
- **Nano Editor**: Simple, easy-to-use text editor with syntax highlighting

### SSH Components
- **Dropbear SSH**: Lightweight SSH server for remote access

## 🏗️ Architecture

```
alpine-package-manager/
├── main.sh                 # Main entry point
├── core/                   # Core modules
│   ├── logger.sh          # Logging system
│   ├── config.sh          # Configuration management
│   ├── menu.sh            # Interactive menu system
│   └── installer.sh       # Installation engine
├── utils/                  # Utility modules
│   ├── system.sh          # System utilities
│   ├── package.sh         # Package management
│   └── service.sh         # Service management
├── components/             # Available components
│   ├── component.interface.sh
│   ├── nano-editor/
│   ├── fish-shell/
│   ├── edge-repositories/
│   └── dropbear-ssh/
└── configs/               # Configuration files
    └── components.yaml    # Component definitions
```

### Core Modules

- **Logger**: Centralized logging with color support and file output
- **Config**: YAML configuration parser and management
- **Menu**: Interactive terminal-based menu system
- **Installer**: Component installation and dependency resolution

### Utility Modules

- **System**: System-level operations and validation
- **Package**: APK package management wrapper
- **Service**: OpenRC service management

## 🔧 Configuration

### Component Configuration (YAML)

```yaml
components:
  nano-editor:
    name: "Nano Editor"
    description: "Simple text editor"
    category: "text-editor"
    priority: 3
    dependencies: []

  fish-shell:
    name: "Fish Shell"
    description: "Modern shell"
    category: "shell"
    priority: 2
    dependencies: []
```

### Environment Variables

```bash
# Configuration file location
CONFIG_FILE="/path/to/components.yaml"

# Log level (debug|info|warning|error)
LOG_LEVEL="info"

# Log file location
LOG_FILE="/var/log/alpine-package-manager.log"
```

## 📊 Component Development

### Creating a New Component

1. Create component directory:
```bash
mkdir components/my-component
```

2. Create installation script:
```bash
# components/my-component/install.sh
#!/bin/bash

component_name() {
    echo "My Component"
}

component_description() {
    echo "Description of my component"
}

component_dependencies() {
    echo "dependency1 dependency2"
}

install_my_component() {
    print_step "Installing My Component..."
    
    # Installation logic here
    install_package "my-package" "My Package"
    
    print_success "My Component installed successfully!"
}

# Main function for installer compatibility
main() {
    install_my_component
}
```

3. Add to configuration:
```yaml
components:
  my-component:
    name: "My Component"
    description: "Description of my component"
    category: "misc"
    priority: 10
    dependencies: []
```

### Component Interface

All components should implement these functions:

- `component_name()`: Return display name
- `component_description()`: Return description
- `component_dependencies()`: Return space-separated dependencies
- `component_status()`: Return "installed" or "not-installed"
- `component_validate()`: Validate component requirements
- `main()`: Main installation function

## 🐛 Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   # Run with sudo
   sudo ./main.sh
   ```

2. **Network Issues**
   ```bash
   # Check internet connectivity
   ping -c 3 dl-cdn.alpinelinux.org
   ```

3. **Dependency Errors**
   ```bash
   # Update package repository
   sudo apk update
   ```

### Logs

Check the installation log for detailed information:
```bash
tail -f /var/log/alpine-package-manager.log
```

### Debug Mode

Run with debug logging for detailed output:
```bash
sudo ./main.sh --log-level debug
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add your component or improvement
4. Test thoroughly on Alpine Linux
5. Submit a pull request

### Development Guidelines

- Follow bash best practices
- Use proper error handling
- Add comprehensive logging
- Test on multiple Alpine versions
- Document your changes

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**ZenKiet**
- GitHub: [@zenkiet](https://github.com/zenkiet)

## 🙏 Acknowledgments

- Alpine Linux community for the excellent distribution
- Contributors who help improve this package manager

## 📈 Roadmap

- [ ] GUI interface (optional)
- [ ] Package search functionality
- [ ] Custom repository support
- [ ] Component update notifications
- [ ] Backup/restore functionality
- [ ] Configuration templates
- [ ] Multi-language support

---

**Made with ❤️ for the Alpine Linux community** 