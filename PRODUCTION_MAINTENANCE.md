# OpenWISP Production Environment Maintenance Guide
# Production Maintenance Guide for OpenWISP

## 🚀 Quick Start

### 1. Production Environment Deployment
```bash
# Use automated deployment script
./deploy_production.sh

# Or manual deployment
cp .env.production.template .env
# Edit .env configuration file
docker-compose -f docker-compose.production.yml up -d
```

### 2. Service Management
```bash
# View service status
docker-compose -f docker-compose.production.yml ps

# View logs
docker-compose -f docker-compose.production.yml logs -f [service_name]

# Restart service
docker-compose -f docker-compose.production.yml restart [service_name]

# Stop all services
docker-compose -f docker-compose.production.yml down

# Force recreate services
docker-compose -f docker-compose.production.yml up -d --force-recreate
```

## 🔒 Security Management

### 1. Key Management
```bash
# Generate new Django secret key
openssl rand -base64 32

# Generate database password
openssl rand -base64 16

# Restart services after updating keys
docker-compose -f docker-compose.production.yml restart
```

### 2. SSL Certificate Management
```bash
# Use Let's Encrypt certificate
# 1. Modify .env file
SSL_CERT_MODE=LetsEncrypt
CERT_ADMIN_EMAIL=admin@yourdomain.com

# 2. Rebuild nginx
docker-compose -f docker-compose.production.yml build nginx
docker-compose -f docker-compose.production.yml up -d nginx

# Manually update SSL certificate
docker-compose -f docker-compose.production.yml exec nginx certbot renew
```

### 3. Firewall Configuration
```bash
# Only open necessary ports
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw enable

# Restrict SSH access
# Edit /etc/ssh/sshd_config
# PermitRootLogin no
# PasswordAuthentication no
# AllowUsers your_username
```

## 📊 Monitoring and Maintenance

### 1. System Monitoring
```bash
# Run monitoring checks
./monitor.sh

# View resource usage
docker stats

# View disk usage
df -h

# View memory usage
free -h
```

### 2. Log Management
```bash
# View nginx access logs
docker-compose -f docker-compose.production.yml logs nginx | grep "GET\|POST"

# View application error logs
docker-compose -f docker-compose.production.yml logs dashboard | grep -i error

# Clean old logs
docker system prune -f
```

### 3. Performance Optimization
```bash
# Adjust uWSGI process count (based on CPU cores)
# Edit .env file
UWSGI_PROCESSES=4
UWSGI_THREADS=4

# Adjust Celery concurrency
OPENWISP_CELERY_COMMAND_FLAGS=--concurrency=2

# Restart related services
docker-compose -f docker-compose.production.yml restart dashboard api celery
```

## 💾 Backup and Recovery

### 1. Automated Backup
```bash
# Run backup script
./backup.sh

# Setup scheduled backup (add to crontab)
crontab -e
# Add the following line: backup at 2 AM daily
0 2 * * * /path/to/docker-openwisp-gmail/backup.sh
```

### 2. Data Recovery
```bash
# Stop services
docker-compose -f docker-compose.production.yml down

# Restore PostgreSQL database
gunzip -c /backup/openwisp/database/postgres_YYYYMMDD_HHMMSS.sql.gz | \
docker-compose -f docker-compose.production.yml exec -T postgres psql -U admin openwisp

# Restore media files
tar -xzf /backup/openwisp/media/media_YYYYMMDD_HHMMSS.tar.gz -C ./

# Restart services
docker-compose -f docker-compose.production.yml up -d
```

## 🔧 Troubleshooting

### 1. Common Issues

#### Service Cannot Start
```bash
# Check configuration files
docker-compose -f docker-compose.production.yml config

# View detailed errors
docker-compose -f docker-compose.production.yml logs [service_name]

# Check port usage
netstat -tlnp | grep ':80\|:443'
```

#### Database Connection Failed
```bash
# Check database service
docker-compose -f docker-compose.production.yml exec postgres pg_isready

# Check database connection
docker-compose -f docker-compose.production.yml exec dashboard python manage.py dbshell

# Restart database
docker-compose -f docker-compose.production.yml restart postgres
```

#### nginx 502 Error
```bash
# Check upstream services
docker-compose -f docker-compose.production.yml exec nginx curl http://dashboard:8000
docker-compose -f docker-compose.production.yml exec nginx curl http://api:8001

# Check nginx configuration
docker-compose -f docker-compose.production.yml exec nginx nginx -t

# Restart nginx
docker-compose -f docker-compose.production.yml restart nginx
```

### 2. Diagnostic Commands
```bash
# Check all service health status
docker-compose -f docker-compose.production.yml ps

# Check container resource usage
docker stats --no-stream

# Check network connections
docker network ls
docker network inspect [network_name]

# Check storage volumes
docker volume ls
docker volume inspect [volume_name]
```

## 📈 Upgrade Guide

### 1. Application Upgrade
```bash
# Backup data
./backup.sh

# Pull latest images
docker-compose -f docker-compose.production.yml pull

# Stop services
docker-compose -f docker-compose.production.yml down

# Run database migrations
docker-compose -f docker-compose.production.yml run --rm dashboard python manage.py migrate

# Restart services
docker-compose -f docker-compose.production.yml up -d

# Verify upgrade
./monitor.sh
```

### 2. System Upgrade
```bash
# Update system packages
apt update && apt upgrade -y

# Update Docker
curl -fsSL https://get.docker.com | sh

# Restart system (if needed)
reboot
```

## 🚨 Emergency Response Plan

### 1. Service Recovery
```bash
# Quick restart all services
docker-compose -f docker-compose.production.yml restart

# If restart fails, force rebuild
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml up -d --force-recreate
```

### 2. Data Recovery
```bash
# Restore from latest backup
BACKUP_DATE=$(ls -t /backup/openwisp/database/ | head -1 | sed 's/postgres_//g' | sed 's/.sql.gz//g')
./restore_backup.sh $BACKUP_DATE
```

### 3. Contact Support
```bash
# Collect system information
docker-compose -f docker-compose.production.yml ps > system_info.txt
docker-compose -f docker-compose.production.yml logs --tail=100 >> system_info.txt
./monitor.sh >> system_info.txt

# Send to technical support
```

## 📞 Maintenance Contact Information

- Technical Support: support@yourdomain.com
- Emergency Contact: +86-xxx-xxxx-xxxx
- Documentation: https://docs.openwisp.io/
- Project Repository: https://github.com/openwisp/docker-openwisp