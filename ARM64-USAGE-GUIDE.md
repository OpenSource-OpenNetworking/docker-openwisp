# OpenWISP ARM64 Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying OpenWISP on ARM64 architecture systems (such as Apple Silicon Macs, Raspberry Pi, AWS Graviton instances, etc.). This deployment has been tested and optimized for ARM64 platforms.

## Prerequisites

### System Requirements

- **ARM64 compatible system** (Apple Silicon Mac, Raspberry Pi 4+, AWS Graviton, etc.)
- **Docker** version 20.10+ with ARM64 support
- **Docker Compose** version 2.0+
- **Minimum 4GB RAM** (8GB recommended)
- **10GB free disk space** (20GB recommended for production)

### Software Installation

#### Ubuntu/Debian ARM64
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt install docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

#### macOS (Apple Silicon)
```bash
# Install Docker Desktop for Mac (Apple Silicon)
# Download from https://docs.docker.com/desktop/mac/install/

# Verify ARM64 support
docker version --format '{{.Server.Arch}}'
# Should output: arm64
```

## Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/openwisp/docker-openwisp.git
cd docker-openwisp
```

### 2. Environment Configuration

Create and configure the `.env` file:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
# Essential Configuration
DASHBOARD_DOMAIN=dashboard.example.com
API_DOMAIN=api.example.com
VPN_DOMAIN=vpn.example.com
EMAIL_DJANGO_DEFAULT=admin@example.com

# Database Configuration
DB_USER=openwisp
DB_PASS=secure_password_here
DB_NAME=openwisp

# InfluxDB Configuration (for monitoring)
INFLUXDB_USER=openwisp
INFLUXDB_PASS=secure_influx_password
INFLUXDB_NAME=openwisp

# Security
DJANGO_SECRET_KEY=your_very_long_random_secret_key_here

# SSL Configuration
SSL_CERT_MODE=SelfSigned  # or 'LetsEncrypt' for production
CERT_ADMIN_EMAIL=admin@example.com

# ARM64 Optimizations
UWSGI_PROCESSES=2
UWSGI_THREADS=2
UWSGI_LISTEN=100

# Enable/Disable Modules
USE_OPENWISP_RADIUS=True
USE_OPENWISP_TOPOLOGY=True
USE_OPENWISP_FIRMWARE=True
USE_OPENWISP_MONITORING=True

# Celery Workers (ARM64 optimized)
USE_OPENWISP_CELERY_TASK_ROUTES_DEFAULTS=True
OPENWISP_CELERY_COMMAND_FLAGS=--concurrency=1
USE_OPENWISP_CELERY_NETWORK=True
OPENWISP_CELERY_NETWORK_COMMAND_FLAGS=--concurrency=1
USE_OPENWISP_CELERY_MONITORING=True
OPENWISP_CELERY_MONITORING_COMMAND_FLAGS=--concurrency=1
USE_OPENWISP_CELERY_FIRMWARE=True
OPENWISP_CELERY_FIRMWARE_COMMAND_FLAGS=--concurrency=1

# Development Settings
DEBUG_MODE=False
DJANGO_LOG_LEVEL=INFO
TZ=UTC
```

### 3. Build and Deploy

Build ARM64 optimized images:

```bash
# Set platform for ARM64
export DOCKER_DEFAULT_PLATFORM=linux/arm64

# Build all services
docker compose build

# Start services
docker compose up -d
```

### 4. Verify Deployment

Check container status:
```bash
docker compose ps
```

All containers should show "Up" status. If any container is restarting, check logs:
```bash
docker compose logs [service-name]
```

### 5. Access the Application

#### Local Development
Add to your `/etc/hosts` file:
```
127.0.0.1 dashboard.example.com
127.0.0.1 api.example.com
```

Access the dashboard at: `https://dashboard.example.com`

#### Production
Configure your DNS to point your domains to your server's public IP address.

## ARM64 Specific Optimizations

### Docker Compose Platform Configuration

The deployment includes ARM64-specific platform configurations:

```yaml
services:
  dashboard:
    platform: linux/arm64
    # ... other configurations
```

### Performance Tuning for ARM64

#### Memory Optimization
```env
# Reduce worker processes for ARM64 systems
UWSGI_PROCESSES=2
UWSGI_THREADS=2

# Optimize Celery concurrency
OPENWISP_CELERY_COMMAND_FLAGS=--concurrency=1
```

#### PostgreSQL ARM64 Configuration
The deployment uses `kartoza/postgis:15-3.4` which is ARM64 compatible:

```yaml
postgres:
  image: kartoza/postgis:15-3.4
  platform: linux/arm64
```

### Container Resource Limits

For ARM64 systems, consider setting resource limits:

```yaml
services:
  dashboard:
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '0.5'
        reservations:
          memory: 512M
          cpus: '0.25'
```

## Troubleshooting

### Common ARM64 Issues

#### 1. Architecture Mismatch Error
```
exec format error
```

**Solution**: Ensure all images specify `platform: linux/arm64` in docker-compose.yml

#### 2. Database Connection Issues
```
FATAL: password authentication failed
```

**Solution**: Check PostgreSQL environment variables:
```env
POSTGRES_USER=openwisp
POSTGRES_PASS=your_password
POSTGRES_DBNAME=openwisp
```

#### 3. InfluxDB v1/v2 Compatibility
```
401: unauthorized
```

**Solution**: Disable monitoring temporarily:
```env
USE_OPENWISP_MONITORING=False
METRIC_COLLECTION=False
```

#### 4. Nginx Configuration Issues
```
404 Not Found
```

**Solution**: Verify domain configuration and SSL setup:
```bash
docker compose logs nginx
```

### Performance Monitoring

Monitor ARM64 performance:

```bash
# Container resource usage
docker stats

# System resources
htop

# Disk usage
df -h
docker system df
```

### Log Analysis

Check service logs for issues:

```bash
# All services
docker compose logs

# Specific service
docker compose logs dashboard

# Follow logs in real-time
docker compose logs -f dashboard

# Last N lines
docker compose logs --tail=50 dashboard
```

## Production Deployment

### SSL Configuration

#### Using Let's Encrypt
```env
SSL_CERT_MODE=LetsEncrypt
CERT_ADMIN_EMAIL=admin@yourdomain.com
```

#### Using Custom Certificates
```bash
# Place certificates in ssl/ directory
mkdir ssl
cp your-cert.pem ssl/
cp your-key.pem ssl/
```

### Backup Strategy

#### Database Backup
```bash
# Create backup
docker compose exec postgres pg_dump -U openwisp openwisp > backup_$(date +%Y%m%d).sql

# Restore backup
docker compose exec -T postgres psql -U openwisp openwisp < backup_file.sql
```

#### Volume Backup
```bash
# Backup all volumes
docker run --rm -v docker-openwisp_postgres_data:/data -v $(pwd):/backup ubuntu tar czf /backup/postgres_backup.tar.gz /data
```

### Scaling for Production

#### Horizontal Scaling
```yaml
services:
  dashboard:
    deploy:
      replicas: 2
  
  celery:
    deploy:
      replicas: 3
```

#### Load Balancer Configuration
Use nginx or HAProxy to distribute load across multiple instances.

### Monitoring and Alerts

#### Health Checks
```bash
# API health check
curl -k https://api.example.com/api/v1/

# Dashboard health check
curl -k https://dashboard.example.com/admin/
```

#### Prometheus Metrics (Optional)
Enable monitoring with Prometheus and Grafana for ARM64 systems.

## Maintenance

### Updates
```bash
# Pull latest images
docker compose pull

# Rebuild and restart
docker compose down
docker compose up -d --build
```

### Cleanup
```bash
# Remove unused images
docker image prune -a

# Remove unused volumes (careful!)
docker volume prune

# System cleanup
docker system prune -a
```

## Security Considerations

### Firewall Configuration
```bash
# Allow HTTP/HTTPS
sudo ufw allow 80
sudo ufw allow 443

# Allow SSH (if needed)
sudo ufw allow 22

# Enable firewall
sudo ufw enable
```

### Docker Security
```bash
# Run Docker rootless (recommended)
dockerd-rootless-setuptool.sh install
```

### Regular Security Updates
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update Docker images
docker compose pull
docker compose up -d
```

## Support and Community

- **Documentation**: https://openwisp.io/docs/
- **GitHub Issues**: https://github.com/openwisp/docker-openwisp/issues
- **Community Forum**: https://openwisp.org/support.html
- **Gitter Chat**: https://gitter.im/openwisp/dockerize-openwisp

## License

This project is licensed under the BSD 3-Clause License. See the [LICENSE](LICENSE) file for details.

---

**Note**: This guide is specifically optimized for ARM64 architectures. For x86_64 deployments, refer to the standard OpenWISP Docker documentation.