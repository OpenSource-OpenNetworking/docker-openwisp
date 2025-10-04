#!/bin/bash

# OpenWISP 生产环境监控脚本
# Production Monitoring Script for OpenWISP

set -e

# 配置
ALERT_EMAIL="admin@yourdomain.com"
LOG_FILE="/var/log/openwisp_monitor.log"
COMPOSE_FILE="docker-compose.production.yml"

# 阈值设置
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=85
RESPONSE_TIME_THRESHOLD=5

# 颜色定义
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

# 检查服务状态
check_services() {
    log "检查服务状态..."
    
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
            log "✓ $service: 运行中"
        else
            error "✗ $service: $status"
            alert_service_down $service
        fi
    done
}

# 检查容器资源使用
check_resource_usage() {
    log "检查资源使用情况..."
    
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
                warn "$name CPU使用率过高: ${cpu}%"
                alert_high_resource $name "CPU" $cpu
            fi
            
            if (( $(echo "$memory > $MEMORY_THRESHOLD" | bc -l) )); then
                warn "$name 内存使用率过高: ${memory}%"
                alert_high_resource $name "Memory" $memory
            fi
            
            log "$name - CPU: ${cpu}%, Memory: ${memory}%"
        fi
    done
}

# 检查磁盘使用
check_disk_usage() {
    log "检查磁盘使用情况..."
    
    df -h | while read filesystem size used avail percent mountpoint; do
        if [[ $percent =~ ^[0-9]+% ]]; then
            usage=$(echo $percent | sed 's/%//')
            if [ $usage -gt $DISK_THRESHOLD ]; then
                warn "磁盘使用率过高: $mountpoint ${percent}"
                alert_disk_full $mountpoint $percent
            fi
            log "$mountpoint: ${percent} 已使用"
        fi
    done
}

# 检查网络连通性
check_network_connectivity() {
    log "检查网络连通性..."
    
    # 检查Dashboard
    if timeout 5 curl -k -s https://localhost/admin/login/ > /dev/null; then
        log "✓ Dashboard 可访问"
    else
        error "✗ Dashboard 不可访问"
        alert_service_unreachable "Dashboard"
    fi
    
    # 检查API
    if timeout 5 curl -k -s https://localhost/api/v1/ > /dev/null; then
        log "✓ API 可访问"
    else
        error "✗ API 不可访问"
        alert_service_unreachable "API"
    fi
}

# 检查数据库连接
check_database_connection() {
    log "检查数据库连接..."
    
    # PostgreSQL
    if [ -f $COMPOSE_FILE ]; then
        if docker-compose -f $COMPOSE_FILE exec -T postgres pg_isready > /dev/null 2>&1; then
            log "✓ PostgreSQL 连接正常"
        else
            error "✗ PostgreSQL 连接失败"
            alert_database_down "PostgreSQL"
        fi
        
        # Redis
        if docker-compose -f $COMPOSE_FILE exec -T redis redis-cli ping > /dev/null 2>&1; then
            log "✓ Redis 连接正常"
        else
            error "✗ Redis 连接失败"
            alert_database_down "Redis"
        fi
    else
        if docker-compose exec -T postgres pg_isready > /dev/null 2>&1; then
            log "✓ PostgreSQL 连接正常"
        else
            error "✗ PostgreSQL 连接失败"
            alert_database_down "PostgreSQL"
        fi
        
        if docker-compose exec -T redis redis-cli ping > /dev/null 2>&1; then
            log "✓ Redis 连接正常"
        else
            error "✗ Redis 连接失败"
            alert_database_down "Redis"
        fi
    fi
}

# 检查日志错误
check_logs_for_errors() {
    log "检查最近的错误日志..."
    
    if [ -f $COMPOSE_FILE ]; then
        error_count=$(docker-compose -f $COMPOSE_FILE logs --since="1h" 2>&1 | grep -i error | wc -l)
    else
        error_count=$(docker-compose logs --since="1h" 2>&1 | grep -i error | wc -l)
    fi
    
    if [ $error_count -gt 10 ]; then
        warn "最近1小时发现 $error_count 个错误"
        alert_error_spike $error_count
    else
        log "最近1小时发现 $error_count 个错误"
    fi
}

# 报警函数
alert_service_down() {
    local service=$1
    info "发送服务停止报警: $service"
    # echo "Service $service is down at $(date)" | mail -s "OpenWISP Alert: Service Down" $ALERT_EMAIL
}

alert_high_resource() {
    local service=$1
    local resource=$2
    local usage=$3
    info "发送高资源使用报警: $service $resource ${usage}%"
    # echo "$service $resource usage is ${usage}% at $(date)" | mail -s "OpenWISP Alert: High Resource Usage" $ALERT_EMAIL
}

alert_disk_full() {
    local mountpoint=$1
    local usage=$2
    info "发送磁盘空间报警: $mountpoint $usage"
    # echo "Disk usage at $mountpoint is $usage at $(date)" | mail -s "OpenWISP Alert: Disk Full" $ALERT_EMAIL
}

alert_service_unreachable() {
    local service=$1
    info "发送服务不可达报警: $service"
    # echo "$service is unreachable at $(date)" | mail -s "OpenWISP Alert: Service Unreachable" $ALERT_EMAIL
}

alert_database_down() {
    local database=$1
    info "发送数据库停止报警: $database"
    # echo "$database database is down at $(date)" | mail -s "OpenWISP Alert: Database Down" $ALERT_EMAIL
}

alert_error_spike() {
    local count=$1
    info "发送错误激增报警: $count errors"
    # echo "Error spike detected: $count errors in the last hour at $(date)" | mail -s "OpenWISP Alert: Error Spike" $ALERT_EMAIL
}

# 生成监控报告
generate_report() {
    log "生成监控报告..."
    
    cat > /tmp/openwisp_monitor_report.txt << EOF
OpenWISP 监控报告
生成时间: $(date)

服务状态:
$(check_services 2>&1 | grep -E "✓|✗")

资源使用:
$(check_resource_usage 2>&1 | grep -E "CPU|Memory")

磁盘使用:
$(df -h | grep -v tmpfs | grep -v udev)

最近错误数量:
$(check_logs_for_errors 2>&1 | grep "发现")

详细日志请查看: $LOG_FILE
EOF

    info "监控报告已生成: /tmp/openwisp_monitor_report.txt"
}

# 主函数
main() {
    mkdir -p $(dirname $LOG_FILE)
    
    log "开始OpenWISP监控检查..."
    
    check_services
    check_resource_usage
    check_disk_usage
    check_network_connectivity
    check_database_connection
    check_logs_for_errors
    
    generate_report
    
    log "监控检查完成"
}

# 如果直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi