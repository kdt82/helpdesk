# GLPI Helpdesk System

GLPI (Gestionnaire Libre de Parc Informatique) is an open-source IT Asset Management, issue tracking system and service desk solution.

**Domain**: `helpdesk.bluemoonit.com.au`  
**Email**: `support@bluemoonit.com.au`

## Architecture

- **GLPI Container**: Runs the GLPI application (PHP/Apache)
- **Database**: Uses existing PostgreSQL on the host server
- **Reverse Proxy**: Traefik handles HTTPS and routing
- **Email**: Resend SMTP for outbound notifications

## Prerequisites

1. **PostgreSQL** must be running on the host (check with the commands below)
2. **Traefik** must be running with the `proxy` network created
3. **DNS**: `helpdesk.bluemoonit.com.au` must point to `194.163.146.126`
4. **Resend API Key**: Obtain from Resend dashboard

## Initial Setup

### Step 1: Check PostgreSQL Status

First, determine if PostgreSQL is running in a container or on the host:

```bash
# Check if PostgreSQL is running in a container
docker ps | grep postgres

# Check if PostgreSQL is running on the host
systemctl status postgresql
# OR
ps aux | grep postgres
```

**If PostgreSQL is in a container:**
- Update `.env` file: `POSTGRES_HOST=<container_name>`
- Ensure the container is on the `proxy` network or create a shared network

**If PostgreSQL is on the host:**
- Update `.env` file: `POSTGRES_HOST=host.docker.internal` (or `172.17.0.1`)
- Ensure PostgreSQL accepts connections from Docker containers

### Step 2: Create PostgreSQL Database and User

Connect to your PostgreSQL server and run the setup script:

```bash
# If PostgreSQL is on the host
psql -U postgres -f setup-database.sql

# If PostgreSQL is in a container
docker exec -i <postgres_container_name> psql -U postgres < setup-database.sql
```

**Manual SQL commands** (if you prefer):

```sql
-- Create user
CREATE USER glpi_user WITH PASSWORD 'YOUR_STRONG_PASSWORD_HERE';

-- Create database
CREATE DATABASE glpi WITH OWNER glpi_user ENCODING 'UTF8';

-- Connect to glpi database
\c glpi

-- Grant privileges
GRANT ALL PRIVILEGES ON SCHEMA public TO glpi_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO glpi_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO glpi_user;
GRANT CREATE ON SCHEMA public TO glpi_user;
```

### Step 3: Configure Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Edit the .env file with your actual values
nano .env
```

**Required changes in `.env`:**

1. **PostgreSQL Connection**:
   - `POSTGRES_HOST`: Set based on Step 1 findings
   - `POSTGRES_PASSWORD`: Use the password from Step 2
   
2. **Resend SMTP**:
   - `RESEND_API_KEY`: Your Resend API key

### Step 4: Deploy GLPI

```bash
# Deploy the stack
docker compose up -d

# Check logs
docker compose logs -f glpi

# Verify container is running
docker compose ps
```

### Step 5: Complete GLPI Installation

1. **Access GLPI**: Navigate to `https://helpdesk.bluemoonit.com.au`

2. **Installation Wizard**:
   - Select language: **English**
   - Accept license terms
   - Choose **Install**
   - Database setup:
     - SQL server: `<your_postgres_host>`
     - SQL user: `glpi_user`
     - SQL password: `<from_your_.env>`
     - Database: `glpi`
   - Click **Continue** through initialization
   
3. **Default Credentials**:
   - **Admin**: `glpi` / `glpi`
   - **Tech**: `tech` / `tech`
   - **Normal**: `normal` / `normal`
   - **Post-only**: `post-only` / `postonly`

4. **IMPORTANT**: Change the default passwords immediately!

### Step 6: Configure SMTP (Resend)

1. Log in as admin (`glpi` / `glpi`)

2. Navigate to: **Setup** → **General** → **Notifications**

3. Configure **Email followups configuration**:
   - **Way of sending emails**: SMTP
   - **SMTP host**: `smtp.resend.com`
   - **SMTP port**: `587`
   - **SMTP login**: `resend`
   - **SMTP password**: Your Resend API key (from `.env`)
   - **Email sender**: `support@bluemoonit.com.au`
   - **Email sender name**: `Blue Moon IT Support`
   - **Reply-to address**: `support@bluemoonit.com.au`
   - **SMTP encryption**: `TLS`

4. **Save** the configuration

5. **Test Email**:
   - Go to **Setup** → **Notifications** → **Email followups configuration**
   - Click **Send a test email**
   - Enter a test email address
   - Check if email is received

### Step 7: Post-Installation Security

1. **Change all default passwords**
2. **Remove or disable unused accounts**
3. **Configure user permissions** under **Administration** → **Profiles**
4. **Enable notifications** for ticket updates
5. **Remove installation files** (GLPI will prompt you)

## Verification Steps

### 1. Database Connection

```bash
# Check GLPI logs for database connection
docker compose logs glpi | grep -i database

# Should see successful connection messages
```

### 2. Web Access

```bash
# Test HTTPS access
curl -I https://helpdesk.bluemoonit.com.au

# Should return 200 OK
```

### 3. Login Test

- Navigate to `https://helpdesk.bluemoonit.com.au`
- Log in with default credentials
- Change password immediately

### 4. Email Test

- Configure SMTP as per Step 6
- Send a test email from GLPI UI
- Verify receipt at test email address
- Check Resend dashboard for delivery status

## Backup Strategy

### What to Backup

1. **Docker Volumes** (GLPI data):
   ```bash
   docker volume ls | grep helpdesk
   ```
   
   Volumes to backup:
   - `helpdesk_glpi_data` - Main GLPI installation
   - `helpdesk_glpi_config` - Configuration files
   - `helpdesk_glpi_files` - Uploaded files and documents
   - `helpdesk_glpi_plugins` - Installed plugins
   - `helpdesk_glpi_marketplace` - Marketplace data

2. **PostgreSQL Database**:
   ```bash
   # Backup database
   pg_dump -U glpi_user -h localhost glpi > glpi_backup_$(date +%Y%m%d).sql
   
   # Or if PostgreSQL is in a container
   docker exec <postgres_container> pg_dump -U glpi_user glpi > glpi_backup_$(date +%Y%m%d).sql
   ```

### Backup Commands

```bash
# Create backup directory
mkdir -p /opt/backups/glpi

# Backup all volumes
docker run --rm \
  -v helpdesk_glpi_data:/data \
  -v helpdesk_glpi_config:/config \
  -v helpdesk_glpi_files:/files \
  -v helpdesk_glpi_plugins:/plugins \
  -v helpdesk_glpi_marketplace:/marketplace \
  -v /opt/backups/glpi:/backup \
  alpine tar czf /backup/glpi_volumes_$(date +%Y%m%d).tar.gz /data /config /files /plugins /marketplace

# Backup database
pg_dump -U glpi_user -h localhost glpi | gzip > /opt/backups/glpi/glpi_db_$(date +%Y%m%d).sql.gz
```

### Restore Process

```bash
# Stop GLPI
docker compose down

# Restore volumes
docker run --rm \
  -v helpdesk_glpi_data:/data \
  -v helpdesk_glpi_config:/config \
  -v helpdesk_glpi_files:/files \
  -v helpdesk_glpi_plugins:/plugins \
  -v helpdesk_glpi_marketplace:/marketplace \
  -v /opt/backups/glpi:/backup \
  alpine tar xzf /backup/glpi_volumes_YYYYMMDD.tar.gz

# Restore database
gunzip < /opt/backups/glpi/glpi_db_YYYYMMDD.sql.gz | psql -U glpi_user -h localhost glpi

# Start GLPI
docker compose up -d
```

## Maintenance

### Update GLPI

```bash
# Pull latest image
docker compose pull

# Recreate container
docker compose up -d

# Check logs
docker compose logs -f glpi
```

### View Logs

```bash
# Follow logs
docker compose logs -f glpi

# Last 100 lines
docker compose logs --tail=100 glpi
```

### Restart Service

```bash
# Restart GLPI
docker compose restart glpi

# Full restart
docker compose down && docker compose up -d
```

## Troubleshooting

### Cannot Connect to Database

1. **Check PostgreSQL is running**:
   ```bash
   # On host
   systemctl status postgresql
   
   # In container
   docker ps | grep postgres
   ```

2. **Verify PostgreSQL accepts connections**:
   ```bash
   # Check pg_hba.conf allows Docker network
   # Location: /etc/postgresql/*/main/pg_hba.conf
   
   # Add line if needed:
   host    glpi    glpi_user    172.17.0.0/16    md5
   ```

3. **Test connection from container**:
   ```bash
   docker exec -it glpi psql -h $POSTGRES_HOST -U glpi_user -d glpi
   ```

### GLPI Not Accessible

1. **Check Traefik routing**:
   ```bash
   docker logs traefik | grep helpdesk
   ```

2. **Verify DNS**:
   ```bash
   nslookup helpdesk.bluemoonit.com.au
   ```

3. **Check container health**:
   ```bash
   docker compose ps
   docker compose logs glpi
   ```

### Email Not Sending

1. **Verify Resend API key** is correct in GLPI settings
2. **Check SMTP configuration** matches Resend requirements
3. **Review GLPI logs** for SMTP errors
4. **Test with Resend dashboard** - check for blocked sends
5. **Verify sender domain** (`support@bluemoonit.com.au`) is verified in Resend

### Permission Issues

```bash
# Fix volume permissions
docker compose exec glpi chown -R www-data:www-data /var/www/html/glpi
```

## Migration Notes

This deployment is designed to be **independent** from the `bluemoonsite` project:
- Separate Docker Compose stack
- Separate volumes
- Separate domain
- Can be moved to a different server without affecting bluemoonsite

To migrate to another server:
1. Backup volumes and database (see Backup Strategy)
2. Copy `docker-compose.yml` and `.env` to new server
3. Restore volumes and database
4. Update DNS to point to new server IP
5. Deploy with `docker compose up -d`

## Support

- **GLPI Documentation**: https://glpi-project.org/documentation/
- **GLPI Forums**: https://forum.glpi-project.org/
- **Docker Image**: https://hub.docker.com/r/diouxx/glpi

## Notes

- **No plugins** are installed by default (as per requirements)
- **IMAP integration** is not configured (outbound SMTP only)
- **Traefik** handles all HTTPS/SSL automatically
- **PostgreSQL** connection uses host database (not containerized)
- **Alerts email** (`alerts@bluemoonit.com.au`) is reserved for future monitoring use
