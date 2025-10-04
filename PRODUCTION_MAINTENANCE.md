# OpenWISP 生产环境维护指南
# Production Maintenance Guide for OpenWISP

## 🚀 快速开始

### 1. 生产环境部署
```bash
# 使用自动化部署脚本
./deploy_production.sh

# 或手动部署
cp .env.production.template .env
# 编辑 .env 配置文件
docker-compose -f docker-compose.production.yml up -d
```

### 2. 服务管理
```bash
# 查看服务状态
docker-compose -f docker-compose.production.yml ps

# 查看日志
docker-compose -f docker-compose.production.yml logs -f [service_name]

# 重启服务
docker-compose -f docker-compose.production.yml restart [service_name]

# 停止所有服务
docker-compose -f docker-compose.production.yml down

# 强制重新创建服务
docker-compose -f docker-compose.production.yml up -d --force-recreate
```

## 🔒 安全管理

### 1. 密钥管理
```bash
# 生成新的Django密钥
openssl rand -base64 32

# 生成数据库密码
openssl rand -base64 16

# 更新密钥后重启服务
docker-compose -f docker-compose.production.yml restart
```

### 2. SSL证书管理
```bash
# 使用Let's Encrypt证书
# 1. 修改 .env 文件
SSL_CERT_MODE=LetsEncrypt
CERT_ADMIN_EMAIL=admin@yourdomain.com

# 2. 重新构建nginx
docker-compose -f docker-compose.production.yml build nginx
docker-compose -f docker-compose.production.yml up -d nginx

# 手动更新SSL证书
docker-compose -f docker-compose.production.yml exec nginx certbot renew
```

### 3. 防火墙配置
```bash
# 只开放必要端口
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw enable

# 限制SSH访问
# 编辑 /etc/ssh/sshd_config
# PermitRootLogin no
# PasswordAuthentication no
# AllowUsers your_username
```

## 📊 监控与维护

### 1. 系统监控
```bash
# 运行监控检查
./monitor.sh

# 查看资源使用
docker stats

# 查看磁盘使用
df -h

# 查看内存使用
free -h
```

### 2. 日志管理
```bash
# 查看nginx访问日志
docker-compose -f docker-compose.production.yml logs nginx | grep "GET\|POST"

# 查看应用错误日志
docker-compose -f docker-compose.production.yml logs dashboard | grep -i error

# 清理旧日志
docker system prune -f
```

### 3. 性能优化
```bash
# 调整uWSGI进程数（根据CPU核心数）
# 编辑 .env 文件
UWSGI_PROCESSES=4
UWSGI_THREADS=4

# 调整Celery并发数
OPENWISP_CELERY_COMMAND_FLAGS=--concurrency=2

# 重启相关服务
docker-compose -f docker-compose.production.yml restart dashboard api celery
```

## 💾 备份与恢复

### 1. 自动备份
```bash
# 运行备份脚本
./backup.sh

# 设置定时备份（添加到crontab）
crontab -e
# 添加以下行：每天凌晨2点备份
0 2 * * * /path/to/docker-openwisp-gmail/backup.sh
```

### 2. 恢复数据
```bash
# 停止服务
docker-compose -f docker-compose.production.yml down

# 恢复PostgreSQL数据库
gunzip -c /backup/openwisp/database/postgres_YYYYMMDD_HHMMSS.sql.gz | \
docker-compose -f docker-compose.production.yml exec -T postgres psql -U admin openwisp

# 恢复媒体文件
tar -xzf /backup/openwisp/media/media_YYYYMMDD_HHMMSS.tar.gz -C ./

# 重启服务
docker-compose -f docker-compose.production.yml up -d
```

## 🔧 故障排除

### 1. 常见问题

#### 服务无法启动
```bash
# 检查配置文件
docker-compose -f docker-compose.production.yml config

# 查看详细错误
docker-compose -f docker-compose.production.yml logs [service_name]

# 检查端口占用
netstat -tlnp | grep ':80\|:443'
```

#### 数据库连接失败
```bash
# 检查数据库服务
docker-compose -f docker-compose.production.yml exec postgres pg_isready

# 检查数据库连接
docker-compose -f docker-compose.production.yml exec dashboard python manage.py dbshell

# 重启数据库
docker-compose -f docker-compose.production.yml restart postgres
```

#### nginx 502错误
```bash
# 检查upstream服务
docker-compose -f docker-compose.production.yml exec nginx curl http://dashboard:8000
docker-compose -f docker-compose.production.yml exec nginx curl http://api:8001

# 检查nginx配置
docker-compose -f docker-compose.production.yml exec nginx nginx -t

# 重启nginx
docker-compose -f docker-compose.production.yml restart nginx
```

### 2. 诊断命令
```bash
# 检查所有服务健康状态
docker-compose -f docker-compose.production.yml ps

# 检查容器资源使用
docker stats --no-stream

# 检查网络连接
docker network ls
docker network inspect [network_name]

# 检查存储卷
docker volume ls
docker volume inspect [volume_name]
```

## 📈 升级指南

### 1. 应用升级
```bash
# 备份数据
./backup.sh

# 拉取最新镜像
docker-compose -f docker-compose.production.yml pull

# 停止服务
docker-compose -f docker-compose.production.yml down

# 运行数据库迁移
docker-compose -f docker-compose.production.yml run --rm dashboard python manage.py migrate

# 重启服务
docker-compose -f docker-compose.production.yml up -d

# 验证升级
./monitor.sh
```

### 2. 系统升级
```bash
# 更新系统包
apt update && apt upgrade -y

# 更新Docker
curl -fsSL https://get.docker.com | sh

# 重启系统（如需要）
reboot
```

## 🚨 应急预案

### 1. 服务恢复
```bash
# 快速重启所有服务
docker-compose -f docker-compose.production.yml restart

# 如果重启失败，强制重建
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml up -d --force-recreate
```

### 2. 数据恢复
```bash
# 从最新备份恢复
BACKUP_DATE=$(ls -t /backup/openwisp/database/ | head -1 | sed 's/postgres_//g' | sed 's/.sql.gz//g')
./restore_backup.sh $BACKUP_DATE
```

### 3. 联系支持
```bash
# 收集系统信息
docker-compose -f docker-compose.production.yml ps > system_info.txt
docker-compose -f docker-compose.production.yml logs --tail=100 >> system_info.txt
./monitor.sh >> system_info.txt

# 发送给技术支持
```

## 📞 维护联系信息

- 技术支持: support@yourdomain.com
- 紧急联系: +86-xxx-xxxx-xxxx
- 文档地址: https://docs.openwisp.io/
- 项目地址: https://github.com/openwisp/docker-openwisp