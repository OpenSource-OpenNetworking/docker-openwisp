#!/bin/bash
# OpenWISP ARM64 Quick Setup Script
# This script automates the setup process for ARM64 systems

set -e

echo "🚀 OpenWISP ARM64 Quick Setup"
echo "=============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running on ARM64
check_architecture() {
    log_info "Checking system architecture..."
    ARCH=$(uname -m)
    if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
        log_error "This script is designed for ARM64 systems. Detected: $ARCH"
        exit 1
    fi
    log_success "ARM64 architecture confirmed: $ARCH"
}

# Check Docker installation
check_docker() {
    log_info "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        echo "Visit: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    # Check Docker version
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    log_success "Docker found: $DOCKER_VERSION"
    
    # Check if user is in docker group
    if ! groups | grep -q docker; then
        log_warning "User not in docker group. You may need sudo for Docker commands."
        log_info "Run: sudo usermod -aG docker \$USER && newgrp docker"
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose not found. Please install Docker Compose."
        exit 1
    fi
    
    COMPOSE_VERSION=$(docker compose version | head -n1 | cut -d' ' -f4)
    log_success "Docker Compose found: $COMPOSE_VERSION"
    
    # Verify ARM64 support
    DOCKER_ARCH=$(docker version --format '{{.Server.Arch}}' 2>/dev/null || echo "unknown")
    if [[ "$DOCKER_ARCH" != "arm64" ]]; then
        log_warning "Docker architecture: $DOCKER_ARCH (expected: arm64)"
    else
        log_success "Docker ARM64 support confirmed"
    fi
}

# Check system resources
check_resources() {
    log_info "Checking system resources..."
    
    # Check memory
    MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEMORY_GB=$((MEMORY_KB / 1024 / 1024))
    
    if [[ $MEMORY_GB -lt 4 ]]; then
        log_warning "Low memory detected: ${MEMORY_GB}GB (4GB+ recommended)"
    else
        log_success "Memory: ${MEMORY_GB}GB"
    fi
    
    # Check disk space
    DISK_SPACE=$(df . | tail -1 | awk '{print $4}')
    DISK_SPACE_GB=$((DISK_SPACE / 1024 / 1024))
    
    if [[ $DISK_SPACE_GB -lt 10 ]]; then
        log_warning "Low disk space: ${DISK_SPACE_GB}GB available (10GB+ recommended)"
    else
        log_success "Disk space: ${DISK_SPACE_GB}GB available"
    fi
}

# Generate optimized .env file
generate_env_file() {
    log_info "Generating ARM64-optimized .env file..."
    
    # Prompt for basic configuration
    read -p "🌐 Dashboard domain (e.g., dashboard.example.com): " DASHBOARD_DOMAIN
    read -p "🔗 API domain (e.g., api.example.com): " API_DOMAIN
    read -p "📧 Admin email: " ADMIN_EMAIL
    
    # Generate secure passwords
    DB_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    INFLUX_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    SECRET_KEY=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-50)
    
    cat > .env << EOF
# OpenWISP ARM64 Configuration
# Generated on $(date)

# Essential Configuration
DASHBOARD_DOMAIN=${DASHBOARD_DOMAIN:-dashboard.localhost}
API_DOMAIN=${API_DOMAIN:-api.localhost}
VPN_DOMAIN=vpn.${DASHBOARD_DOMAIN:-localhost}
EMAIL_DJANGO_DEFAULT=${ADMIN_EMAIL:-admin@example.com}

# Database Configuration
DB_USER=openwisp
DB_PASS=${DB_PASS}
DB_NAME=openwisp

# PostgreSQL specific variables for kartoza/postgis
POSTGRES_USER=openwisp
POSTGRES_PASS=${DB_PASS}
POSTGRES_DBNAME=openwisp

# InfluxDB Configuration
INFLUXDB_USER=openwisp
INFLUXDB_PASS=${INFLUX_PASS}
INFLUXDB_NAME=openwisp

# Security
DJANGO_SECRET_KEY=${SECRET_KEY}

# SSL Configuration
SSL_CERT_MODE=SelfSigned
CERT_ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.com}

# ARM64 Performance Optimizations
UWSGI_PROCESSES=2
UWSGI_THREADS=2
UWSGI_LISTEN=100

# Enable/Disable Modules
USE_OPENWISP_RADIUS=True
USE_OPENWISP_TOPOLOGY=True
USE_OPENWISP_FIRMWARE=True
USE_OPENWISP_MONITORING=True

# ARM64 Celery Optimization
USE_OPENWISP_CELERY_TASK_ROUTES_DEFAULTS=True
OPENWISP_CELERY_COMMAND_FLAGS=--concurrency=1
USE_OPENWISP_CELERY_NETWORK=True
OPENWISP_CELERY_NETWORK_COMMAND_FLAGS=--concurrency=1
USE_OPENWISP_CELERY_MONITORING=True
OPENWISP_CELERY_MONITORING_COMMAND_FLAGS=--concurrency=1
USE_OPENWISP_CELERY_FIRMWARE=True
OPENWISP_CELERY_FIRMWARE_COMMAND_FLAGS=--concurrency=1

# Metric Collection
METRIC_COLLECTION=True

# Development Settings
DEBUG_MODE=False
DJANGO_LOG_LEVEL=INFO
TZ=UTC

# Additional Settings
COLLECTSTATIC_WHEN_DEPS_CHANGE=true
OPENWISP_GEOCODING_CHECK=True

# X509 Certificate Information
X509_NAME_CA=OpenWISP-CA
X509_NAME_CERT=OpenWISP
X509_COUNTRY_CODE=US
X509_STATE=California
X509_CITY=San Francisco
X509_ORGANIZATION_NAME=OpenWISP
X509_ORGANIZATION_UNIT_NAME=IT Department
X509_EMAIL=${ADMIN_EMAIL:-admin@example.com}
X509_COMMON_NAME=OpenWISP

# VPN Configuration
VPN_NAME=default
VPN_CLIENT_NAME=default-management-vpn
EOF
    
    log_success ".env file generated with ARM64 optimizations"
    log_info "Database password: ${DB_PASS}"
    log_info "InfluxDB password: ${INFLUX_PASS}"
    log_warning "Please save these passwords securely!"
}

# Build and start services
deploy_services() {
    log_info "Setting up Docker environment for ARM64..."
    
    # Set platform for ARM64
    export DOCKER_DEFAULT_PLATFORM=linux/arm64
    
    log_info "Building ARM64 images... (this may take 10-20 minutes)"
    docker compose build --parallel
    
    log_info "Starting services..."
    docker compose up -d
    
    log_info "Waiting for services to initialize..."
    sleep 30
    
    # Check service status
    log_info "Checking service status..."
    docker compose ps
}

# Wait for services to be ready
wait_for_services() {
    log_info "Waiting for services to be ready..."
    
    # Wait for database
    log_info "Waiting for PostgreSQL..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if docker compose exec postgres pg_isready -U openwisp -d openwisp &>/dev/null; then
            log_success "PostgreSQL is ready"
            break
        fi
        sleep 2
        timeout=$((timeout - 2))
    done
    
    if [ $timeout -le 0 ]; then
        log_warning "PostgreSQL timeout - check logs: docker compose logs postgres"
    fi
    
    # Wait for dashboard
    log_info "Waiting for dashboard service..."
    timeout=120
    while [ $timeout -gt 0 ]; do
        if curl -s -k --connect-timeout 5 "https://${DASHBOARD_DOMAIN:-localhost}" >/dev/null 2>&1; then
            log_success "Dashboard is responding"
            break
        fi
        sleep 5
        timeout=$((timeout - 5))
    done
    
    if [ $timeout -le 0 ]; then
        log_warning "Dashboard timeout - check logs: docker compose logs dashboard"
    fi
}

# Display final information
show_completion_info() {
    echo ""
    echo "🎉 OpenWISP ARM64 Deployment Complete!"
    echo "======================================"
    echo ""
    log_success "Services Status:"
    docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    log_info "Access URLs:"
    echo "  📊 Dashboard: https://${DASHBOARD_DOMAIN:-localhost}"
    echo "  🔌 API: https://${API_DOMAIN:-localhost}"
    echo ""
    
    log_info "For local access, add to /etc/hosts:"
    echo "  127.0.0.1 ${DASHBOARD_DOMAIN:-localhost}"
    echo "  127.0.0.1 ${API_DOMAIN:-localhost}"
    echo ""
    
    log_info "Useful commands:"
    echo "  📊 View logs: docker compose logs [service]"
    echo "  🔄 Restart: docker compose restart [service]"
    echo "  ⏹️  Stop all: docker compose down"
    echo "  🆙 Update: docker compose pull && docker compose up -d"
    echo ""
    
    log_info "Documentation:"
    echo "  📖 Usage Guide: ./ARM64-USAGE-GUIDE.md"
    echo "  🔧 Troubleshooting: ./ARM64-TROUBLESHOOTING.md"
    echo ""
    
    log_warning "Note: Using self-signed certificates. Browsers will show security warnings."
    log_info "For production, configure proper SSL certificates in .env (SSL_CERT_MODE=LetsEncrypt)"
}

# Handle errors
handle_error() {
    log_error "Setup failed at: $1"
    log_info "Check logs with: docker compose logs"
    log_info "For troubleshooting: ./ARM64-TROUBLESHOOTING.md"
    exit 1
}

# Main execution
main() {
    trap 'handle_error "line $LINENO"' ERR
    
    check_architecture
    check_docker
    check_resources
    
    if [[ ! -f .env ]]; then
        generate_env_file
    else
        log_info "Using existing .env file"
    fi
    
    deploy_services
    wait_for_services
    show_completion_info
}

# Run main function
main "$@"