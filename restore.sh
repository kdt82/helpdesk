#!/bin/bash

# GLPI Restore Script
# Restores GLPI volumes and PostgreSQL database from backup
# Usage: ./restore.sh <backup_date>
# Example: ./restore.sh 20260105_140000

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
    echo -e "${NC}ℹ $1${NC}"
}

# Configuration
BACKUP_DIR="/opt/backups/glpi"

echo "=========================================="
echo "GLPI Restore Script"
echo "=========================================="
echo ""

# Check if backup date provided
if [ -z "$1" ]; then
    print_error "No backup date provided"
    echo ""
    print_info "Usage: ./restore.sh <backup_date>"
    print_info "Example: ./restore.sh 20260105_140000"
    echo ""
    print_info "Available backups:"
    ls -1 "$BACKUP_DIR" | grep "glpi_volumes_" | sed 's/glpi_volumes_//' | sed 's/.tar.gz//' | sort -r | head -10
    exit 1
fi

BACKUP_DATE=$1
VOLUME_BACKUP="$BACKUP_DIR/glpi_volumes_${BACKUP_DATE}.tar.gz"
DB_BACKUP="$BACKUP_DIR/glpi_db_${BACKUP_DATE}.sql.gz"

# Verify backup files exist
if [ ! -f "$VOLUME_BACKUP" ]; then
    print_error "Volume backup not found: $VOLUME_BACKUP"
    exit 1
fi

if [ ! -f "$DB_BACKUP" ]; then
    print_error "Database backup not found: $DB_BACKUP"
    exit 1
fi

print_success "Found backup files:"
print_info "Volumes: $VOLUME_BACKUP ($(du -h "$VOLUME_BACKUP" | cut -f1))"
print_info "Database: $DB_BACKUP ($(du -h "$DB_BACKUP" | cut -f1))"
echo ""

# Load environment variables
if [ -f .env ]; then
    source .env
else
    print_error ".env file not found"
    exit 1
fi

# Warning
print_warning "WARNING: This will OVERWRITE all current GLPI data!"
print_warning "Make sure you have a backup of the current state if needed."
echo ""
read -p "Are you sure you want to continue? (yes/NO): " -r
echo ""
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_info "Restore cancelled"
    exit 0
fi

# Step 1: Stop GLPI
print_info "Stopping GLPI container..."
docker compose down
print_success "GLPI stopped"
echo ""

# Step 2: Restore volumes
print_info "Restoring Docker volumes..."
print_warning "This may take several minutes depending on backup size..."

docker run --rm \
  -v helpdesk_glpi_data:/data \
  -v helpdesk_glpi_config:/config \
  -v helpdesk_glpi_files:/files \
  -v helpdesk_glpi_plugins:/plugins \
  -v helpdesk_glpi_marketplace:/marketplace \
  -v "$BACKUP_DIR":/backup \
  alpine sh -c "
    cd / && 
    tar xzf /backup/glpi_volumes_${BACKUP_DATE}.tar.gz &&
    echo 'Volumes extracted successfully'
  "

print_success "Volumes restored"
echo ""

# Step 3: Restore database
print_info "Restoring PostgreSQL database..."

# Drop and recreate database
print_warning "Dropping existing database..."

if docker ps | grep -q postgres; then
    # PostgreSQL in container
    POSTGRES_CONTAINER=$(docker ps --filter "name=postgres" --format "{{.Names}}" | head -1)
    
    # Drop database
    docker exec "$POSTGRES_CONTAINER" psql -U postgres -c "DROP DATABASE IF EXISTS $POSTGRES_DB;"
    docker exec "$POSTGRES_CONTAINER" psql -U postgres -c "CREATE DATABASE $POSTGRES_DB WITH OWNER $POSTGRES_USER ENCODING 'UTF8';"
    
    # Restore database
    gunzip < "$DB_BACKUP" | docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" "$POSTGRES_DB"
else
    # PostgreSQL on host
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -U postgres -c "DROP DATABASE IF EXISTS $POSTGRES_DB;"
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -U postgres -c "CREATE DATABASE $POSTGRES_DB WITH OWNER $POSTGRES_USER ENCODING 'UTF8';"
    
    # Restore database
    gunzip < "$DB_BACKUP" | PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" "$POSTGRES_DB"
fi

print_success "Database restored"
echo ""

# Step 4: Start GLPI
print_info "Starting GLPI container..."
docker compose up -d
print_success "GLPI started"
echo ""

# Step 5: Verify
print_info "Waiting for GLPI to initialize..."
sleep 10

if docker compose ps | grep -q "Up"; then
    print_success "GLPI container is running"
else
    print_error "GLPI container failed to start"
    print_info "Check logs with: docker compose logs glpi"
    exit 1
fi

echo ""
echo "=========================================="
echo "Restore Complete!"
echo "=========================================="
echo ""
print_success "GLPI has been restored from backup: $BACKUP_DATE"
echo ""
print_info "Next steps:"
echo "1. Access GLPI at: https://helpdesk.bluemoonit.com.au"
echo "2. Verify data is correct"
echo "3. Test login functionality"
echo "4. Send a test email"
echo "5. Check recent tickets"
echo ""
print_info "If you encounter issues, check logs with:"
echo "  docker compose logs -f glpi"
echo ""

# Show recent logs
read -p "Do you want to view the logs? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker compose logs -f glpi
fi
