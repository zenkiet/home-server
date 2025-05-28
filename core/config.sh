#!/bin/bash
# Configuration management
# Author: ZenKiet

# Global variables
declare -g CONFIG_FILE=""
declare -A CONFIG_CACHE=()
declare -g CONFIG_LOADED=false

# Initialize configuration
config_init() {
    local config_file="$1"
    
    if [[ -z "$config_file" ]]; then
        log_error "Configuration file path is required"
        return 1
    fi
    
    CONFIG_FILE="$config_file"
    
    # Download config if it's a URL
    if [[ "$config_file" =~ ^https?:// ]]; then
        local temp_config
        temp_config=$(create_temp_dir)/components.yaml
        
        if download_file "$config_file" "$temp_config"; then
            CONFIG_FILE="$temp_config"
            log_debug "Downloaded configuration from: $config_file"
        else
            log_error "Failed to download configuration from: $config_file"
            return 1
        fi
    fi
    
    # Validate config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    # Load configuration
    if config_load; then
        CONFIG_LOADED=true
        log_debug "Configuration loaded successfully from: $CONFIG_FILE"
        return 0
    else
        log_error "Failed to load configuration"
        return 1
    fi
}

# Simple YAML parser for our component structure
config_load() {
    local current_component=""
    local current_section=""
    
    # Clear cache
    CONFIG_CACHE=()
    
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Parse components section
        if [[ "$line" == "components:" ]]; then
            current_section="components"
            continue
        fi
        
        # Skip if not in components section
        [[ "$current_section" != "components" ]] && continue
        
        # Parse component name (2 spaces indentation)
        if [[ "$line" =~ ^[a-zA-Z0-9_-]+:$ ]]; then
            current_component="${line%:}"
            CONFIG_CACHE["components.$current_component.exists"]="true"
            continue
        fi
        
        # Parse component properties (4 spaces indentation)
        if [[ "$line" =~ ^[[:space:]]{2,}[a-zA-Z_]+:[[:space:]]*.* && -n "$current_component" ]]; then
            local key value
            key=$(echo "$line" | cut -d: -f1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            value=$(echo "$line" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^"//' | sed 's/"$//')
            
            # Handle arrays (dependencies)
            if [[ "$key" == "dependencies" && "$value" =~ ^\[.*\]$ ]]; then
                # Remove brackets and split by comma
                value=$(echo "$value" | sed 's/^\[//' | sed 's/\]$//' | sed 's/,/ /g' | sed 's/"//g')
            fi
            
            CONFIG_CACHE["components.$current_component.$key"]="$value"
        fi
    done < "$CONFIG_FILE"
    
    return 0
}

# Get configuration value
config_get() {
    local key="$1"
    local default_value="$2"
    
    if [[ ! "$CONFIG_LOADED" == "true" ]]; then
        log_error "Configuration not loaded"
        return 1
    fi
    
    local value="${CONFIG_CACHE[$key]}"
    echo "${value:-$default_value}"
}

# Check if configuration key exists
config_exists() {
    local key="$1"
    [[ -n "${CONFIG_CACHE[$key]}" ]]
}

# Get list of all components
config_get_components() {
    if [[ ! "$CONFIG_LOADED" == "true" ]]; then
        log_error "Configuration not loaded"
        return 1
    fi
    
    local components=()
    
    for key in "${!CONFIG_CACHE[@]}"; do
        if [[ "$key" =~ ^components\.([^.]+)\.exists$ ]]; then
            local component="${BASH_REMATCH[1]}"
            components+=("$component")
        fi
    done
    
    # Sort and output
    printf '%s\n' "${components[@]}" | sort
}

# Get component property
config_get_component_property() {
    local component="$1"
    local property="$2"
    local default_value="$3"
    
    if [[ -z "$component" || -z "$property" ]]; then
        log_error "Component and property are required"
        return 1
    fi
    
    config_get "components.$component.$property" "$default_value"
}

# Get component name
config_get_component_name() {
    local component="$1"
    config_get_component_property "$component" "name" "$component"
}

# Get component description
config_get_component_description() {
    local component="$1"
    config_get_component_property "$component" "description" "No description available"
}

# Get component category
config_get_component_category() {
    local component="$1"
    config_get_component_property "$component" "category" "misc"
}

# Get component priority
config_get_component_priority() {
    local component="$1"
    config_get_component_property "$component" "priority" "999"
}

# Get component dependencies
config_get_component_dependencies() {
    local component="$1"
    local deps
    deps=$(config_get_component_property "$component" "dependencies" "")
    
    if [[ -n "$deps" ]]; then
        echo "$deps"
    fi
}

# Check if component exists in configuration
config_component_exists() {
    local component="$1"
    config_exists "components.$component.exists"
}

# Get components by category
config_get_components_by_category() {
    local category="$1"
    local components
    
    components=$(config_get_components)
    
    while IFS= read -r component; do
        local comp_category
        comp_category=$(config_get_component_category "$component")
        [[ "$comp_category" == "$category" ]] && echo "$component"
    done <<< "$components"
}

# Get all categories
config_get_categories() {
    local categories=()
    local components
    
    components=$(config_get_components)
    
    while IFS= read -r component; do
        local category
        category=$(config_get_component_category "$component")
        if ! array_contains "$category" "${categories[@]}"; then
            categories+=("$category")
        fi
    done <<< "$components"
    
    printf '%s\n' "${categories[@]}" | sort
}

# Validate component dependencies
config_validate_dependencies() {
    local component="$1"
    local dependencies
    local missing_deps=()
    
    dependencies=$(config_get_component_dependencies "$component")
    
    if [[ -n "$dependencies" ]]; then
        for dep in $dependencies; do
            if ! config_component_exists "$dep"; then
                missing_deps+=("$dep")
            fi
        done
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Component $component has missing dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    return 0
}

# Get dependency tree for component
config_get_dependency_tree() {
    local component="$1"
    local visited=()
    local result=()
    
    _config_get_deps_recursive() {
        local comp="$1"
        local deps
        
        # Check for circular dependencies
        if array_contains "$comp" "${visited[@]}"; then
            log_error "Circular dependency detected for component: $comp"
            return 1
        fi
        
        visited+=("$comp")
        
        deps=$(config_get_component_dependencies "$comp")
        if [[ -n "$deps" ]]; then
            for dep in $deps; do
                if config_component_exists "$dep"; then
                    _config_get_deps_recursive "$dep" || return 1
                    if ! array_contains "$dep" "${result[@]}"; then
                        result+=("$dep")
                    fi
                else
                    log_error "Dependency not found: $dep (required by $comp)"
                    return 1
                fi
            done
        fi
        
        if ! array_contains "$comp" "${result[@]}"; then
            result+=("$comp")
        fi
    }
    
    if _config_get_deps_recursive "$component"; then
        printf '%s\n' "${result[@]}"
        return 0
    else
        return 1
    fi
}

# Sort components by priority
config_sort_by_priority() {
    local components=("$@")
    local sorted_components=()
    
    # Create array of "priority:component" strings
    local priority_components=()
    for component in "${components[@]}"; do
        local priority
        priority=$(config_get_component_priority "$component")
        priority_components+=("$priority:$component")
    done
    
    # Sort by priority and extract component names
    while IFS= read -r line; do
        sorted_components+=("${line#*:}")
    done < <(printf '%s\n' "${priority_components[@]}" | sort -n)
    
    printf '%s\n' "${sorted_components[@]}"
}

# Get configuration summary
config_summary() {
    if [[ ! "$CONFIG_LOADED" == "true" ]]; then
        log_error "Configuration not loaded"
        return 1
    fi
    
    log_info "Configuration Summary:"
    log_info "  Configuration file: $CONFIG_FILE"
    
    local components
    components=$(config_get_components)
    local component_count
    component_count=$(echo "$components" | wc -l)
    log_info "  Total components: $component_count"
    
    local categories
    categories=$(config_get_categories)
    log_info "  Categories: $(echo "$categories" | tr '\n' ', ' | sed 's/, $//')"
    
    log_info "  Components by category:"
    while IFS= read -r category; do
        local cat_components
        cat_components=$(config_get_components_by_category "$category")
        local cat_count
        cat_count=$(echo "$cat_components" | wc -l)
        log_info "    $category: $cat_count components"
    done <<< "$categories"
}

# Export configuration to different format
config_export() {
    local format="${1:-json}"
    local output_file="$2"
    
    case "$format" in
        "json")
            config_export_json "$output_file"
            ;;
        "env")
            config_export_env "$output_file"
            ;;
        *)
            log_error "Unsupported export format: $format"
            return 1
            ;;
    esac
}

# Export to JSON format (basic)
config_export_json() {
    local output_file="$1"
    local output_target
    
    if [[ -n "$output_file" ]]; then
        output_target="$output_file"
    else
        output_target="/dev/stdout"
    fi
    
    {
        echo "{"
        echo '  "components": {'
        
        local components
        components=$(config_get_components)
        local component_array=()
        while IFS= read -r component; do
            component_array+=("$component")
        done <<< "$components"
        
        for i in "${!component_array[@]}"; do
            local component="${component_array[$i]}"
            local name description category priority dependencies
            
            name=$(config_get_component_name "$component")
            description=$(config_get_component_description "$component")
            category=$(config_get_component_category "$component")
            priority=$(config_get_component_priority "$component")
            dependencies=$(config_get_component_dependencies "$component")
            
            echo "    \"$component\": {"
            echo "      \"name\": \"$name\","
            echo "      \"description\": \"$description\","
            echo "      \"category\": \"$category\","
            echo "      \"priority\": $priority"
            
            if [[ -n "$dependencies" ]]; then
                echo "      \"dependencies\": [$(echo "$dependencies" | sed 's/\([^ ]*\)/"\1"/g' | tr ' ' ',')]"
            else
                echo "      \"dependencies\": []"
            fi
            
            if [[ $i -eq $((${#component_array[@]} - 1)) ]]; then
                echo "    }"
            else
                echo "    },"
            fi
        done
        
        echo "  }"
        echo "}"
    } > "$output_target"
    
    if [[ -n "$output_file" ]]; then
        log_success "Configuration exported to JSON: $output_file"
    fi
}

# Export to environment variables format
config_export_env() {
    local output_file="$1"
    local output_target
    
    if [[ -n "$output_file" ]]; then
        output_target="$output_file"
    else
        output_target="/dev/stdout"
    fi
    
    {
        local components
        components=$(config_get_components)
        
        while IFS= read -r component; do
            local name description category priority dependencies
            local comp_upper
            comp_upper=$(echo "$component" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
            
            name=$(config_get_component_name "$component")
            description=$(config_get_component_description "$component")
            category=$(config_get_component_category "$component")
            priority=$(config_get_component_priority "$component")
            dependencies=$(config_get_component_dependencies "$component")
            
            echo "COMPONENT_${comp_upper}_NAME=\"$name\""
            echo "COMPONENT_${comp_upper}_DESCRIPTION=\"$description\""
            echo "COMPONENT_${comp_upper}_CATEGORY=\"$category\""
            echo "COMPONENT_${comp_upper}_PRIORITY=\"$priority\""
            echo "COMPONENT_${comp_upper}_DEPENDENCIES=\"$dependencies\""
            echo ""
        done <<< "$components"
    } > "$output_target"
    
    if [[ -n "$output_file" ]]; then
        log_success "Configuration exported to ENV format: $output_file"
    fi
}