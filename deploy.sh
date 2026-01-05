#!/bin/bash

# GLPI Quick Deployment Script
# This script helps with the initial deployment of GLPI
# Run on the VPS server at: /opt/apps/glpi

set -e  # Exit on error

echo "=========================================="
echo "GLPI Helpdesk Deployment Script"
echo "Domain: helpdesk.bluemoonit.com.au"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
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
    echo -e "${NC}ℹ $1${NC}"
}

# Check if running on the server
if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml not found!"
    print_info "Please run this script from /opt/apps/glpi directory"
    exit 1
fi

# Step 1: Check prerequisites
echo "Step 1: Checking prerequisites..."
echo ""

# Check Docker
if command -v docker &> /dev/null; then
    print_success "Docker is installed"
else
    print_error "Docker is not installed"
    exit 1
fi

# Check Docker Compose
if docker compose version &> /dev/null; then
    print_success "Docker Compose is installed"
else
    print_error "Docker Compose is not installed"
    exit 1
fi

# Check Traefik
if docker ps | grep -q traefik; then
    print_success "Traefik is running"
else
    print_warning "Traefik is not running - GLPI will not be accessible via HTTPS"
fi

# Check proxy network
if docker network ls | grep -q proxy; then
    print_success "Proxy network exists"
else
    print_error "Proxy network does not exist"
    print_info "Create it with: docker network create proxy"
    exit 1
fi

# Check PostgreSQL
echo ""
print_info "Checking PostgreSQL..."
if docker ps | grep -q postgres; then
    print_success "PostgreSQL container is running"
    POSTGRES_LOCATION="container"
elif systemctl is-active --quiet postgresql 2>/dev/null; then
    print_success "PostgreSQL service is running on host"
    POSTGRES_LOCATION="host"
elif pgrep -x postgres > /dev/null; then
    print_success "PostgreSQL process is running on host"
    POSTGRES_LOCATION="host"
else
    print_error "PostgreSQL is not running"
    print_info "Please start PostgreSQL before deploying GLPI"
    exit 1
fi

echo ""
echo "=========================================="
echo "Step 2: Environment Configuration"
echo "=========================================="
echo ""

# Check if .env exists
if [ -f ".env" ]; then
    print_warning ".env file already exists"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Using existing .env file"
    else
        cp .env.example .env
        print_success "Created new .env file from template"
    fi
else
    cp .env.example .env
    print_success "Created .env file from template"
fi

# Prompt for configuration
echo ""
print_info "Please configure the following settings in .env:"
echo ""

# PostgreSQL Host
if [ "$POSTGRES_LOCATION" = "container" ]; then
    print_info "PostgreSQL is running in a container"
    read -p "Enter PostgreSQL container name (or press Enter for 'postgres'): " POSTGRES_CONTAINER
    POSTGRES_CONTAINER=${POSTGRES_CONTAINER:-postgres}
    sed -i "s/POSTGRES_HOST=.*/POSTGRES_HOST=$POSTGRES_CONTAINER/" .env
    print_success "Set POSTGRES_HOST=$POSTGRES_CONTAINER"
else
    print_info "PostgreSQL is running on the host"
    print_warning "Using host.docker.internal - if this doesn't work, try 172.17.0.1"
    sed -i "s/POSTGRES_HOST=.*/POSTGRES_HOST=host.docker.internal/" .env
    print_success "Set POSTGRES_HOST=host.docker.internal"
fi

# Database password
echo ""
read -sp "Enter PostgreSQL password for glpi_user: " DB_PASSWORD
echo ""
if [ -n "$DB_PASSWORD" ]; then
    sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$DB_PASSWORD/" .env
    print_success "Set database password"
else
    print_warning "No password entered - please update .env manually"
fi

# Resend API key
echo ""
read -sp "Enter Resend API key (or press Enter to skip): " RESEND_KEY
echo ""
if [ -n "$RESEND_KEY" ]; then
    sed -i "s/RESEND_API_KEY=.*/RESEND_API_KEY=$RESEND_KEY/" .env
    print_success "Set Resend API key"
else
    print_warning "No Resend API key entered - configure SMTP later in GLPI UI"
fi

echo ""
echo "=========================================="
echo "Step 3: Database Setup"
echo "=========================================="
echo ""

print_info "You need to create the PostgreSQL database and user"
print_info "SQL script is available in: setup-database.sql"
echo ""

if [ "$POSTGRES_LOCATION" = "container" ]; then
    print_info "Run this command to create the database:"
    echo "  docker exec -i $POSTGRES_CONTAINER psql -U postgres < setup-database.sql"
else
    print_info "Run this command to create the database:"
    echo "  psql -U postgres -f setup-database.sql"
fi

echo ""
read -p "Have you created the database? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Please create the database before deploying GLPI"
    print_info "You can run this script again after creating the database"
    exit 0
fi

echo ""
echo "=========================================="
echo "Step 4: Deploy GLPI"
echo "=========================================="
echo ""

print_info "Starting GLPI container..."
docker compose up -d

echo ""
print_success "GLPI container started!"
echo ""

print_info "Waiting for GLPI to initialize (this may take 1-2 minutes)..."
sleep 10

# Check container status
if docker compose ps | grep -q "Up"; then
    print_success "GLPI container is running"
else
    print_error "GLPI container failed to start"
    print_info "Check logs with: docker compose logs glpi"
    exit 1
fi

echo ""
echo "=========================================="
echo "Step 5: Verification"
echo "=========================================="
echo ""

# Check logs for errors
print_info "Checking logs for errors..."
if docker compose logs glpi | grep -i error | grep -v "No such file" | grep -q .; then
    print_warning "Found errors in logs - please review:"
    docker compose logs glpi | grep -i error | tail -5
else
    print_success "No critical errors found in logs"
fi

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""

print_success "GLPI has been deployed successfully!"
echo ""
print_info "Next steps:"
echo ""
echo "1. Access GLPI at: https://helpdesk.bluemoonit.com.au"
echo "2. Complete the installation wizard"
echo "3. Login with default credentials:"
echo "   - Username: glpi"
echo "   - Password: glpi"
echo "4. IMPORTANT: Change the default password immediately!"
echo "5. Configure SMTP in Setup → General → Notifications"
echo "6. Send a test email to verify configuration"
echo ""
print_info "For detailed instructions, see README.md"
print_info "For deployment checklist, see DEPLOYMENT-CHECKLIST.md"
echo ""

# Show logs
read -p "Do you want to view the logs? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker compose logs -f glpi
fi
