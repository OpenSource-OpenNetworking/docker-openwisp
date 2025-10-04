#!/bin/bash

# OpenWISP 生产环境部署脚本
# Production Deployment Script for OpenWISP

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# 检查依赖
check_dependencies() {
    log "检查系统依赖..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker 未安装，请先安装 Docker"
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose 未安装，请先安装 Docker Compose"
    fi
    
    if ! command -v openssl &> /dev/null; then
        error "OpenSSL 未安装，请先安装 OpenSSL"
    fi
    
    log "依赖检查完成"
}

# 生成安全密钥
generate_secrets() {
    log "生成安全密钥..."
    
    if [ ! -f .env.secrets ]; then
        echo "# 自动生成的安全密钥" > .env.secrets
        echo "DJANGO_SECRET_KEY=$(openssl rand -base64 32)" >> .env.secrets
        echo "DB_PASS=$(openssl rand -base64 16)" >> .env.secrets
        echo "INFLUXDB_PASS=$(openssl rand -base64 16)" >> .env.secrets
        echo "REDIS_PASSWORD=$(openssl rand -base64 16)" >> .env.secrets
        log "安全密钥已生成并保存到 .env.secrets"
        warn "请安全保存 .env.secrets 文件，不要提交到版本控制"
    else
        log "使用现有的安全密钥"
    fi
}

# 配置环境
setup_environment() {
    log "配置生产环境..."
    
    if [ ! -f .env ]; then
        if [ -f .env.production.template ]; then
            cp .env.production.template .env
            log "已创建 .env 文件，请根据需要修改配置"
        else
            error ".env.production.template 文件不存在"
        fi
    fi
    
    # 合并密钥到环境文件
    if [ -f .env.secrets ]; then
        cat .env.secrets >> .env
    fi
    
    # 设置权限
    chmod 600 .env .env.secrets 2>/dev/null || true
}

# 初始化数据目录
init_data_directories() {
    log "初始化数据目录..."
    
    mkdir -p ./data/{postgres,redis,influxdb,media,static,logs,backup}
    chmod 755 ./data
    chmod 700 ./data/{postgres,redis,influxdb}
    
    log "数据目录创建完成"
}

# 构建镜像
build_images() {
    log "构建Docker镜像..."
    
    if [ -f docker-compose.production.yml ]; then
        docker-compose -f docker-compose.production.yml build --no-cache
    else
        docker-compose build --no-cache
    fi
    
    log "镜像构建完成"
}

# 数据库初始化
init_database() {
    log "初始化数据库..."
    
    # 启动数据库服务
    if [ -f docker-compose.production.yml ]; then
        docker-compose -f docker-compose.production.yml up -d postgres redis influxdb
    else
        docker-compose up -d postgres redis influxdb
    fi
    
    # 等待数据库启动
    log "等待数据库启动..."
    sleep 30
    
    # 运行数据库迁移
    if [ -f docker-compose.production.yml ]; then
        docker-compose -f docker-compose.production.yml run --rm dashboard python manage.py migrate
        docker-compose -f docker-compose.production.yml run --rm api python manage.py migrate
    else
        docker-compose run --rm dashboard python manage.py migrate
        docker-compose run --rm api python manage.py migrate
    fi
    
    log "数据库初始化完成"
}

# 创建超级用户
create_superuser() {
    log "创建管理员用户..."
    
    read -p "请输入管理员用户名: " admin_username
    read -s -p "请输入管理员密码: " admin_password
    echo
    read -p "请输入管理员邮箱: " admin_email
    
    if [ -f docker-compose.production.yml ]; then
        echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('$admin_username', '$admin_email', '$admin_password')" | docker-compose -f docker-compose.production.yml run --rm dashboard python manage.py shell
    else
        echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('$admin_username', '$admin_email', '$admin_password')" | docker-compose run --rm dashboard python manage.py shell
    fi
    
    log "管理员用户创建完成"
}

# 启动服务
start_services() {
    log "启动所有服务..."
    
    if [ -f docker-compose.production.yml ]; then
        docker-compose -f docker-compose.production.yml up -d
    else
        docker-compose up -d
    fi
    
    log "等待服务启动..."
    sleep 30
    
    # 检查服务状态
    if [ -f docker-compose.production.yml ]; then
        docker-compose -f docker-compose.production.yml ps
    else
        docker-compose ps
    fi
    
    log "服务启动完成"
}

# 健康检查
health_check() {
    log "执行健康检查..."
    
    # 检查nginx
    if curl -k -f https://localhost/admin/login/ > /dev/null 2>&1; then
        log "Dashboard 服务正常"
    else
        warn "Dashboard 服务可能异常"
    fi
    
    # 检查API
    if curl -k -f https://localhost/api/v1/ > /dev/null 2>&1; then
        log "API 服务正常"
    else
        warn "API 服务可能异常"
    fi
    
    log "健康检查完成"
}

# 显示部署信息
show_deployment_info() {
    log "部署完成！"
    echo
    info "访问信息:"
    info "Dashboard: https://$(grep DASHBOARD_DOMAIN .env | cut -d= -f2)"
    info "API: https://$(grep API_DOMAIN .env | cut -d= -f2)"
    echo
    info "本地访问:"
    info "Dashboard: https://localhost/admin/"
    info "API: https://localhost/api/v1/"
    echo
    warn "请确保在 /etc/hosts 中添加域名解析:"
    echo "127.0.0.1 $(grep DASHBOARD_DOMAIN .env | cut -d= -f2)"
    echo "127.0.0.1 $(grep API_DOMAIN .env | cut -d= -f2)"
    echo
    info "查看日志: docker-compose logs -f"
    info "停止服务: docker-compose down"
    info "备份数据: ./backup.sh"
}

# 主函数
main() {
    log "开始 OpenWISP 生产环境部署..."
    
    check_dependencies
    generate_secrets
    setup_environment
    init_data_directories
    build_images
    init_database
    
    read -p "是否创建管理员用户? (y/n): " create_admin
    if [[ $create_admin =~ ^[Yy]$ ]]; then
        create_superuser
    fi
    
    start_services
    health_check
    show_deployment_info
    
    log "部署完成！"
}

# 执行主函数
main "$@"