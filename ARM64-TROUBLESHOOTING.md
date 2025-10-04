# ARM64 Troubleshooting Guide

## Quick Diagnostics

### System Check Commands
```bash
# Verify ARM64 architecture
uname -m
# Should output: aarch64 or arm64

# Check Docker platform support
docker version --format '{{.Server.Arch}}'
# Should output: arm64

# Verify container platforms
docker compose config | grep platform

# Check available space
df -h
docker system df
```

## Common Issues and Solutions

### 1. Container Startup Issues

#### Issue: `exec format error`
```
standard_init_linux.go:228: exec user process caused: exec format error
```

**Root Cause**: Architecture mismatch - trying to run x86_64 images on ARM64

**Solution**:
```bash
# Ensure docker-compose.yml has platform specifications
grep -r "platform:" docker-compose.yml

# If missing, add to each service:
platform: linux/arm64

# Rebuild all images
docker compose build --no-cache
```

#### Issue: `no matching manifest for linux/arm64`
```
ERROR: no matching manifest for linux/arm64/v8 in the manifest list entries
```

**Root Cause**: Base image doesn't support ARM64

**Solution**:
```bash
# Check Dockerfile base images
find images/ -name "Dockerfile" -exec grep -l "FROM" {} \;

# Replace with ARM64 compatible alternatives:
# python:3.9 → python:3.9-slim (supports ARM64)
# nginx:alpine → nginx:1.29.0-alpine (supports ARM64)
# postgres:13 → kartoza/postgis:15-3.4 (ARM64 compatible)
```

### 2. Database Connection Problems

#### Issue: `FATAL: password authentication failed`
```
FATAL: password authentication failed for user "admin"
DETAIL: Role "admin" does not exist
```

**Root Cause**: PostgreSQL environment variables mismatch

**Solution**:
```bash
# Check .env file for correct variables
cat .env | grep -E "(DB_|POSTGRES_)"

# Ensure these variables exist:
DB_USER=openwisp
DB_PASS=your_password
DB_NAME=openwisp
POSTGRES_USER=openwisp
POSTGRES_PASS=your_password
POSTGRES_DBNAME=openwisp

# Reset database
docker compose down
docker volume rm docker-openwisp-gmail_postgres_data
docker compose up -d postgres
```

#### Issue: Database connection timeout
```
django.db.utils.OperationalError: timeout expired
```

**Root Cause**: ARM64 database initialization takes longer

**Solution**:
```bash
# Wait for database to be ready
docker compose up -d postgres
sleep 30

# Check postgres logs
docker compose logs postgres

# Wait for "database system is ready to accept connections"
# Then start other services
docker compose up -d
```

### 3. Performance Issues

#### Issue: High CPU/Memory usage
```
container consuming 100% CPU
```

**Root Cause**: Incorrect process/thread configuration for ARM64

**Solution**:
```env
# Optimize .env for ARM64
UWSGI_PROCESSES=2          # Reduce from default 4
UWSGI_THREADS=2            # Reduce from default 4
UWSGI_LISTEN=100           # Keep reasonable

# Celery worker optimization
OPENWISP_CELERY_COMMAND_FLAGS=--concurrency=1
OPENWISP_CELERY_NETWORK_COMMAND_FLAGS=--concurrency=1
OPENWISP_CELERY_MONITORING_COMMAND_FLAGS=--concurrency=1
OPENWISP_CELERY_FIRMWARE_COMMAND_FLAGS=--concurrency=1
```

#### Issue: Out of memory errors
```
MemoryError: Unable to allocate array
```

**Root Cause**: Insufficient memory allocation for ARM64 containers

**Solution**:
```bash
# Check system memory
free -h

# Add memory limits to docker-compose.yml
services:
  dashboard:
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M

# Consider swap if low memory
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 4. Network and SSL Issues

#### Issue: `404 Not Found` on web access
```
nginx: 404 Not Found
```

**Root Cause**: Domain configuration or nginx routing issues

**Solution**:
```bash
# Check nginx configuration
docker compose logs nginx

# Verify domain in .env
grep DOMAIN .env

# Test with correct Host header
curl -H "Host: dashboard.example.com" http://localhost

# Check nginx config generation
docker compose exec nginx ls -la /etc/nginx/conf.d/
```

#### Issue: SSL certificate problems
```
SSL certificate problem: self-signed certificate
```

**Root Cause**: Using self-signed certificates in production

**Solution**:
```bash
# For development, ignore SSL
curl -k https://dashboard.example.com

# For production, use Let's Encrypt
# In .env:
SSL_CERT_MODE=LetsEncrypt
CERT_ADMIN_EMAIL=admin@yourdomain.com

# Or provide custom certificates
mkdir ssl/
cp your-cert.pem ssl/
cp your-key.pem ssl/
```

### 5. Service-Specific Issues

#### Issue: InfluxDB authentication errors
```
401: unauthorized
```

**Root Cause**: InfluxDB v1/v2 API compatibility issues

**Solution**:
```bash
# Temporarily disable monitoring
# In .env:
USE_OPENWISP_MONITORING=False
METRIC_COLLECTION=False
USE_OPENWISP_CELERY_MONITORING=False

# Restart services
docker compose restart dashboard celery celerybeat
```

#### Issue: Celery worker crashes
```
celery worker exited with code 1
```

**Root Cause**: Memory or concurrency issues on ARM64

**Solution**:
```bash
# Check celery logs
docker compose logs celery

# Reduce concurrency in .env
OPENWISP_CELERY_COMMAND_FLAGS=--concurrency=1 --loglevel=INFO

# Check memory usage
docker stats celery
```

#### Issue: FreeRADIUS fails to start
```
radiusd: error while loading shared libraries
```

**Root Cause**: ARM64 library compatibility

**Solution**:
```bash
# Check FreeRADIUS logs
docker compose logs freeradius

# Verify ARM64 base image in Dockerfile
cat images/openwisp_freeradius/Dockerfile

# May need to disable RADIUS temporarily
# In .env:
USE_OPENWISP_RADIUS=False
```

## Performance Optimization for ARM64

### CPU Optimization
```env
# Optimize for ARM64 cores (typically fewer but efficient)
UWSGI_PROCESSES=2
UWSGI_THREADS=2

# Single-threaded Celery workers work better on ARM64
OPENWISP_CELERY_COMMAND_FLAGS=--concurrency=1
```

### Memory Optimization
```env
# Conservative memory settings
UWSGI_LISTEN=100
DEBUG_MODE=False

# Disable unnecessary features during troubleshooting
USE_OPENWISP_MONITORING=False
USE_OPENWISP_FIRMWARE=False
```

### Disk I/O Optimization
```bash
# Use faster storage if available
# Move Docker data to SSD if using Raspberry Pi with SD card

# Check disk performance
sudo hdparm -Tt /dev/sda1

# Optimize PostgreSQL for ARM64
# Add to docker-compose.yml postgres service:
command: >
  postgres
  -c shared_buffers=256MB
  -c effective_cache_size=1GB
  -c work_mem=16MB
```

## Monitoring and Diagnostics

### Container Health Monitoring
```bash
# Monitor all containers
watch docker compose ps

# Resource usage
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Container restart count
docker compose ps --format "table {{.Service}}\t{{.Status}}"
```

### Log Analysis Scripts
```bash
# Create log monitoring script
cat > monitor_logs.sh << 'EOF'
#!/bin/bash
echo "=== Dashboard Logs ==="
docker compose logs --tail=10 dashboard

echo "=== Database Logs ==="
docker compose logs --tail=10 postgres

echo "=== Nginx Logs ==="
docker compose logs --tail=10 nginx

echo "=== Celery Logs ==="
docker compose logs --tail=10 celery
EOF

chmod +x monitor_logs.sh
./monitor_logs.sh
```

### Network Diagnostics
```bash
# Test internal network connectivity
docker compose exec dashboard ping postgres
docker compose exec dashboard ping redis
docker compose exec dashboard ping influxdb

# Port availability
ss -tulpn | grep -E ":(80|443|5432|6379|8086)"

# DNS resolution (if using custom domains)
nslookup dashboard.example.com
```

### Health Check Commands
```bash
# API endpoint health
curl -k -s -o /dev/null -w "%{http_code}" https://api.example.com/api/v1/

# Dashboard health
curl -k -s -o /dev/null -w "%{http_code}" https://dashboard.example.com/admin/

# Database connectivity
docker compose exec postgres pg_isready -U openwisp -d openwisp

# Redis connectivity
docker compose exec redis redis-cli ping
```

## Recovery Procedures

### Complete Service Recovery
```bash
# Stop all services
docker compose down

# Clean up (if needed)
docker system prune -f

# Remove problematic containers
docker compose rm -f

# Rebuild all images
docker compose build --no-cache

# Start services one by one
docker compose up -d postgres redis
sleep 30
docker compose up -d influxdb
sleep 10
docker compose up -d dashboard api websocket
sleep 20
docker compose up -d nginx

# Check status
docker compose ps
```

### Database Recovery
```bash
# Backup current database (if accessible)
docker compose exec postgres pg_dump -U openwisp openwisp > backup_before_recovery.sql

# Reset database completely
docker compose stop dashboard api celery celerybeat websocket
docker compose rm -f postgres
docker volume rm docker-openwisp-gmail_postgres_data

# Restart with fresh database
docker compose up -d postgres
sleep 30

# Check database is ready
docker compose logs postgres | grep "ready to accept connections"

# Restore from backup (if available)
docker compose exec -T postgres psql -U openwisp openwisp < backup_before_recovery.sql

# Start other services
docker compose up -d
```

### Configuration Reset
```bash
# Backup current configuration
cp .env .env.backup
cp docker-compose.yml docker-compose.yml.backup

# Reset to minimal configuration
cat > .env << 'EOF'
DASHBOARD_DOMAIN=dashboard.example.com
API_DOMAIN=api.example.com
EMAIL_DJANGO_DEFAULT=admin@example.com
DB_USER=openwisp
DB_PASS=openwisp123
DJANGO_SECRET_KEY=changeme
SSL_CERT_MODE=SelfSigned
UWSGI_PROCESSES=2
UWSGI_THREADS=2
USE_OPENWISP_MONITORING=False
DEBUG_MODE=True
EOF

# Restart with minimal config
docker compose down
docker compose up -d
```

## Getting Help

When reporting issues, please include:

1. **System Information**:
```bash
uname -a
docker --version
docker compose version
free -h
df -h
```

2. **Container Status**:
```bash
docker compose ps
docker compose logs --tail=50
```

3. **Configuration** (sanitized):
```bash
cat .env | sed 's/PASS=.*/PASS=***HIDDEN***/g'
```

4. **Error Messages**: Full error output from logs

### Community Resources
- GitHub Issues: https://github.com/openwisp/docker-openwisp/issues
- OpenWISP Support: https://openwisp.org/support.html
- ARM64 specific discussions: Tag your issues with `arm64` label

---

Remember: ARM64 systems often require different optimization strategies than x86_64. When in doubt, start with conservative resource settings and scale up as needed.