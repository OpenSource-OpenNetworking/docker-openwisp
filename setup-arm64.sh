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
    
    # Clean up if force rebuild is requested
    if [[ "${FORCE_REBUILD:-false}" == "true" ]]; then
        log_info "Force rebuild requested - cleaning up existing images..."
        docker compose down -v --remove-orphans 2>/dev/null || true
        docker images -q | grep -E "docker-openwisp-gmail" | xargs -r docker rmi -f 2>/dev/null || true
        docker system prune -f >/dev/null 2>&1 || true
    fi
    
    log_info "Building ARM64 images... (this may take 10-20 minutes)"
    
    # Build base image first to avoid dependency issues
    log_info "Building OpenWISP base image..."
    if ! docker compose build openwisp-base; then
        log_error "Failed to build base image"
        exit 1
    fi
    
    # Fix Dockerfile image references for dependent services
    log_info "Ensuring correct image references..."
    fix_dockerfile_references
    
    # Build services using direct docker build to avoid compose issues
    log_info "Building dashboard service..."
    if ! (cd images && docker build -t docker-openwisp-gmail-openwisp-dashboard:latest -f openwisp_dashboard/Dockerfile --build-arg BUILDPLATFORM=linux/arm64 .); then
        log_error "Failed to build dashboard service"
        exit 1
    fi
    
    log_info "Building API service..."
    if ! (cd images && docker build -t docker-openwisp-gmail-openwisp-api:latest -f openwisp_api/Dockerfile --build-arg BUILDPLATFORM=linux/arm64 .); then
        log_error "Failed to build API service"
        exit 1
    fi
    
    log_info "Building websocket service..."
    if ! (cd images && docker build -t docker-openwisp-gmail-openwisp-websocket:latest -f openwisp_websocket/Dockerfile --build-arg BUILDPLATFORM=linux/arm64 .); then
        log_error "Failed to build websocket service"
        exit 1
    fi
    
    # Build remaining services using compose
    log_info "Building remaining services..."
    if ! docker compose build nginx freeradius postfix openvpn; then
        log_error "Failed to build remaining services"
        exit 1
    fi
    
    log_info "Starting services..."
    docker compose up -d
    
    log_info "Waiting for services to initialize..."
    sleep 30
    
    # Check service status
    log_info "Checking service status..."
    docker compose ps
}

# Fix Dockerfile image references to use correct tags
fix_dockerfile_references() {
    log_info "Fixing Dockerfile image references..."
    
    # Update dashboard Dockerfile
    if grep -q "FROM docker-openwisp-gmail-openwisp-base$" images/openwisp_dashboard/Dockerfile 2>/dev/null; then
        sed -i 's|FROM docker-openwisp-gmail-openwisp-base$|FROM docker-openwisp-gmail-openwisp-base:latest|g' images/openwisp_dashboard/Dockerfile
        log_info "Fixed dashboard Dockerfile"
    fi
    
    # Update api Dockerfile - remove platform directive and fix tag
    if grep -q "FROM --platform=\$BUILDPLATFORM docker-openwisp-gmail-openwisp-base" images/openwisp_api/Dockerfile 2>/dev/null; then
        sed -i 's|FROM --platform=\$BUILDPLATFORM docker-openwisp-gmail-openwisp-base.*|FROM docker-openwisp-gmail-openwisp-base:latest|g' images/openwisp_api/Dockerfile
        log_info "Fixed API Dockerfile"
    fi
    
    # Update websocket Dockerfile - remove platform directive and fix tag
    if grep -q "FROM --platform=\$BUILDPLATFORM docker-openwisp-gmail-openwisp-base" images/openwisp_websocket/Dockerfile 2>/dev/null; then
        sed -i 's|FROM --platform=\$BUILDPLATFORM docker-openwisp-gmail-openwisp-base.*|FROM docker-openwisp-gmail-openwisp-base:latest|g' images/openwisp_websocket/Dockerfile
        log_info "Fixed websocket Dockerfile"
    fi
    
    # Remove duplicate hadolint comments
    find images -name "Dockerfile" -exec sed -i '/^# hadolint ignore=DL3007$/N;s/# hadolint ignore=DL3007\n# hadolint ignore=DL3007/# hadolint ignore=DL3007/' {} \;
}

# Wait for services to be ready
wait_for_services() {
    log_info "Waiting for services to be ready..."
    
    # Wait for database
    log_info "Waiting for PostgreSQL..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if docker compose exec -T postgres pg_isready -U openwisp -d openwisp &>/dev/null; then
            log_success "PostgreSQL is ready"
            break
        fi
        sleep 2
        timeout=$((timeout - 2))
    done
    
    if [ $timeout -le 0 ]; then
        log_warning "PostgreSQL timeout - check logs: docker compose logs postgres"
        return 1
    fi
    
    # Wait for dashboard service to be ready
    log_info "Waiting for dashboard service..."
    timeout=120
    while [ $timeout -gt 0 ]; do
        if docker compose exec -T dashboard python manage.py check &>/dev/null; then
            log_success "Dashboard service is ready"
            break
        fi
        sleep 5
        timeout=$((timeout - 5))
    done
    
    if [ $timeout -le 0 ]; then
        log_warning "Dashboard service timeout - check logs: docker compose logs dashboard"
        return 1
    fi
    
    # Wait for web interface
    log_info "Waiting for web interface..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if curl -s -k --connect-timeout 5 "https://${DASHBOARD_DOMAIN:-localhost}/admin/" | grep -q "OpenWISP" 2>/dev/null; then
            log_success "Web interface is accessible"
            break
        fi
        sleep 5
        timeout=$((timeout - 5))
    done
    
    if [ $timeout -le 0 ]; then
        log_warning "Web interface timeout - checking nginx logs..."
        docker compose logs nginx | tail -10
    fi
    
    return 0
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
    echo "  📊 Dashboard: https://${DASHBOARD_DOMAIN:-localhost}/admin/"
    echo "  🔌 API: https://${API_DOMAIN:-localhost}/api/"
    echo ""
    
    # Show admin user information
    ADMIN_COUNT=$(docker compose exec -T dashboard python manage.py shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); print(User.objects.filter(is_superuser=True).count())" 2>/dev/null | tail -1)
    if [[ "$ADMIN_COUNT" -gt 0 ]]; then
        log_success "Admin user exists (count: $ADMIN_COUNT)"
    else
        log_warning "No admin user found. Create one with:"
        echo "  docker compose exec dashboard python manage.py createsuperuser"
    fi
    echo ""
    
    log_info "For local access, add to /etc/hosts (if using custom domains):"
    if [[ "${DASHBOARD_DOMAIN:-localhost}" != "localhost" ]]; then
        echo "  127.0.0.1 ${DASHBOARD_DOMAIN}"
    fi
    if [[ "${API_DOMAIN:-localhost}" != "localhost" ]]; then
        echo "  127.0.0.1 ${API_DOMAIN}"
    fi
    echo ""
    
    log_info "Useful commands:"
    echo "  📊 View logs: docker compose logs [service]"
    echo "  🔄 Restart: docker compose restart [service]"
    echo "  ⏹️  Stop all: docker compose down"
    echo "  🆙 Update: docker compose pull && docker compose up -d"
    echo "  👤 Create admin: docker compose exec dashboard python manage.py createsuperuser"
    echo ""
    
    log_info "Performance monitoring:"
    echo "  📈 Resource usage: docker stats"
    echo "  🔍 Service health: docker compose ps"
    echo "  📋 System monitor: ./monitor.sh (if available)"
    echo ""
    
    log_info "Documentation:"
    echo "  📖 Usage Guide: ./ARM64-USAGE-GUIDE.md"
    echo "  🔧 Troubleshooting: ./ARM64-TROUBLESHOOTING.md"
    echo ""
    
    log_warning "Note: Using self-signed certificates. Browsers will show security warnings."
    log_info "For production, configure proper SSL certificates in .env (SSL_CERT_MODE=LetsEncrypt)"
    
    # Display resource usage
    echo ""
    log_info "Current resource usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -5
}

# Handle errors
handle_error() {
    local exit_code=$?
    local line_no=$1
    
    log_error "Setup failed at line $line_no with exit code $exit_code"
    
    # Show recent logs for debugging
    echo ""
    log_info "Recent Docker Compose logs:"
    docker compose logs --tail=20 2>/dev/null || echo "No logs available"
    
    echo ""
    log_info "Service status:"
    docker compose ps 2>/dev/null || echo "No services running"
    
    echo ""
    log_info "Troubleshooting steps:"
    echo "  1. Check logs: docker compose logs [service_name]"
    echo "  2. Check system resources: docker stats"
    echo "  3. Restart failed services: docker compose restart [service_name]"
    echo "  4. Complete reset: docker compose down && docker system prune -f"
    echo "  5. Consult documentation: ./ARM64-TROUBLESHOOTING.md"
    
    exit $exit_code
}

# Cleanup function for script interruption
cleanup() {
    log_warning "Script interrupted. Cleaning up..."
    docker compose down 2>/dev/null || true
    exit 1
}

# Validate environment before starting
validate_environment() {
    log_info "Validating environment..."
    
    # Check if docker-compose.yml exists
    if [[ ! -f docker-compose.yml ]]; then
        log_error "docker-compose.yml not found. Please run this script from the project root."
        exit 1
    fi
    
    # Check available disk space for build
    AVAILABLE_SPACE=$(df . | tail -1 | awk '{print $4}')
    AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))
    
    if [[ $AVAILABLE_GB -lt 5 ]]; then
        log_error "Insufficient disk space: ${AVAILABLE_GB}GB available (minimum 5GB required)"
        exit 1
    fi
    
    # Check if ports are available
    local ports=("80" "443" "1812" "1813" "8086" "5432")
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            log_warning "Port $port appears to be in use"
        fi
    done
    
    log_success "Environment validation passed"
}

# Quick health check function
health_check() {
    log_info "Performing health check..."
    
    # Check if services are running
    local running_services=$(docker compose ps --services --filter "status=running" | wc -l)
    local total_services=$(docker compose ps --services | wc -l)
    
    log_info "Services running: $running_services/$total_services"
    
    # Check database connectivity
    if docker compose exec -T postgres pg_isready -U openwisp -d openwisp &>/dev/null; then
        log_success "Database: Connected"
    else
        log_error "Database: Not accessible"
        return 1
    fi
    
    # Check web interface
    if curl -s -k --connect-timeout 5 "https://localhost/admin/" | grep -q "OpenWISP" 2>/dev/null; then
        log_success "Web interface: Accessible"
    else
        log_warning "Web interface: Not accessible"
    fi
    
    # Check resource usage
    local mem_usage=$(docker stats --no-stream --format "{{.MemPerc}}" | head -1 | sed 's/%//')
    if (( $(echo "$mem_usage > 80" | bc -l) )); then
        log_warning "High memory usage: ${mem_usage}%"
    else
        log_success "Memory usage: ${mem_usage}%"
    fi
    
    return 0
}

# Main execution
main() {
    # Set up signal handlers
    trap 'handle_error $LINENO' ERR
    trap 'cleanup' INT TERM
    
    # Validate environment first
    validate_environment
    
    # System checks
    check_architecture
    check_docker
    check_resources
    
    # Configuration setup
    if [[ ! -f .env ]]; then
        log_warning "No .env file found. Generating configuration..."
        generate_env_file
    else
        log_info "Using existing .env file"
        # Validate essential variables
        if ! grep -q "DASHBOARD_DOMAIN" .env; then
            log_warning ".env file missing DASHBOARD_DOMAIN. Please check configuration."
        fi
    fi
    
    # Deployment
    deploy_services
    
    # Verification (skip if requested)
    if [[ "${SKIP_WAIT:-false}" != "true" ]]; then
        if wait_for_services; then
            show_completion_info
            log_success "OpenWISP ARM64 deployment completed successfully!"
        else
            log_error "Some services failed to start properly. Check logs for details."
            exit 1
        fi
    else
        log_info "Skipping service readiness checks as requested"
        show_completion_info
        log_info "OpenWISP ARM64 deployment started. Use 'docker compose ps' to check status."
    fi
}

# Cleanup OpenWISP containers and images
cleanup_openwisp() {
    log_info "🧹 Starting OpenWISP cleanup..."
    
    # Stop and remove containers
    log_info "Stopping OpenWISP containers..."
    if docker compose ps -q 2>/dev/null | grep -q .; then
        docker compose down -v 2>/dev/null || true
        log_success "OpenWISP containers stopped and removed"
    else
        log_info "No running OpenWISP containers found"
    fi
    
    # Remove OpenWISP images
    log_info "Removing OpenWISP images..."
    local images_removed=0
    
    # Get OpenWISP related images
    local openwisp_images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "(openwisp|docker-openwisp)" || true)
    
    if [[ -n "$openwisp_images" ]]; then
        while IFS= read -r image; do
            if [[ -n "$image" ]]; then
                log_info "Removing image: $image"
                if docker rmi "$image" >/dev/null 2>&1; then
                    ((images_removed++))
                else
                    log_warning "Failed to remove image: $image (may be in use)"
                fi
            fi
        done <<< "$openwisp_images"
        log_success "Removed $images_removed OpenWISP images"
    else
        log_info "No OpenWISP images found"
    fi
    
    # Clean up dangling images
    log_info "Removing dangling images..."
    local dangling_count=$(docker images --filter "dangling=true" -q | wc -l)
    if [[ $dangling_count -gt 0 ]]; then
        docker image prune -f >/dev/null 2>&1
        log_success "Removed $dangling_count dangling images"
    else
        log_info "No dangling images found"
    fi
    
    # Clean up unused volumes (optional - ask user)
    if [[ "${CLEANUP_VOLUMES:-false}" == "true" ]]; then
        log_warning "Removing unused volumes (this will delete all data)..."
        docker volume prune -f >/dev/null 2>&1
        log_success "Unused volumes removed"
    fi
    
    # Clean up unused networks
    log_info "Cleaning up unused networks..."
    docker network prune -f >/dev/null 2>&1
    
    # System cleanup
    log_info "Performing system cleanup..."
    docker system prune -f >/dev/null 2>&1
    
    log_success "OpenWISP cleanup completed!"
    
    # Show remaining Docker resources
    log_info "Remaining Docker resources:"
    echo "Images: $(docker images -q | wc -l)"
    echo "Containers: $(docker ps -aq | wc -l)"
    echo "Volumes: $(docker volume ls -q | wc -l)"
    echo "Networks: $(docker network ls -q | wc -l)"
}

# Interactive cleanup with confirmation
interactive_cleanup() {
    echo "🧹 OpenWISP Interactive Cleanup"
    echo "==============================="
    echo ""
    echo "This will remove:"
    echo "  ✓ All OpenWISP containers"
    echo "  ✓ All OpenWISP images"
    echo "  ✓ All dangling images"
    echo "  ✓ Unused networks"
    echo "  ✓ Build cache"
    echo ""
    
    # Ask about volumes
    read -p "⚠️  Also remove data volumes? This will DELETE ALL DATA! (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        CLEANUP_VOLUMES=true
        echo "  ✓ Data volumes will be removed"
    else
        echo "  ⏭  Data volumes will be preserved"
    fi
    
    echo ""
    read -p "Continue with cleanup? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup_openwisp
    else
        log_info "Cleanup cancelled"
        exit 0
    fi
}

# Show help information
show_help() {
    echo "OpenWISP ARM64 Setup Script"
    echo "=========================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -v, --verbose       Enable verbose logging"
    echo "  -f, --force         Force rebuild of all images"
    echo "  --no-wait           Skip service readiness checks"
    echo "  --health-check      Perform health check on existing deployment"
    echo "  --status            Show current deployment status"
    echo "  --cleanup           Clean OpenWISP containers and images (interactive)"
    echo "  --cleanup-all       Clean everything including data volumes (non-interactive)"
    echo "  --cleanup-images    Clean only OpenWISP images (preserve containers/data)"
    echo ""
    echo "Examples:"
    echo "  $0                      # Normal setup"
    echo "  $0 --verbose            # Setup with detailed logs"
    echo "  $0 --force              # Force rebuild all images"
    echo "  $0 --health-check       # Check deployment health"
    echo "  $0 --status             # Show current status"
    echo "  $0 --cleanup            # Interactive cleanup"
    echo "  $0 --cleanup-all        # Full cleanup (destructive)"
    echo "  $0 --cleanup-images     # Clean only images"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            set -x
            shift
            ;;
        -f|--force)
            FORCE_REBUILD=true
            shift
            ;;
        --no-wait)
            SKIP_WAIT=true
            shift
            ;;
        --health-check)
            validate_environment
            health_check
            exit $?
            ;;
        --status)
            validate_environment
            echo "🔍 OpenWISP ARM64 Status Check"
            echo "=============================="
            docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"
            echo ""
            echo "📊 Resource Usage:"
            docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -5
            exit 0
            ;;
        --cleanup)
            validate_environment
            interactive_cleanup
            exit 0
            ;;
        --cleanup-all)
            validate_environment
            log_warning "Performing full cleanup (including data volumes)..."
            CLEANUP_VOLUMES=true
            cleanup_openwisp
            exit 0
            ;;
        --cleanup-images)
            validate_environment
            log_info "🧹 Cleaning OpenWISP images only..."
            
            # Check if containers are running
            running_containers=$(docker compose ps -q 2>/dev/null | wc -l)
            if [[ $running_containers -gt 0 ]]; then
                log_warning "OpenWISP containers are running. Stopping them first..."
                docker compose down >/dev/null 2>&1
                log_success "Containers stopped"
            fi
            
            # Remove OpenWISP images
            openwisp_images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "(openwisp|docker-openwisp)" || true)
            images_removed=0
            
            if [[ -n "$openwisp_images" ]]; then
                while IFS= read -r image; do
                    if [[ -n "$image" ]]; then
                        log_info "Removing image: $image"
                        if docker rmi "$image" >/dev/null 2>&1; then
                            ((images_removed++))
                        else
                            log_warning "Failed to remove image: $image (may be in use)"
                        fi
                    fi
                done <<< "$openwisp_images"
                log_success "Removed $images_removed OpenWISP images"
            else
                log_info "No OpenWISP images found"
            fi
            
            # Clean dangling images
            docker image prune -f >/dev/null 2>&1
            log_success "Image cleanup completed!"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main "$@"