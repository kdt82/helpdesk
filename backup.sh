#!/bin/bash

# GLPI Backup Script
# Creates backups of GLPI volumes and PostgreSQL database
# Run with: ./backup.sh

set -e

# Configuration
BACKUP_DIR="/opt/backups/glpi"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${NC}ℹ $1${NC}"
}

echo "=========================================="
echo "GLPI Backup Script"
echo "Date: $(date)"
echo "=========================================="
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# Backup Docker volumes
print_info "Backing up Docker volumes..."
docker run --rm \
  -v helpdesk_glpi_data:/data \
  -v helpdesk_glpi_config:/config \
  -v helpdesk_glpi_files:/files \
  -v helpdesk_glpi_plugins:/plugins \
  -v helpdesk_glpi_marketplace:/marketplace \
  -v "$BACKUP_DIR":/backup \
  alpine tar czf "/backup/glpi_volumes_${DATE}.tar.gz" \
    /data /config /files /plugins /marketplace

print_success "Volumes backed up to: glpi_volumes_${DATE}.tar.gz"

# Backup PostgreSQL database
print_info "Backing up PostgreSQL database..."

# Determine PostgreSQL location
if docker ps | grep -q postgres; then
    # PostgreSQL in container
    POSTGRES_CONTAINER=$(docker ps --filter "name=postgres" --format "{{.Names}}" | head -1)
    docker exec "$POSTGRES_CONTAINER" pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | \
        gzip > "$BACKUP_DIR/glpi_db_${DATE}.sql.gz"
else
    # PostgreSQL on host
    PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h "$POSTGRES_HOST" -U "$POSTGRES_USER" "$POSTGRES_DB" | \
        gzip > "$BACKUP_DIR/glpi_db_${DATE}.sql.gz"
fi

print_success "Database backed up to: glpi_db_${DATE}.sql.gz"

# Create backup manifest
cat > "$BACKUP_DIR/backup_${DATE}.manifest" <<EOF
GLPI Backup Manifest
====================
Date: $(date)
Hostname: $(hostname)

Files:
- glpi_volumes_${DATE}.tar.gz
- glpi_db_${DATE}.sql.gz

Database:
- Name: $POSTGRES_DB
- User: $POSTGRES_USER
- Host: $POSTGRES_HOST

Docker Volumes:
- helpdesk_glpi_data
- helpdesk_glpi_config
- helpdesk_glpi_files
- helpdesk_glpi_plugins
- helpdesk_glpi_marketplace

Restore Instructions:
1. Stop GLPI: docker compose down
2. Restore volumes: docker run --rm -v helpdesk_glpi_data:/data -v helpdesk_glpi_config:/config -v helpdesk_glpi_files:/files -v helpdesk_glpi_plugins:/plugins -v helpdesk_glpi_marketplace:/marketplace -v $BACKUP_DIR:/backup alpine tar xzf /backup/glpi_volumes_${DATE}.tar.gz
3. Restore database: gunzip < $BACKUP_DIR/glpi_db_${DATE}.sql.gz | psql -U $POSTGRES_USER -h $POSTGRES_HOST $POSTGRES_DB
4. Start GLPI: docker compose up -d
EOF

print_success "Backup manifest created"

# Calculate backup sizes
VOLUME_SIZE=$(du -h "$BACKUP_DIR/glpi_volumes_${DATE}.tar.gz" | cut -f1)
DB_SIZE=$(du -h "$BACKUP_DIR/glpi_db_${DATE}.sql.gz" | cut -f1)

echo ""
print_success "Backup completed successfully!"
echo ""
print_info "Backup location: $BACKUP_DIR"
print_info "Volume backup size: $VOLUME_SIZE"
print_info "Database backup size: $DB_SIZE"

# Clean up old backups
print_info "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "glpi_*" -type f -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "backup_*.manifest" -type f -mtime +$RETENTION_DAYS -delete

print_success "Old backups cleaned up"

echo ""
echo "=========================================="
echo "Backup Summary"
echo "=========================================="
echo "Total backups in $BACKUP_DIR:"
ls -lh "$BACKUP_DIR" | grep "glpi_" | wc -l
echo ""
echo "Recent backups:"
ls -lht "$BACKUP_DIR" | grep "glpi_" | head -5
echo ""
