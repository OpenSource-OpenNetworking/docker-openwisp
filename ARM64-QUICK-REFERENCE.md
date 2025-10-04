# OpenWISP ARM64 Quick Reference

## 🚀 Quick Start

```bash
# Clone and setup
git clone https://github.com/openwisp/docker-openwisp.git
cd docker-openwisp

# Automated setup (recommended)
./setup-arm64.sh

# Manual setup
cp .env.example .env
# Edit .env with your configuration
docker compose build
docker compose up -d
```

## 📋 Essential Commands

### Service Management
```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart specific service
docker compose restart dashboard

# View running services
docker compose ps

# Update services
docker compose pull && docker compose up -d
```

### Monitoring & Logs
```bash
# View all logs
docker compose logs

# Follow logs for specific service
docker compose logs -f dashboard

# View last 50 lines
docker compose logs --tail=50 nginx

# Monitor resource usage
docker stats
```

### Health Checks
```bash
# Check all containers
docker compose ps

# Test web endpoints
curl -k https://dashboard.example.com
curl -k https://api.example.com/api/v1/

# Database connectivity
docker compose exec postgres pg_isready -U openwisp

# Redis connectivity
docker compose exec redis redis-cli ping
```

## ⚙️ ARM64 Optimized Settings

### Environment Variables (.env)
```env
# Performance optimization for ARM64
UWSGI_PROCESSES=2
UWSGI_THREADS=2
UWSGI_LISTEN=100

# Celery optimization
OPENWISP_CELERY_COMMAND_FLAGS=--concurrency=1
OPENWISP_CELERY_NETWORK_COMMAND_FLAGS=--concurrency=1
OPENWISP_CELERY_MONITORING_COMMAND_FLAGS=--concurrency=1
OPENWISP_CELERY_FIRMWARE_COMMAND_FLAGS=--concurrency=1

# Conservative memory settings
DEBUG_MODE=False
DJANGO_LOG_LEVEL=INFO
```

### Docker Compose Platform
```yaml
services:
  dashboard:
    platform: linux/arm64
    # ... other settings
```

## 🔧 Common Troubleshooting

### Architecture Issues
```bash
# Check architecture
uname -m                    # Should show: aarch64 or arm64
docker version --format '{{.Server.Arch}}'  # Should show: arm64

# Fix exec format error
# Add to all services in docker-compose.yml:
platform: linux/arm64
```

### Database Issues
```bash
# Reset database
docker compose down
docker volume rm docker-openwisp-gmail_postgres_data
docker compose up -d postgres

# Check database logs
docker compose logs postgres

# Verify database connection
docker compose exec postgres pg_isready -U openwisp -d openwisp
```

### Performance Issues
```bash
# Monitor resources
docker stats

# Check memory usage
free -h

# Optimize for low memory (in .env):
USE_OPENWISP_MONITORING=False
UWSGI_PROCESSES=1
```

### SSL/Network Issues
```bash
# Test with curl (ignore SSL)
curl -k -H "Host: dashboard.example.com" https://localhost

# Check nginx configuration
docker compose logs nginx

# Verify ports
ss -tulpn | grep -E ":(80|443)"
```

## 📊 Service Ports

| Service | Internal Port | External Port | Purpose |
|---------|---------------|---------------|---------|
| nginx | 80, 443 | 80, 443 | Web server |
| dashboard | 8000 | - | Django app |
| api | 8001 | - | API server |
| websocket | 8002 | - | WebSocket |
| postgres | 5432 | - | Database |
| redis | 6379 | - | Cache |
| influxdb | 8086 | - | Metrics |
| freeradius | 1812, 1813 | 1812, 1813 | RADIUS |
| openvpn | 1194 | 1194 | VPN |

## 🛠️ Maintenance Tasks

### Backup
```bash
# Database backup
docker compose exec postgres pg_dump -U openwisp openwisp > backup_$(date +%Y%m%d).sql

# Volume backup
docker run --rm -v docker-openwisp_postgres_data:/data -v $(pwd):/backup ubuntu tar czf /backup/volumes_backup.tar.gz /data
```

### Updates
```bash
# Pull latest images
docker compose pull

# Rebuild and restart
docker compose down
docker compose up -d --build

# Clean up old images
docker image prune -a
```

### Reset to Default
```bash
# Complete reset (destructive!)
docker compose down
docker system prune -a -f --volumes
# Re-run setup
./setup-arm64.sh
```

## 🆘 Emergency Commands

### Service Recovery
```bash
# Stop problematic services
docker compose stop dashboard celery

# Remove and recreate
docker compose rm -f dashboard celery
docker compose up -d dashboard celery

# Check logs immediately
docker compose logs -f dashboard
```

### Resource Cleanup
```bash
# Free up space
docker system prune -a -f

# Remove unused volumes (careful!)
docker volume prune -f

# Restart Docker daemon (if needed)
sudo systemctl restart docker
```

## 📞 Getting Help

### Log Collection for Support
```bash
# System info
uname -a
docker --version
docker compose version

# Service status
docker compose ps

# Recent logs (sanitize passwords!)
docker compose logs --tail=100 > debug_logs.txt

# Configuration (hide sensitive data)
cat .env | sed 's/PASS=.*/PASS=***HIDDEN***/' > debug_config.txt
```

### Support Channels
- 📖 Full Documentation: [ARM64-USAGE-GUIDE.md](ARM64-USAGE-GUIDE.md)
- 🔧 Troubleshooting: [ARM64-TROUBLESHOOTING.md](ARM64-TROUBLESHOOTING.md)
- 🐛 GitHub Issues: https://github.com/openwisp/docker-openwisp/issues
- 💬 Community: https://openwisp.org/support.html

---

**💡 Pro Tips:**
- Always check `docker compose logs` first when troubleshooting
- ARM64 systems benefit from lower concurrency settings
- Use `./setup-arm64.sh` for automated setup on new systems
- Monitor memory usage closely on resource-constrained ARM64 devices