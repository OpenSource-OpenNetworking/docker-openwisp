#!/bin/bash

# OpenWISP 生产环境备份脚本
# Production Backup Script for OpenWISP

set -e

# 配置
BACKUP_DIR="/backup/openwisp"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# 创建备份目录
create_backup_dir() {
    mkdir -p $BACKUP_DIR/{database,config,media,logs}
    chmod 700 $BACKUP_DIR
}

# 备份PostgreSQL数据库
backup_database() {
    log "备份PostgreSQL数据库..."
    
    DB_NAME=$(grep DB_NAME .env | cut -d= -f2)
    DB_USER=$(grep DB_USER .env | cut -d= -f2)
    
    if [ -f docker-compose.production.yml ]; then
        docker-compose -f docker-compose.production.yml exec -T postgres pg_dump -U $DB_USER $DB_NAME | gzip > $BACKUP_DIR/database/postgres_${DATE}.sql.gz
    else
        docker-compose exec -T postgres pg_dump -U $DB_USER $DB_NAME | gzip > $BACKUP_DIR/database/postgres_${DATE}.sql.gz
    fi
    
    log "数据库备份完成: postgres_${DATE}.sql.gz"
}

# 备份InfluxDB
backup_influxdb() {
    log "备份InfluxDB..."
    
    INFLUX_DB=$(grep INFLUXDB_NAME .env | cut -d= -f2)
    
    if [ -f docker-compose.production.yml ]; then
        docker-compose -f docker-compose.production.yml exec -T influxdb influxd backup -portable -database $INFLUX_DB /tmp/backup
        docker-compose -f docker-compose.production.yml exec -T influxdb tar -czf /tmp/influxdb_${DATE}.tar.gz /tmp/backup
        docker-compose -f docker-compose.production.yml cp influxdb:/tmp/influxdb_${DATE}.tar.gz $BACKUP_DIR/database/
    else
        docker-compose exec -T influxdb influxd backup -portable -database $INFLUX_DB /tmp/backup
        docker-compose exec -T influxdb tar -czf /tmp/influxdb_${DATE}.tar.gz /tmp/backup
        docker-compose cp influxdb:/tmp/influxdb_${DATE}.tar.gz $BACKUP_DIR/database/
    fi
    
    log "InfluxDB备份完成: influxdb_${DATE}.tar.gz"
}

# 备份配置文件
backup_config() {
    log "备份配置文件..."
    
    tar -czf $BACKUP_DIR/config/config_${DATE}.tar.gz \
        .env \
        .env.secrets \
        docker-compose.yml \
        docker-compose.production.yml \
        images/
    
    log "配置备份完成: config_${DATE}.tar.gz"
}

# 备份媒体文件
backup_media() {
    log "备份媒体文件..."
    
    if [ -d ./data/media ]; then
        tar -czf $BACKUP_DIR/media/media_${DATE}.tar.gz ./data/media/
        log "媒体文件备份完成: media_${DATE}.tar.gz"
    else
        warn "媒体文件目录不存在，跳过备份"
    fi
}

# 备份日志文件
backup_logs() {
    log "备份日志文件..."
    
    if [ -d ./data/logs ]; then
        tar -czf $BACKUP_DIR/logs/logs_${DATE}.tar.gz ./data/logs/
        log "日志文件备份完成: logs_${DATE}.tar.gz"
    else
        warn "日志文件目录不存在，跳过备份"
    fi
}

# 清理旧备份
cleanup_old_backups() {
    log "清理${RETENTION_DAYS}天前的备份..."
    
    find $BACKUP_DIR -type f -mtime +$RETENTION_DAYS -delete
    
    log "清理完成"
}

# 验证备份
verify_backup() {
    log "验证备份文件..."
    
    for file in $BACKUP_DIR/database/postgres_${DATE}.sql.gz \
               $BACKUP_DIR/config/config_${DATE}.tar.gz; do
        if [ -f "$file" ]; then
            size=$(du -h "$file" | cut -f1)
            log "✓ $file ($size)"
        else
            error "✗ $file 不存在"
        fi
    done
    
    log "备份验证完成"
}

# 发送备份报告
send_report() {
    local backup_size=$(du -sh $BACKUP_DIR | cut -f1)
    
    log "备份报告:"
    log "备份时间: $(date)"
    log "备份大小: $backup_size"
    log "备份位置: $BACKUP_DIR"
    
    # 如果配置了邮件，可以发送邮件报告
    # mail -s "OpenWISP Backup Report - $DATE" admin@yourdomain.com < /tmp/backup_report.txt
}

# 主函数
main() {
    log "开始OpenWISP备份任务..."
    
    create_backup_dir
    backup_database
    backup_influxdb
    backup_config
    backup_media
    backup_logs
    verify_backup
    cleanup_old_backups
    send_report
    
    log "备份任务完成！"
}

# 如果直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi