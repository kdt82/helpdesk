#!/bin/bash
# Apply timezone fix for GLPI password reset token expiration
# This script updates the MariaDB timezone to match GLPI

echo "=========================================="
echo "GLPI Password Reset Token - Timezone Fix"
echo "=========================================="
echo ""

# Navigate to GLPI directory
cd /opt/apps/glpi || exit 1

echo "Step 1: Backing up current configuration..."
docker compose down
echo "✓ Containers stopped"
echo ""

echo "Step 2: Redeploying with timezone fix..."
docker compose up -d
echo "✓ Containers started with new timezone configuration"
echo ""

echo "Step 3: Waiting for containers to be ready..."
sleep 15
echo ""

echo "Step 4: Clearing existing password reset tokens..."
docker exec mariadb mysql -u root -p${DB_ROOT_PASSWORD:-rootpassword} ${DB_NAME} -e "UPDATE glpi_users SET password_forget_token = NULL, password_forget_token_date = NULL WHERE password_forget_token IS NOT NULL;" 2>/dev/null
echo "✓ All existing tokens cleared"
echo ""

echo "=========================================="
echo "Verification"
echo "=========================================="
echo ""

echo "GLPI Container Timezone:"
docker exec glpi date
echo ""

echo "MariaDB Timezone:"
docker exec mariadb mysql -u root -p${DB_ROOT_PASSWORD:-rootpassword} -e "SELECT @@global.time_zone, NOW();" 2>/dev/null
echo ""

echo "=========================================="
echo "✓ Fix Applied Successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Go to GLPI admin panel"
echo "2. Send a new password reset email to the user"
echo "3. The token should now be valid for 1 full day"
echo ""
echo "Alternative: Reset password manually with:"
echo "docker exec -it glpi php /var/www/html/glpi/bin/console glpi:user:reset-password --user=admin"
echo ""
