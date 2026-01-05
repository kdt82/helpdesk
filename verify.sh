#!/bin/bash

# GLPI Pre-Deployment Verification Script
# Checks all prerequisites before deploying GLPI
# Run this script before running deploy.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

ERRORS=0
WARNINGS=0

print_header "GLPI Pre-Deployment Verification"

# Check 1: Docker
print_info "Checking Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)
    print_success "Docker is installed (version $DOCKER_VERSION)"
else
    print_error "Docker is not installed"
    ((ERRORS++))
fi

# Check 2: Docker Compose
print_info "Checking Docker Compose..."
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version --short)
    print_success "Docker Compose is installed (version $COMPOSE_VERSION)"
else
    print_error "Docker Compose is not installed"
    ((ERRORS++))
fi

# Check 3: Traefik
print_info "Checking Traefik..."
if docker ps | grep -q traefik; then
    print_success "Traefik is running"
else
    print_error "Traefik is not running"
    print_info "Start Traefik before deploying GLPI"
    ((ERRORS++))
fi

# Check 4: Proxy Network
print_info "Checking proxy network..."
if docker network ls | grep -q proxy; then
    print_success "Proxy network exists"
else
    print_error "Proxy network does not exist"
    print_info "Create it with: docker network create proxy"
    ((ERRORS++))
fi

# Check 5: PostgreSQL
print_info "Checking PostgreSQL..."
POSTGRES_FOUND=false

if docker ps | grep -q postgres; then
    POSTGRES_CONTAINER=$(docker ps --filter "name=postgres" --format "{{.Names}}" | head -1)
    print_success "PostgreSQL container is running ($POSTGRES_CONTAINER)"
    POSTGRES_FOUND=true
    POSTGRES_LOCATION="container"
elif systemctl is-active --quiet postgresql 2>/dev/null; then
    print_success "PostgreSQL service is running on host"
    POSTGRES_FOUND=true
    POSTGRES_LOCATION="host"
elif pgrep -x postgres > /dev/null; then
    print_success "PostgreSQL process is running on host"
    POSTGRES_FOUND=true
    POSTGRES_LOCATION="host"
else
    print_error "PostgreSQL is not running"
    print_info "Start PostgreSQL before deploying GLPI"
    ((ERRORS++))
fi

# Check 6: DNS Resolution
print_info "Checking DNS for helpdesk.bluemoonit.com.au..."
if nslookup helpdesk.bluemoonit.com.au &> /dev/null; then
    DNS_IP=$(nslookup helpdesk.bluemoonit.com.au | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
    print_success "DNS resolves to: $DNS_IP"
    
    # Check if it points to this server
    SERVER_IP=$(hostname -I | awk '{print $1}')
    if [ "$DNS_IP" != "194.163.146.126" ]; then
        print_warning "DNS does not point to 194.163.146.126 (points to $DNS_IP)"
        print_info "Update DNS before deployment"
        ((WARNINGS++))
    fi
else
    print_warning "DNS lookup failed for helpdesk.bluemoonit.com.au"
    print_info "Ensure DNS is configured before deployment"
    ((WARNINGS++))
fi

# Check 7: Port Availability
print_info "Checking if ports are available..."
if netstat -tuln 2>/dev/null | grep -q ":80 "; then
    if docker ps | grep -q traefik; then
        print_success "Port 80 is used by Traefik (expected)"
    else
        print_warning "Port 80 is in use by another service"
        ((WARNINGS++))
    fi
else
    print_warning "Port 80 is not in use - Traefik may not be configured correctly"
    ((WARNINGS++))
fi

if netstat -tuln 2>/dev/null | grep -q ":443 "; then
    if docker ps | grep -q traefik; then
        print_success "Port 443 is used by Traefik (expected)"
    else
        print_warning "Port 443 is in use by another service"
        ((WARNINGS++))
    fi
else
    print_warning "Port 443 is not in use - Traefik may not be configured correctly"
    ((WARNINGS++))
fi

# Check 8: Disk Space
print_info "Checking disk space..."
AVAILABLE_SPACE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -gt 10 ]; then
    print_success "Sufficient disk space available (${AVAILABLE_SPACE}GB)"
else
    print_warning "Low disk space (${AVAILABLE_SPACE}GB available)"
    print_info "GLPI requires at least 5GB, 10GB+ recommended"
    ((WARNINGS++))
fi

# Check 9: Files Present
print_info "Checking required files..."
REQUIRED_FILES=("docker-compose.yml" ".env.example" "setup-database.sql" "README.md" "deploy.sh")
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_success "Found: $file"
    else
        print_error "Missing: $file"
        ((ERRORS++))
    fi
done

# Check 10: Environment File
print_info "Checking environment configuration..."
if [ -f ".env" ]; then
    print_success ".env file exists"
    
    # Check if it's been configured
    if grep -q "CHANGE_ME" .env; then
        print_warning ".env contains placeholder values (CHANGE_ME)"
        print_info "Update .env with actual values before deployment"
        ((WARNINGS++))
    else
        print_success ".env appears to be configured"
    fi
else
    print_warning ".env file does not exist"
    print_info "Copy .env.example to .env and configure it"
    ((WARNINGS++))
fi

# Check 11: PostgreSQL Database
if [ "$POSTGRES_FOUND" = true ]; then
    print_info "Checking if GLPI database exists..."
    
    if [ "$POSTGRES_LOCATION" = "container" ]; then
        if docker exec "$POSTGRES_CONTAINER" psql -U postgres -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw glpi; then
            print_warning "Database 'glpi' already exists"
            print_info "If this is a fresh install, you may need to drop the existing database"
            ((WARNINGS++))
        else
            print_success "Database 'glpi' does not exist (ready for setup)"
        fi
    else
        if psql -U postgres -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw glpi; then
            print_warning "Database 'glpi' already exists"
            print_info "If this is a fresh install, you may need to drop the existing database"
            ((WARNINGS++))
        else
            print_success "Database 'glpi' does not exist (ready for setup)"
        fi
    fi
fi

# Summary
print_header "Verification Summary"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    print_success "All checks passed! Ready to deploy GLPI"
    echo ""
    print_info "Next steps:"
    echo "  1. Review .env configuration"
    echo "  2. Run: ./deploy.sh"
    echo ""
    exit 0
elif [ $ERRORS -eq 0 ]; then
    print_warning "Verification completed with $WARNINGS warning(s)"
    echo ""
    print_info "You can proceed with deployment, but review the warnings above"
    echo ""
    print_info "Next steps:"
    echo "  1. Address warnings if needed"
    echo "  2. Review .env configuration"
    echo "  3. Run: ./deploy.sh"
    echo ""
    exit 0
else
    print_error "Verification failed with $ERRORS error(s) and $WARNINGS warning(s)"
    echo ""
    print_info "Please fix the errors above before deploying GLPI"
    echo ""
    exit 1
fi
