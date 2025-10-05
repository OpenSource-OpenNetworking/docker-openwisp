#!/bin/bash

# OpenWISP Production Environment Deployment Script
# Production Deployment Script for OpenWISP

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functions
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

# Check dependencies
check_dependencies() {
    log "Checking system dependencies..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed, please install Docker first"
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose is not installed, please install Docker Compose first"
    fi
    
    if ! command -v openssl &> /dev/null; then
        error "OpenSSL is not installed, please install OpenSSL first"
    fi
    
    log "Dependencies check completed"
}

# Generate security keys
generate_secrets() {
    log "Generating security keys..."
    
    if [ ! -f .env.secrets ]; then
        echo "# Auto-generated security keys" > .env.secrets
        echo "DJANGO_SECRET_KEY=$(openssl rand -base64 32)" >> .env.secrets
        echo "DB_PASS=$(openssl rand -base64 16)" >> .env.secrets
        echo "INFLUXDB_PASS=$(openssl rand -base64 16)" >> .env.secrets
        echo "REDIS_PASSWORD=$(openssl rand -base64 16)" >> .env.secrets
        log "Security keys generated and saved to .env.secrets"
        warn "Please keep .env.secrets file secure, do not commit to version control"
    else
        log "Using existing security keys"
    fi
}

# Setup environment
setup_environment() {
    log "Setting up production environment..."
    
    if [ ! -f .env ]; then
        if [ -f .env.production.template ]; then
            cp .env.production.template .env
            log ".env file created, please modify configuration as needed"
        else
            error ".env.production.template file does not exist"
        fi
    fi
    
    # Merge secrets into environment file
    if [ -f .env.secrets ]; then
        cat .env.secrets >> .env
    fi
    
    # Set permissions
    chmod 600 .env .env.secrets 2>/dev/null || true
}

# Initialize data directories
init_data_directories() {
    log "Initializing data directories..."
    
    mkdir -p ./data/{postgres,redis,influxdb,media,static,logs,backup}
    chmod 755 ./data
    chmod 700 ./data/{postgres,redis,influxdb}
    
    log "Data directories creation completed"
}

# Build images
build_images() {
    log "Building Docker images..."
    
    if [ -f docker-compose.production.yml ]; then
        docker-compose -f docker-compose.production.yml build --no-cache
    else
        docker-compose build --no-cache
    fi
    
    log "Image build completed"
}

# Database initialization
init_database() {
    log "Initializing database..."
    
    # Start database services
    if [ -f docker-compose.production.yml ]; then
        docker-compose -f docker-compose.production.yml up -d postgres redis influxdb
    else
        docker-compose up -d postgres redis influxdb
    fi
    
    # Wait for database startup
    log "Waiting for database startup..."
    sleep 30
    
    # Run database migrations
    if [ -f docker-compose.production.yml ]; then
        docker-compose -f docker-compose.production.yml run --rm dashboard python manage.py migrate
        docker-compose -f docker-compose.production.yml run --rm api python manage.py migrate
    else
        docker-compose run --rm dashboard python manage.py migrate
        docker-compose run --rm api python manage.py migrate
    fi
    
    log "Database initialization completed"
}

# Create superuser
create_superuser() {
    log "Creating admin user..."
    
    read -p "Please enter admin username: " admin_username
    read -s -p "Please enter admin password: " admin_password
    echo
    read -p "Please enter admin email: " admin_email
    
    if [ -f docker-compose.production.yml ]; then
        echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('$admin_username', '$admin_email', '$admin_password')" | docker-compose -f docker-compose.production.yml run --rm dashboard python manage.py shell
    else
        echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('$admin_username', '$admin_email', '$admin_password')" | docker-compose run --rm dashboard python manage.py shell
    fi
    
    log "Admin user creation completed"
}

# Start services
start_services() {
    log "Starting all services..."
    
    if [ -f docker-compose.production.yml ]; then
        docker-compose -f docker-compose.production.yml up -d
    else
        docker-compose up -d
    fi
    
    log "Waiting for services to start..."
    sleep 30
    
    # Check service status
    if [ -f docker-compose.production.yml ]; then
        docker-compose -f docker-compose.production.yml ps
    else
        docker-compose ps
    fi
    
    log "Services startup completed"
}

# Health check
health_check() {
    log "Performing health check..."
    
    # Check nginx
    if curl -k -f https://localhost/admin/login/ > /dev/null 2>&1; then
        log "Dashboard service is normal"
    else
        warn "Dashboard service may be abnormal"
    fi
    
    # Check API
    if curl -k -f https://localhost/api/v1/ > /dev/null 2>&1; then
        log "API service is normal"
    else
        warn "API service may be abnormal"
    fi
    
    log "Health check completed"
}

# Show deployment information
show_deployment_info() {
    log "Deployment completed!"
    echo
    info "Access information:"
    info "Dashboard: https://$(grep DASHBOARD_DOMAIN .env | cut -d= -f2)"
    info "API: https://$(grep API_DOMAIN .env | cut -d= -f2)"
    echo
    info "Local access:"
    info "Dashboard: https://localhost/admin/"
    info "API: https://localhost/api/v1/"
    echo
    warn "Please add domain resolution to /etc/hosts:"
    echo "127.0.0.1 $(grep DASHBOARD_DOMAIN .env | cut -d= -f2)"
    echo "127.0.0.1 $(grep API_DOMAIN .env | cut -d= -f2)"
    echo
    info "View logs: docker-compose logs -f"
    info "Stop services: docker-compose down"
    info "Backup data: ./backup.sh"
}

# Main function
main() {
    log "Starting OpenWISP production environment deployment..."
    
    check_dependencies
    generate_secrets
    setup_environment
    init_data_directories
    build_images
    init_database
    
    read -p "Create admin user? (y/n): " create_admin
    if [[ $create_admin =~ ^[Yy]$ ]]; then
        create_superuser
    fi
    
    start_services
    health_check
    show_deployment_info
    
    log "Deployment completed!"
}

# Execute main function
main "$@"