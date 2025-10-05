#!/bin/bash

# OpenWISP Production Environment Backup Script
# Production Backup Script for OpenWISP

set -e

# Configuration
BACKUP_DIR="/backup/openwisp"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Color definitions
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

# Create backup directory
create_backup_dir() {
    mkdir -p $BACKUP_DIR/{database,config,media,logs}
    chmod 700 $BACKUP_DIR
}

# Backup PostgreSQL database
backup_database() {
    log "Backing up PostgreSQL database..."
    
    DB_NAME=$(grep DB_NAME .env | cut -d= -f2)
    DB_USER=$(grep DB_USER .env | cut -d= -f2)
    
    if [ -f docker-compose.production.yml ]; then
        docker-compose -f docker-compose.production.yml exec -T postgres pg_dump -U $DB_USER $DB_NAME | gzip > $BACKUP_DIR/database/postgres_${DATE}.sql.gz
    else
        docker-compose exec -T postgres pg_dump -U $DB_USER $DB_NAME | gzip > $BACKUP_DIR/database/postgres_${DATE}.sql.gz
    fi
    
    log "Database backup completed: postgres_${DATE}.sql.gz"
}

# Backup InfluxDB
backup_influxdb() {
    log "Backing up InfluxDB..."
    
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
    
    log "InfluxDB backup completed: influxdb_${DATE}.tar.gz"
}

# Backup configuration files
backup_config() {
    log "Backing up configuration files..."
    
    tar -czf $BACKUP_DIR/config/config_${DATE}.tar.gz \
        .env \
        .env.secrets \
        docker-compose.yml \
        docker-compose.production.yml \
        images/
    
    log "Configuration backup completed: config_${DATE}.tar.gz"
}

# Backup media files
backup_media() {
    log "Backing up media files..."
    
    if [ -d ./data/media ]; then
        tar -czf $BACKUP_DIR/media/media_${DATE}.tar.gz ./data/media/
        log "Media files backup completed: media_${DATE}.tar.gz"
    else
        warn "Media files directory does not exist, skipping backup"
    fi
}

# Backup log files
backup_logs() {
    log "Backing up log files..."
    
    if [ -d ./data/logs ]; then
        tar -czf $BACKUP_DIR/logs/logs_${DATE}.tar.gz ./data/logs/
        log "Log files backup completed: logs_${DATE}.tar.gz"
    else
        warn "Log files directory does not exist, skipping backup"
    fi
}

# Clean up old backups
cleanup_old_backups() {
    log "Cleaning up backups older than ${RETENTION_DAYS} days..."
    
    find $BACKUP_DIR -type f -mtime +$RETENTION_DAYS -delete
    
    log "Cleanup completed"
}

# Verify backup
verify_backup() {
    log "Verifying backup files..."
    
    for file in $BACKUP_DIR/database/postgres_${DATE}.sql.gz \
               $BACKUP_DIR/config/config_${DATE}.tar.gz; do
        if [ -f "$file" ]; then
            size=$(du -h "$file" | cut -f1)
            log "✓ $file ($size)"
        else
            error "✗ $file does not exist"
        fi
    done
    
    log "Backup verification completed"
}

# Send backup report
send_report() {
    local backup_size=$(du -sh $BACKUP_DIR | cut -f1)
    
    log "Backup report:"
    log "Backup time: $(date)"
    log "Backup size: $backup_size"
    log "Backup location: $BACKUP_DIR"
    
    # If email is configured, you can send email report
    # mail -s "OpenWISP Backup Report - $DATE" admin@yourdomain.com < /tmp/backup_report.txt
}

# Main function
main() {
    log "Starting OpenWISP backup task..."
    
    create_backup_dir
    backup_database
    backup_influxdb
    backup_config
    backup_media
    backup_logs
    verify_backup
    cleanup_old_backups
    send_report
    
    log "Backup task completed!"
}

# If running script directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi