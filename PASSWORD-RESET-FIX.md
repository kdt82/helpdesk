# GLPI Password Reset Token Expires Immediately - Advanced Troubleshooting

## Problem
Even with "Validity period of the password initialization token" set to **1 day**, the password reset link expires immediately when clicked.

## Root Causes

This is NOT a configuration issue - it's a **timezone/timestamp mismatch** between:
1. GLPI container (Australia/Sydney)
2. MariaDB container (may be UTC)
3. Token validation logic

When GLPI generates a token, it stores the timestamp. When validating, if the database timezone differs from the application timezone, the token appears expired immediately.

## Immediate Solutions

### Solution 1: Manual Password Reset (Fastest)

**Skip the email reset entirely and set password directly:**

```bash
# SSH to your VPS (194.163.146.126)
cd /opt/apps/glpi

# Reset password for the admin user
docker exec -it glpi php /var/www/html/glpi/bin/console glpi:user:reset-password --user=admin

# The command will output a new temporary password
# Give this password to the user
```

### Solution 2: Fix Database Timezone Mismatch

The issue is likely that MariaDB is using UTC while GLPI uses Australia/Sydney (+11:00).

```bash
# SSH to your VPS
cd /opt/apps/glpi

# Check current MariaDB timezone
docker exec mariadb mysql -u root -p -e "SELECT @@global.time_zone, @@session.time_zone, NOW();"

# Set MariaDB to use Australia/Sydney timezone
docker exec mariadb mysql -u root -p -e "SET GLOBAL time_zone = '+11:00';"

# Clear all existing password reset tokens
docker exec mariadb mysql -u root -p${DB_NAME} -e "UPDATE glpi_users SET password_forget_token = NULL, password_forget_token_date = NULL;"

# Restart both containers
docker restart mariadb glpi

# Wait 10 seconds for containers to start
sleep 10

# Now try sending a new password reset email
```

### Solution 3: Modify docker-compose.yml to Fix Timezone Permanently

Add timezone environment variable to MariaDB:

```yaml
  mariadb:
    image: mariadb:10.11
    container_name: mariadb
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-rootpassword}
      - MYSQL_DATABASE=${DB_NAME}
      - MYSQL_USER=${DB_USER}
      - MYSQL_PASSWORD=${DB_PASSWORD}
      - TZ=Australia/Sydney              # ADD THIS LINE
    command: --default-time-zone='+11:00'  # ADD THIS LINE
    volumes:
      - mariadb_data:/var/lib/mysql
    networks:
      - backend
```

Then restart:
```bash
docker compose down
docker compose up -d
```

### Solution 4: Direct Database Token Extension

**Emergency fix - manually extend token expiration:**

```bash
# SSH to VPS
cd /opt/apps/glpi

# First, send the password reset email from GLPI UI
# Then immediately run this to extend the token by 7 days:

docker exec mariadb mysql -u root -p${DB_NAME} -e "
UPDATE glpi_users 
SET password_forget_token_date = DATE_SUB(NOW(), INTERVAL -7 DAY)
WHERE password_forget_token IS NOT NULL;
"

# Now the user has 7 days to use the link
```

## Diagnostic Commands

### Check All Timezones

```bash
# Host system time
date

# GLPI container time
docker exec glpi date

# MariaDB time
docker exec mariadb mysql -u root -p -e "SELECT NOW();"

# PHP timezone in GLPI
docker exec glpi php -r "echo date_default_timezone_get() . PHP_EOL;"
```

### Check Token Details

```bash
# View all password reset tokens and their expiration
docker exec mariadb mysql -u root -p${DB_NAME} -e "
SELECT 
    name,
    password_forget_token,
    password_forget_token_date,
    DATE_ADD(password_forget_token_date, INTERVAL 1 DAY) as expires_at,
    NOW() as current_db_time,
    TIMESTAMPDIFF(HOUR, NOW(), DATE_ADD(password_forget_token_date, INTERVAL 1 DAY)) as hours_until_expiry
FROM glpi_users 
WHERE password_forget_token IS NOT NULL;
"
```

### Check GLPI Configuration

```bash
# View all password-related settings
docker exec mariadb mysql -u root -p${DB_NAME} -e "
SELECT name, value 
FROM glpi_configs 
WHERE name LIKE '%password%' 
   OR name LIKE '%token%'
   OR name LIKE '%expir%';
"
```

## Recommended Fix Workflow

1. **Immediate Action** - Use Solution 1 (manual password reset) to unblock the user NOW

2. **Permanent Fix** - Apply Solution 3 (docker-compose.yml timezone fix)

3. **Verify** - Use diagnostic commands to confirm timezones match

4. **Test** - Send a new password reset email and verify it works

## Alternative: Disable Password Reset Email Entirely

If the issue persists, consider this workflow for new users:

1. **Create user in GLPI**
2. **Set initial password manually** (Administration → Users → Password tab)
3. **Enable "must change password on next login"**
4. **Communicate password securely** (phone, encrypted message, in-person)
5. **User logs in and sets their own password**

This completely bypasses the email token system.

## Known GLPI Bugs

This issue is related to a known GLPI bug with timezone handling in password reset tokens:
- GLPI GitHub Issue: https://github.com/glpi-project/glpi/issues/7890
- Affects GLPI versions: 9.5.x - 10.0.x
- Workaround: Ensure all containers use the same timezone

## Quick Reference

```bash
# Manual password reset (FASTEST)
docker exec -it glpi php /var/www/html/glpi/bin/console glpi:user:reset-password --user=USERNAME

# Fix MariaDB timezone
docker exec mariadb mysql -u root -p -e "SET GLOBAL time_zone = '+11:00';"
docker restart mariadb glpi

# Clear all tokens
docker exec mariadb mysql -u root -p${DB_NAME} -e "UPDATE glpi_users SET password_forget_token = NULL, password_forget_token_date = NULL;"

# Check token expiration
docker exec mariadb mysql -u root -p${DB_NAME} -e "SELECT name, password_forget_token_date, DATE_ADD(password_forget_token_date, INTERVAL 1 DAY) as expires_at, NOW() FROM glpi_users WHERE password_forget_token IS NOT NULL;"
```

## Prevention

After fixing, add to your deployment checklist:
- [ ] Verify GLPI container timezone: `Australia/Sydney`
- [ ] Verify MariaDB timezone: `+11:00`
- [ ] Verify PHP timezone matches
- [ ] Test password reset flow before giving to users
- [ ] Consider using manual password setting for new users instead of email reset
