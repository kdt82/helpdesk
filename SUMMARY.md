# GLPI Deployment Summary

## Project Overview

**Project**: GLPI Helpdesk System  
**Domain**: helpdesk.bluemoonit.com.au  
**Server**: 194.163.146.126  
**Location**: /opt/apps/glpi  
**Email**: support@bluemoonit.com.au  

## What is GLPI?

GLPI (Gestionnaire Libre de Parc Informatique) is an open-source IT Asset Management, issue tracking system and service desk solution. It provides:

- **Ticket Management**: Track and manage support requests
- **Asset Management**: Inventory of IT assets
- **Knowledge Base**: Document solutions and procedures
- **Email Integration**: Automated email notifications
- **User Portal**: Self-service for end users

## Architecture

```
Internet
    ↓
Traefik (HTTPS/SSL)
    ↓
GLPI Container (Docker)
    ↓
PostgreSQL Database (Host/Container)
    ↓
Resend SMTP (Email)
```

### Components

1. **GLPI Container** (`diouxx/glpi:latest`)
   - Runs PHP/Apache
   - Exposed via Traefik on port 80 (internal)
   - Persistent volumes for data

2. **PostgreSQL Database**
   - Existing PostgreSQL on host or in container
   - Dedicated database: `glpi`
   - Dedicated user: `glpi_user` (least privilege)

3. **Traefik Reverse Proxy**
   - Handles HTTPS/SSL (Let's Encrypt)
   - Routes traffic to GLPI container
   - Automatic certificate renewal

4. **Resend SMTP**
   - Outbound email notifications
   - Sender: support@bluemoonit.com.au
   - TLS encryption on port 587

## Files Included

### Core Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | Docker Compose configuration with Traefik labels |
| `.env.example` | Environment variable template |
| `.gitignore` | Prevents committing secrets |

### Database

| File | Description |
|------|-------------|
| `setup-database.sql` | PostgreSQL setup script |

### Documentation

| File | Description |
|------|-------------|
| `README.md` | Complete deployment guide |
| `DEPLOYMENT-CHECKLIST.md` | Step-by-step deployment checklist |
| `QUICK-REFERENCE.md` | Common commands and troubleshooting |
| `SUMMARY.md` | This file - project overview |

### Scripts

| File | Description |
|------|-------------|
| `deploy.sh` | Interactive deployment script |
| `backup.sh` | Automated backup script |
| `restore.sh` | Restore from backup script |

## Deployment Steps (Quick)

1. **Upload to Server**
   ```bash
   scp -r helpdesk/ root@194.163.146.126:/opt/apps/
   ```

2. **SSH to Server**
   ```bash
   ssh root@194.163.146.126
   cd /opt/apps/glpi
   ```

3. **Setup Database**
   ```bash
   psql -U postgres -f setup-database.sql
   ```

4. **Configure Environment**
   ```bash
   cp .env.example .env
   nano .env  # Edit with your values
   ```

5. **Deploy**
   ```bash
   chmod +x *.sh
   ./deploy.sh
   ```

6. **Access GLPI**
   - URL: https://helpdesk.bluemoonit.com.au
   - Username: `glpi`
   - Password: `glpi`
   - **Change password immediately!**

7. **Configure SMTP**
   - Setup → General → Notifications
   - Enter Resend credentials

## Key Features

### Security
- ✅ HTTPS only (via Traefik)
- ✅ Least privilege database user
- ✅ No direct internet exposure
- ✅ Environment variables for secrets
- ✅ Security headers configured

### Persistence
- ✅ Docker volumes for GLPI data
- ✅ Separate volumes for config, files, plugins
- ✅ PostgreSQL database (external)
- ✅ Backup scripts included

### Email Integration
- ✅ Resend SMTP configured
- ✅ Branded sender (Blue Moon IT Support)
- ✅ TLS encryption
- ✅ Reply-to configured

### Separation from bluemoonsite
- ✅ Separate Docker Compose stack
- ✅ Separate volumes
- ✅ Separate domain
- ✅ Can be migrated independently

## Configuration Details

### Environment Variables

```bash
# PostgreSQL
POSTGRES_HOST=host.docker.internal  # or container name
POSTGRES_PORT=5432
POSTGRES_DB=glpi
POSTGRES_USER=glpi_user
POSTGRES_PASSWORD=<strong_password>

# Resend SMTP
RESEND_API_KEY=re_xxxxx
SMTP_HOST=smtp.resend.com
SMTP_PORT=587
SMTP_FROM_EMAIL=support@bluemoonit.com.au
SMTP_FROM_NAME=Blue Moon IT Support
```

### Traefik Labels

```yaml
# HTTP to HTTPS redirect
traefik.http.routers.glpi-http.rule=Host(`helpdesk.bluemoonit.com.au`)
traefik.http.routers.glpi-http.middlewares=glpi-redirect

# HTTPS router
traefik.http.routers.glpi.rule=Host(`helpdesk.bluemoonit.com.au`)
traefik.http.routers.glpi.tls.certresolver=letsencrypt

# Service port
traefik.http.services.glpi.loadbalancer.server.port=80
```

### Docker Volumes

```yaml
volumes:
  glpi_data:        # Main GLPI installation
  glpi_config:      # Configuration files
  glpi_files:       # Uploaded files/documents
  glpi_plugins:     # Installed plugins
  glpi_marketplace: # Marketplace data
```

## Backup Strategy

### Automated Backups

```bash
# Run backup script
./backup.sh

# Schedule daily backups (cron)
0 2 * * * cd /opt/apps/glpi && ./backup.sh
```

### What Gets Backed Up

1. **Docker Volumes** (all GLPI data)
2. **PostgreSQL Database** (complete dump)
3. **Backup Manifest** (metadata)

### Retention

- Default: 30 days
- Configurable in `backup.sh`

### Restore

```bash
# List available backups
ls -lh /opt/backups/glpi/

# Restore from specific backup
./restore.sh 20260105_140000
```

## Maintenance

### Regular Tasks

**Daily**:
- Monitor logs for errors
- Check disk space
- Verify backup completion

**Weekly**:
- Review open tickets
- Check email delivery
- Update GLPI if needed

**Monthly**:
- Database optimization (VACUUM)
- Test backup restoration
- Review security settings

### Updates

```bash
# Pull latest image
docker compose pull

# Update GLPI
docker compose up -d --force-recreate
```

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Can't access GLPI | Check Traefik logs, verify DNS |
| Database connection failed | Verify PostgreSQL is running, check credentials |
| Email not sending | Verify Resend API key, check SMTP config |
| Permission errors | Run: `docker compose exec glpi chown -R www-data:www-data /var/www/html/glpi` |

### Logs

```bash
# GLPI logs
docker compose logs -f glpi

# Traefik logs
docker logs traefik | grep helpdesk

# PostgreSQL logs
docker logs postgres  # or check /var/log/postgresql/
```

## Migration Guide

To move GLPI to another server:

1. **Backup current installation**
   ```bash
   ./backup.sh
   ```

2. **Copy backup files to new server**
   ```bash
   scp /opt/backups/glpi/* root@new-server:/opt/backups/glpi/
   ```

3. **Copy deployment files to new server**
   ```bash
   scp -r /opt/apps/glpi root@new-server:/opt/apps/
   ```

4. **On new server, restore**
   ```bash
   cd /opt/apps/glpi
   ./restore.sh <backup_date>
   ```

5. **Update DNS**
   - Point `helpdesk.bluemoonit.com.au` to new server IP

6. **Verify**
   - Access GLPI
   - Test login
   - Send test email

## Security Checklist

- [ ] Change all default passwords
- [ ] Disable unused accounts
- [ ] Configure strong password policy
- [ ] Enable HTTPS only (automatic via Traefik)
- [ ] Restrict database access
- [ ] Use environment variables for secrets
- [ ] Regular security updates
- [ ] Monitor access logs
- [ ] Regular backups with encryption
- [ ] Review user permissions

## Support & Resources

### Documentation
- **README.md**: Complete deployment guide
- **QUICK-REFERENCE.md**: Common commands
- **DEPLOYMENT-CHECKLIST.md**: Step-by-step checklist

### External Resources
- GLPI Documentation: https://glpi-project.org/documentation/
- GLPI Forums: https://forum.glpi-project.org/
- Docker Image: https://hub.docker.com/r/diouxx/glpi
- Resend Docs: https://resend.com/docs

### Scripts
- `deploy.sh`: Interactive deployment
- `backup.sh`: Automated backups
- `restore.sh`: Restore from backup

## Next Steps

After deployment:

1. **Complete GLPI Setup**
   - Change default passwords
   - Configure user roles
   - Set up ticket categories
   - Customize branding

2. **Configure Email**
   - Set up SMTP (Resend)
   - Test email notifications
   - Configure email templates

3. **User Management**
   - Create user accounts
   - Assign roles
   - Set up permissions

4. **Backup Configuration**
   - Schedule automated backups
   - Test restoration process
   - Document backup location

5. **Monitoring**
   - Set up log monitoring
   - Configure alerts
   - Monitor disk space

## Questions?

Before deployment, verify:

1. **PostgreSQL Location**: Is it on the host or in a container?
2. **Resend API Key**: Do you have the API key ready?
3. **DNS**: Is `helpdesk.bluemoonit.com.au` pointing to the server?
4. **Traefik**: Is Traefik running and configured?

If you have any questions, please ask before proceeding with deployment.

---

**Created**: 2026-01-05  
**Version**: 1.0  
**Status**: Ready for deployment
