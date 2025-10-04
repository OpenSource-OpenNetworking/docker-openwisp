# 生产环境安全配置建议
# Production Environment Security Configuration

## 🔒 关键安全配置

### 1. 强密码和密钥
```bash
# 生成强密码
openssl rand -base64 32  # 用于 DJANGO_SECRET_KEY
openssl rand -base64 16  # 用于数据库密码
```

### 2. SSL/TLS 配置
```env
# 使用真实的SSL证书而不是自签名
SSL_CERT_MODE=LetsEncrypt  # 或者使用外部证书
CERT_ADMIN_EMAIL=admin@yourdomain.com
```

### 3. 数据库安全
```env
# 使用强密码
DB_USER=openwisp_prod
DB_PASS=<生成的强密码>
DB_NAME=openwisp_production

# InfluxDB 安全
INFLUXDB_USER=openwisp_metrics
INFLUXDB_PASS=<生成的强密码>
INFLUXDB_NAME=openwisp_metrics
```

### 4. Django 安全设置
```env
DEBUG_MODE=False
DJANGO_LOG_LEVEL=WARNING
DJANGO_SECRET_KEY=<生成的32字符密钥>

# 生产域名
DASHBOARD_DOMAIN=dashboard.yourcompany.com
API_DOMAIN=api.yourcompany.com
VPN_DOMAIN=vpn.yourcompany.com
```

### 5. 网络安全
```yaml
# 在 docker-compose.yml 中限制端口暴露
# 只暴露必要的端口 (80, 443)
ports:
  - "80:80"
  - "443:443"
  # 移除其他端口暴露
```

## 🚀 性能优化

### 1. uWSGI 配置
```env
# 根据服务器资源调整
UWSGI_PROCESSES=4          # CPU核心数
UWSGI_THREADS=4            # 每个进程的线程数
UWSGI_LISTEN=1000          # 连接队列
```

### 2. Celery 工作进程
```env
# 根据工作负载调整并发数
OPENWISP_CELERY_COMMAND_FLAGS=--concurrency=2
OPENWISP_CELERY_NETWORK_COMMAND_FLAGS=--concurrency=2
OPENWISP_CELERY_MONITORING_COMMAND_FLAGS=--concurrency=2
OPENWISP_CELERY_FIRMWARE_COMMAND_FLAGS=--concurrency=2
```

## 📊 监控和日志

### 1. 日志配置
```env
DJANGO_LOG_LEVEL=INFO
# 配置日志轮转和持久化存储
```

### 2. 健康检查
```yaml
# 添加到 docker-compose.yml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost/admin/login/"]
  interval: 30s
  timeout: 10s
  retries: 3
```

## 🔄 备份策略

### 1. 数据库备份
```bash
# PostgreSQL 备份脚本
#!/bin/bash
BACKUP_DIR="/backup/postgres"
DATE=$(date +%Y%m%d_%H%M%S)
docker compose exec postgres pg_dump -U admin openwisp > $BACKUP_DIR/openwisp_$DATE.sql
```

### 2. 配置文件备份
```bash
# 定期备份配置
tar -czf /backup/config_$(date +%Y%m%d).tar.gz .env docker-compose.yml
```

## 🔧 维护建议

### 1. 定期更新
```bash
# 更新镜像
docker compose pull
docker compose up -d

# 清理旧镜像
docker image prune -f
```

### 2. 资源监控
```bash
# 监控容器资源使用
docker stats
docker compose logs --tail=100 -f
```

## 🚨 故障排查

### 1. 服务状态检查
```bash
docker compose ps
docker compose logs <service_name>
```

### 2. 网络连通性
```bash
# 测试服务间连接
docker compose exec nginx curl http://dashboard:8000/admin/login/
docker compose exec nginx curl http://api:8001/admin/login/
```

### 3. 数据库连接
```bash
# 检查数据库连接
docker compose exec dashboard python manage.py dbshell
```