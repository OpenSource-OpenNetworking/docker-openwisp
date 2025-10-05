#!/bin/bash

# OpenWISP Production Environment Monitoring Script
# Production Monitoring Script for OpenWISP

set -e

# Configuration
ALERT_EMAIL="admin@yourdomain.com"
LOG_FILE="/var/log/openwisp_monitor.log"
COMPOSE_FILE="docker-compose.production.yml"

# Threshold settings
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=85
RESPONSE_TIME_THRESHOLD=5

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a $LOG_FILE
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a $LOG_FILE
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a $LOG_FILE
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}" | tee -a $LOG_FILE
}

# Check service status
check_services() {
    log "Checking service status..."
    
    if [ -f $COMPOSE_FILE ]; then
        services=$(docker compose -f $COMPOSE_FILE ps --services)
        compose_cmd="docker compose -f $COMPOSE_FILE"
    else
        services=$(docker compose ps --services)
        compose_cmd="docker compose"
    fi
    
    for service in $services; do
        status=$($compose_cmd ps -q $service | xargs docker inspect --format='{{.State.Status}}' 2>/dev/null || echo "not_found")
        
        if [ "$status" = "running" ]; then
            log "✓ $service: running"
        else
            error "✗ $service: $status"
            alert_service_down $service
        fi
    done
}

# Check container resource usage
check_resource_usage() {
    log "Checking resource usage..."
    
    if [ -f $COMPOSE_FILE ]; then
        containers=$(docker-compose -f $COMPOSE_FILE ps -q)
    else
        containers=$(docker-compose ps -q)
    fi
    
    for container in $containers; do
        if [ -n "$container" ]; then
            name=$(docker inspect --format='{{.Name}}' $container | sed 's/\///')
            stats=$(docker stats --no-stream --format "table {{.CPUPerc}}\t{{.MemPerc}}" $container)
            cpu=$(echo $stats | awk 'NR==2 {print $1}' | sed 's/%//')
            memory=$(echo $stats | awk 'NR==2 {print $2}' | sed 's/%//')
            
            if (( $(echo "$cpu > $CPU_THRESHOLD" | bc -l) )); then
                warn "$name CPU usage too high: ${cpu}%"
                alert_high_resource $name "CPU" $cpu
            fi
            
            if (( $(echo "$memory > $MEMORY_THRESHOLD" | bc -l) )); then
                warn "$name memory usage too high: ${memory}%"
                alert_high_resource $name "Memory" $memory
            fi
            
            log "$name - CPU: ${cpu}%, Memory: ${memory}%"
        fi
    done
}

# Check disk usage
check_disk_usage() {
    log "Checking disk usage..."
    
    df -h | while read filesystem size used avail percent mountpoint; do
        if [[ $percent =~ ^[0-9]+% ]]; then
            usage=$(echo $percent | sed 's/%//')
            if [ $usage -gt $DISK_THRESHOLD ]; then
                warn "Disk usage too high: $mountpoint ${percent}"
                alert_disk_full $mountpoint $percent
            fi
            log "$mountpoint: ${percent} used"
        fi
    done
}

# Check network connectivity
check_network_connectivity() {
    log "Checking network connectivity..."
    
    # Check Dashboard
    if timeout 5 curl -k -s https://localhost/admin/login/ > /dev/null; then
        log "✓ Dashboard accessible"
    else
        error "✗ Dashboard not accessible"
        alert_service_unreachable "Dashboard"
    fi
    
    # Check API
    if timeout 5 curl -k -s https://localhost/api/v1/ > /dev/null; then
        log "✓ API accessible"
    else
        error "✗ API not accessible"
        alert_service_unreachable "API"
    fi
}

# Check database connection
check_database_connection() {
    log "Checking database connection..."
    
    # PostgreSQL
    if [ -f $COMPOSE_FILE ]; then
        if docker-compose -f $COMPOSE_FILE exec -T postgres pg_isready > /dev/null 2>&1; then
            log "✓ PostgreSQL connection normal"
        else
            error "✗ PostgreSQL connection failed"
            alert_database_down "PostgreSQL"
        fi
        
        # Redis
        if docker-compose -f $COMPOSE_FILE exec -T redis redis-cli ping > /dev/null 2>&1; then
            log "✓ Redis connection normal"
        else
            error "✗ Redis connection failed"
            alert_database_down "Redis"
        fi
    else
        if docker-compose exec -T postgres pg_isready > /dev/null 2>&1; then
            log "✓ PostgreSQL connection normal"
        else
            error "✗ PostgreSQL connection failed"
            alert_database_down "PostgreSQL"
        fi
        
        if docker-compose exec -T redis redis-cli ping > /dev/null 2>&1; then
            log "✓ Redis connection normal"
        else
            error "✗ Redis connection failed"
            alert_database_down "Redis"
        fi
    fi
}

# Check logs for errors
check_logs_for_errors() {
    log "Checking recent error logs..."
    
    if [ -f $COMPOSE_FILE ]; then
        error_count=$(docker-compose -f $COMPOSE_FILE logs --since="1h" 2>&1 | grep -i error | wc -l)
    else
        error_count=$(docker-compose logs --since="1h" 2>&1 | grep -i error | wc -l)
    fi
    
    if [ $error_count -gt 10 ]; then
        warn "Found $error_count errors in the last hour"
        alert_error_spike $error_count
    else
        log "Found $error_count errors in the last hour"
    fi
}

# Alert functions
alert_service_down() {
    local service=$1
    info "Sending service down alert: $service"
    # echo "Service $service is down at $(date)" | mail -s "OpenWISP Alert: Service Down" $ALERT_EMAIL
}

alert_high_resource() {
    local service=$1
    local resource=$2
    local usage=$3
    info "Sending high resource usage alert: $service $resource ${usage}%"
    # echo "$service $resource usage is ${usage}% at $(date)" | mail -s "OpenWISP Alert: High Resource Usage" $ALERT_EMAIL
}

alert_disk_full() {
    local mountpoint=$1
    local usage=$2
    info "Sending disk space alert: $mountpoint $usage"
    # echo "Disk usage at $mountpoint is $usage at $(date)" | mail -s "OpenWISP Alert: Disk Full" $ALERT_EMAIL
}

alert_service_unreachable() {
    local service=$1
    info "Sending service unreachable alert: $service"
    # echo "$service is unreachable at $(date)" | mail -s "OpenWISP Alert: Service Unreachable" $ALERT_EMAIL
}

alert_database_down() {
    local database=$1
    info "Sending database down alert: $database"
    # echo "$database database is down at $(date)" | mail -s "OpenWISP Alert: Database Down" $ALERT_EMAIL
}

alert_error_spike() {
    local count=$1
    info "Sending error spike alert: $count errors"
    # echo "Error spike detected: $count errors in the last hour at $(date)" | mail -s "OpenWISP Alert: Error Spike" $ALERT_EMAIL
}

# Generate monitoring report
generate_report() {
    log "Generating monitoring report..."
    
    cat > /tmp/openwisp_monitor_report.txt << EOF
OpenWISP Monitoring Report
Generated at: $(date)

Service Status:
$(check_services 2>&1 | grep -E "✓|✗")

Resource Usage:
$(check_resource_usage 2>&1 | grep -E "CPU|Memory")

Disk Usage:
$(df -h | grep -v tmpfs | grep -v udev)

Recent Error Count:
$(check_logs_for_errors 2>&1 | grep "Found")

For detailed logs, check: $LOG_FILE
EOF

    info "Monitoring report generated: /tmp/openwisp_monitor_report.txt"
}

# Main function
main() {
    mkdir -p $(dirname $LOG_FILE)
    
    log "Starting OpenWISP monitoring check..."
    
    check_services
    check_resource_usage
    check_disk_usage
    check_network_connectivity
    check_database_connection
    check_logs_for_errors
    
    generate_report
    
    log "Monitoring check completed"
}

# If running script directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi