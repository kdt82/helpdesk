#!/bin/bash
# GLPI Password Reset Token Expiration Fix
# This script diagnoses and fixes immediate token expiration issues

echo "=========================================="
echo "GLPI Password Reset Token Diagnostic"
echo "=========================================="
echo ""

# Check container timezone
echo "1. Checking GLPI container timezone..."
docker exec glpi date
docker exec glpi cat /etc/timezone
echo ""

# Check database timezone
echo "2. Checking MariaDB timezone..."
docker exec mariadb mysql -u root -p${DB_ROOT_PASSWORD:-rootpassword} -e "SELECT @@global.time_zone, @@session.time_zone, NOW();"
echo ""

# Check GLPI configuration
echo "3. Checking GLPI password reset configuration..."
docker exec mariadb mysql -u root -p${DB_ROOT_PASSWORD:-rootpassword} ${DB_NAME} -e "SELECT name, value FROM glpi_configs WHERE name LIKE '%password%' OR name LIKE '%token%';"
echo ""

# Check for existing password reset tokens
echo "4. Checking existing password reset tokens..."
docker exec mariadb mysql -u root -p${DB_ROOT_PASSWORD:-rootpassword} ${DB_NAME} -e "SELECT id, name, password_forget_token, password_forget_token_date FROM glpi_users WHERE password_forget_token IS NOT NULL;"
echo ""

# Check PHP timezone
echo "5. Checking PHP timezone..."
docker exec glpi php -r "echo 'PHP Timezone: ' . date_default_timezone_get() . PHP_EOL; echo 'Current Time: ' . date('Y-m-d H:i:s') . PHP_EOL;"
echo ""

echo "=========================================="
echo "Applying Fixes..."
echo "=========================================="
echo ""

# Fix 1: Set MariaDB timezone to Australia/Sydney
echo "Fix 1: Setting MariaDB timezone..."
docker exec mariadb mysql -u root -p${DB_ROOT_PASSWORD:-rootpassword} -e "SET GLOBAL time_zone = '+11:00';"
docker exec mariadb mysql -u root -p${DB_ROOT_PASSWORD:-rootpassword} -e "SET time_zone = '+11:00';"
echo "✓ MariaDB timezone set to +11:00 (Australia/Sydney)"
echo ""

# Fix 2: Clear all existing password reset tokens
echo "Fix 2: Clearing all existing password reset tokens..."
docker exec mariadb mysql -u root -p${DB_ROOT_PASSWORD:-rootpassword} ${DB_NAME} -e "UPDATE glpi_users SET password_forget_token = NULL, password_forget_token_date = NULL WHERE password_forget_token IS NOT NULL;"
echo "✓ All existing tokens cleared"
echo ""

# Fix 3: Verify GLPI config table has correct token validity
echo "Fix 3: Verifying token validity configuration..."
docker exec mariadb mysql -u root -p${DB_ROOT_PASSWORD:-rootpassword} ${DB_NAME} -e "SELECT name, value FROM glpi_configs WHERE name = 'password_expiration_delay';"
echo ""

# Fix 4: Restart GLPI container to apply timezone changes
echo "Fix 4: Restarting GLPI container..."
docker restart glpi
echo "✓ GLPI container restarted"
echo ""

# Wait for container to be ready
echo "Waiting for GLPI to be ready..."
sleep 10
echo ""

echo "=========================================="
echo "Verification"
echo "=========================================="
echo ""

# Verify timezones match
echo "Verifying timezone synchronization..."
echo -n "GLPI Container Time: "
docker exec glpi date "+%Y-%m-%d %H:%M:%S %Z"
echo -n "MariaDB Time: "
docker exec mariadb mysql -u root -p${DB_ROOT_PASSWORD:-rootpassword} -e "SELECT NOW();" -s -N
echo -n "Host System Time: "
date "+%Y-%m-%d %H:%M:%S %Z"
echo ""

echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Try sending a new password reset email"
echo "2. Check the token expiration time in the database:"
echo "   docker exec mariadb mysql -u root -p${DB_ROOT_PASSWORD:-rootpassword} ${DB_NAME} -e \"SELECT name, password_forget_token_date, DATE_ADD(password_forget_token_date, INTERVAL 1 DAY) as expires_at FROM glpi_users WHERE password_forget_token IS NOT NULL;\""
echo ""
echo "3. If issue persists, use manual password reset:"
echo "   docker exec -it glpi php /var/www/html/glpi/bin/console glpi:user:reset-password --user=USERNAME"
echo ""
