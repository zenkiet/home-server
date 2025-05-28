#!/bin/bash
# Service management utilities  
# Author: ZenKiet

# List all services
service_list_all() {
    log_info "Listing all available services..."
    rc-status --list 2>/dev/null | sort
}

# List running services
service_list_running() {
    log_info "Listing running services..."
    rc-status --servicelist 2>/dev/null | grep -E "started|running" | awk '{print $1}'
}

# List stopped services
service_list_stopped() {
    log_info "Listing stopped services..."
    rc-status --servicelist 2>/dev/null | grep -E "stopped|crashed" | awk '{print $1}'
}

# Get service status
service_status() {
    local service="$1"
    if [[ -z "$service" ]]; then
        log_error "Service name is required"
        return 1
    fi
    
    rc-service "$service" status 2>/dev/null
}

# Get detailed service status
service_status_detailed() {
    local service="$1"
    if [[ -z "$service" ]]; then
        log_error "Service name is required"
        return 1
    fi
    
    log_info "Detailed status for service: $service"
    
    # Basic status
    local status
    if is_service_running "$service"; then
        status="RUNNING"
    else
        status="STOPPED"
    fi
    
    echo "Service: $service"
    echo "Status: $status"
    
    # Check if enabled
    local runlevels
    runlevels=$(rc-update show | grep "^$service" | awk '{for(i=2;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//')
    if [[ -n "$runlevels" ]]; then
        echo "Enabled in runlevels: $runlevels"
    else
        echo "Enabled in runlevels: none"
    fi
    
    # Get PID if running
    if [[ "$status" == "RUNNING" ]]; then
        local pid
        pid=$(pgrep -f "$service" | head -1)
        [[ -n "$pid" ]] && echo "PID: $pid"
    fi
}

# Restart service
service_restart() {
    local service="$1"
    if [[ -z "$service" ]]; then
        log_error "Service name is required"
        return 1
    fi
    
    log_info "Restarting service: $service"
    if rc-service "$service" restart >/dev/null 2>&1; then
        log_success "Service $service restarted"
        return 0
    else
        log_error "Failed to restart service: $service"
        return 1
    fi
}

# Reload service configuration
service_reload() {
    local service="$1"
    if [[ -z "$service" ]]; then
        log_error "Service name is required"
        return 1
    fi
    
    log_info "Reloading service configuration: $service"
    if rc-service "$service" reload >/dev/null 2>&1; then
        log_success "Service $service configuration reloaded"
        return 0
    else
        log_warning "Service $service does not support reload, attempting restart..."
        service_restart "$service"
    fi
}

# Disable service from runlevel
service_disable() {
    local service="$1"
    local runlevel="${2:-default}"
    
    if [[ -z "$service" ]]; then
        log_error "Service name is required"
        return 1
    fi
    
    log_info "Disabling service $service from runlevel $runlevel"
    if rc-update del "$service" "$runlevel" >/dev/null 2>&1; then
        log_success "Service $service disabled from runlevel $runlevel"
        return 0
    else
        log_error "Failed to disable service: $service"
        return 1
    fi
}

# Check if service exists
service_exists() {
    local service="$1"
    [[ -f "/etc/init.d/$service" ]]
}

# Get service dependencies
service_dependencies() {
    local service="$1"
    if [[ -z "$service" ]]; then
        log_error "Service name is required"
        return 1
    fi
    
    if ! service_exists "$service"; then
        log_error "Service $service does not exist"
        return 1
    fi
    
    log_info "Dependencies for service: $service"
    
    # Extract dependencies from init script
    local init_script="/etc/init.d/$service"
    local deps
    
    # Get 'need' dependencies
    deps=$(grep -E "^[[:space:]]*need[[:space:]]+" "$init_script" 2>/dev/null | sed 's/.*need[[:space:]]\+//' | tr ' ' '\n' | sort -u)
    if [[ -n "$deps" ]]; then
        echo "Required services:"
        echo "$deps" | sed 's/^/  - /'
    fi
    
    # Get 'use' dependencies
    deps=$(grep -E "^[[:space:]]*use[[:space:]]+" "$init_script" 2>/dev/null | sed 's/.*use[[:space:]]\+//' | tr ' ' '\n' | sort -u)
    if [[ -n "$deps" ]]; then
        echo "Optional services:"
        echo "$deps" | sed 's/^/  - /'
    fi
    
    # Get 'after' dependencies
    deps=$(grep -E "^[[:space:]]*after[[:space:]]+" "$init_script" 2>/dev/null | sed 's/.*after[[:space:]]\+//' | tr ' ' '\n' | sort -u)
    if [[ -n "$deps" ]]; then
        echo "Start after:"
        echo "$deps" | sed 's/^/  - /'
    fi
    
    # Get 'before' dependencies
    deps=$(grep -E "^[[:space:]]*before[[:space:]]+" "$init_script" 2>/dev/null | sed 's/.*before[[:space:]]\+//' | tr ' ' '\n' | sort -u)
    if [[ -n "$deps" ]]; then
        echo "Start before:"
        echo "$deps" | sed 's/^/  - /'
    fi
}

# Create simple service script
service_create() {
    local service_name="$1"
    local command="$2"
    local description="$3"
    local user="${4:-root}"
    
    if [[ -z "$service_name" || -z "$command" ]]; then
        log_error "Service name and command are required"
        return 1
    fi
    
    local init_script="/etc/init.d/$service_name"
    
    if [[ -f "$init_script" ]]; then
        log_error "Service $service_name already exists"
        return 1
    fi
    
    log_info "Creating service: $service_name"
    
    cat > "$init_script" << EOF
#!/sbin/openrc-run

name="$service_name"
description="${description:-Custom service: $service_name}"
command="$command"
command_user="$user"
pidfile="/var/run/\${RC_SVCNAME}.pid"
command_background="yes"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath --directory --owner \$command_user --mode 0755 \$(dirname \$pidfile)
}
EOF
    
    chmod +x "$init_script"
    log_success "Service $service_name created successfully"
    log_info "To enable: rc-update add $service_name default"
    log_info "To start: rc-service $service_name start"
}

# Remove service
service_remove() {
    local service="$1"
    if [[ -z "$service" ]]; then
        log_error "Service name is required"
        return 1
    fi
    
    if ! service_exists "$service"; then
        log_error "Service $service does not exist"
        return 1
    fi
    
    # Stop service first
    if is_service_running "$service"; then
        log_info "Stopping service $service before removal..."
        stop_service "$service"
    fi
    
    # Disable from all runlevels
    log_info "Disabling service $service from all runlevels..."
    rc-update show | grep "^$service" | while read -r line; do
        local runlevel
        runlevel=$(echo "$line" | awk '{print $2}')
        rc-update del "$service" "$runlevel" >/dev/null 2>&1
    done
    
    # Remove init script
    local init_script="/etc/init.d/$service"
    backup_file "$init_script"
    
    if rm "$init_script" 2>/dev/null; then
        log_success "Service $service removed successfully"
        return 0
    else
        log_error "Failed to remove service: $service"
        return 1
    fi
}

# Get service logs
service_logs() {
    local service="$1"
    local lines="${2:-50}"
    
    if [[ -z "$service" ]]; then
        log_error "Service name is required"
        return 1
    fi
    
    log_info "Showing last $lines lines of logs for service: $service"
    
    # Common log locations
    local log_files=(
        "/var/log/$service.log"
        "/var/log/$service/$service.log"
        "/var/log/messages"
        "/var/log/syslog"
    )
    
    local found_logs=false
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            if grep -q "$service" "$log_file" 2>/dev/null; then
                echo "=== $log_file ==="
                tail -n "$lines" "$log_file" | grep "$service" || true
                found_logs=true
                echo ""
            fi
        fi
    done
    
    if [[ "$found_logs" == "false" ]]; then
        log_warning "No log files found for service: $service"
        return 1
    fi
}

# Monitor service (simple monitoring)
service_monitor() {
    local service="$1"
    local interval="${2:-5}"
    
    if [[ -z "$service" ]]; then
        log_error "Service name is required"
        return 1
    fi
    
    log_info "Monitoring service: $service (interval: ${interval}s, press Ctrl+C to stop)"
    
    while true; do
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        if is_service_running "$service"; then
            printf "[%s] ✅ %s is running\n" "$timestamp" "$service"
        else
            printf "[%s] ❌ %s is stopped\n" "$timestamp" "$service"
        fi
        
        sleep "$interval"
    done
}

# Batch service operations
service_batch_start() {
    local services=("$@")
    local failed_services=()
    
    log_info "Starting ${#services[@]} services..."
    
    for service in "${services[@]}"; do
        if start_service "$service"; then
            log_success "Started: $service"
        else
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        log_warning "Failed to start: ${failed_services[*]}"
        return 1
    fi
    
    return 0
}

service_batch_stop() {
    local services=("$@")
    local failed_services=()
    
    log_info "Stopping ${#services[@]} services..."
    
    for service in "${services[@]}"; do
        if stop_service "$service"; then
            log_success "Stopped: $service"
        else
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        log_warning "Failed to stop: ${failed_services[*]}"
        return 1
    fi
    
    return 0
}

# Get all services in runlevel
service_get_runlevel_services() {
    local runlevel="${1:-default}"
    log_info "Services in runlevel: $runlevel"
    rc-update show "$runlevel" 2>/dev/null | awk '{print $1}' | sort
}