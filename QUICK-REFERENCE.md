# GLPI Quick Reference Guide

## Common Commands

### Container Management

```bash
# Start GLPI
docker compose up -d

# Stop GLPI
docker compose down

# Restart GLPI
docker compose restart

# View logs (follow)
docker compose logs -f glpi

# View last 100 log lines
docker compose logs --tail=100 glpi

# Check container status
docker compose ps

# Access container shell
docker compose exec glpi bash
```

### Updates

```bash
# Pull latest GLPI image
docker compose pull

# Update GLPI (recreate container)
docker compose up -d --force-recreate

# Update with image pull
docker compose pull && docker compose up -d
```

### Backup & Restore

```bash
# Run backup script
./backup.sh

# Manual volume backup
docker run --rm \
  -v helpdesk_glpi_data:/data \
  -v /opt/backups/glpi:/backup \
  alpine tar czf /backup/glpi_volumes_$(date +%Y%m%d).tar.gz /data

# Manual database backup
docker exec postgres pg_dump -U glpi_user glpi | gzip > glpi_backup.sql.gz

# Restore volumes
docker compose down
docker run --rm \
  -v helpdesk_glpi_data:/data \
  -v /opt/backups/glpi:/backup \
  alpine tar xzf /backup/glpi_volumes_YYYYMMDD.tar.gz

# Restore database
gunzip < glpi_backup.sql.gz | docker exec -i postgres psql -U glpi_user glpi
docker compose up -d
```

### Database Operations

```bash
# Connect to PostgreSQL (if in container)
docker exec -it postgres psql -U glpi_user -d glpi

# Connect to PostgreSQL (if on host)
psql -U glpi_user -d glpi

# List tables
\dt

# Check database size
SELECT pg_size_pretty(pg_database_size('glpi'));

# List users
SELECT * FROM glpi_users;

# Vacuum database (maintenance)
VACUUM ANALYZE;
```

### Volume Management

```bash
# List GLPI volumes
docker volume ls | grep helpdesk

# Inspect volume
docker volume inspect helpdesk_glpi_data

# Check volume size
docker system df -v | grep helpdesk

# Remove unused volumes (DANGEROUS - only if GLPI is removed)
docker volume prune
```

## GLPI Configuration

### Access URLs

- **Main URL**: https://helpdesk.bluemoonit.com.au
- **Login**: https://helpdesk.bluemoonit.com.au/index.php

### Default Credentials

| Account | Username | Password | Role |
|---------|----------|----------|------|
| Admin | glpi | glpi | Super Admin |
| Tech | tech | tech | Technician |
| Normal | normal | normal | Normal User |
| Post-only | post-only | postonly | Post-only |

**⚠️ Change these immediately after installation!**

### SMTP Configuration (Resend)

Navigate to: **Setup → General → Notifications → Email followups configuration**

| Setting | Value |
|---------|-------|
| Way of sending emails | SMTP |
| SMTP host | smtp.resend.com |
| SMTP port | 587 |
| SMTP login | resend |
| SMTP password | [Your Resend API Key] |
| Email sender | support@bluemoonit.com.au |
| Email sender name | Blue Moon IT Support |
| Reply-to address | support@bluemoonit.com.au |
| SMTP encryption | TLS |

### Important Paths

| Path | Description |
|------|-------------|
| `/var/www/html/glpi` | GLPI installation directory |
| `/var/www/html/glpi/config` | Configuration files |
| `/var/www/html/glpi/files` | Uploaded files and documents |
| `/var/www/html/glpi/plugins` | Installed plugins |
| `/var/www/html/glpi/marketplace` | Marketplace data |

## Troubleshooting

### GLPI Not Accessible

```bash
# Check if container is running
docker compose ps

# Check Traefik logs
docker logs traefik | grep helpdesk

# Check GLPI logs
docker compose logs glpi | tail -50

# Test DNS
nslookup helpdesk.bluemoonit.com.au

# Test HTTPS
curl -I https://helpdesk.bluemoonit.com.au
```

### Database Connection Issues

```bash
# Test database connection from container
docker compose exec glpi psql -h $POSTGRES_HOST -U glpi_user -d glpi

# Check PostgreSQL is running
docker ps | grep postgres
# OR
systemctl status postgresql

# Check PostgreSQL logs
docker logs postgres
# OR
tail -f /var/log/postgresql/postgresql-*.log

# Verify database exists
docker exec postgres psql -U postgres -c "\l" | grep glpi
```

### Email Not Sending

```bash
# Check GLPI logs for SMTP errors
docker compose logs glpi | grep -i smtp

# Test SMTP connection
docker compose exec glpi telnet smtp.resend.com 587

# Verify Resend API key
# Check in GLPI UI: Setup → General → Notifications

# Check Resend dashboard for blocked sends
# https://resend.com/emails
```

### Performance Issues

```bash
# Check container resources
docker stats glpi

# Check disk space
df -h

# Check volume sizes
docker system df -v

# Optimize database
docker exec postgres psql -U glpi_user -d glpi -c "VACUUM ANALYZE;"

# Clear GLPI cache
docker compose exec glpi rm -rf /var/www/html/glpi/files/_cache/*
```

### Permission Issues

```bash
# Fix file permissions
docker compose exec glpi chown -R www-data:www-data /var/www/html/glpi

# Fix specific directories
docker compose exec glpi chown -R www-data:www-data /var/www/html/glpi/files
docker compose exec glpi chown -R www-data:www-data /var/www/html/glpi/config
```

## Monitoring

### Health Checks

```bash
# Check if GLPI is responding
curl -s -o /dev/null -w "%{http_code}" https://helpdesk.bluemoonit.com.au

# Check database connection
docker compose exec glpi psql -h $POSTGRES_HOST -U glpi_user -d glpi -c "SELECT 1;"

# Check disk usage
docker system df

# Check container health
docker inspect glpi | grep -A 10 Health
```

### Log Monitoring

```bash
# Follow all logs
docker compose logs -f

# Follow only errors
docker compose logs -f | grep -i error

# Search logs for specific term
docker compose logs glpi | grep "search_term"

# Export logs to file
docker compose logs glpi > glpi_logs_$(date +%Y%m%d).log
```

## Maintenance

### Regular Tasks

**Daily:**
- Monitor logs for errors
- Check disk space
- Verify backup completion

**Weekly:**
- Review open tickets
- Check email delivery (Resend dashboard)
- Update GLPI if new version available

**Monthly:**
- Run database vacuum/analyze
- Review user accounts
- Test backup restoration
- Review security settings

### Scheduled Maintenance

```bash
# Create cron job for daily backups
crontab -e

# Add this line (runs at 2 AM daily)
0 2 * * * cd /opt/apps/glpi && ./backup.sh >> /var/log/glpi-backup.log 2>&1

# Create cron job for weekly database optimization
0 3 * * 0 docker exec postgres psql -U glpi_user -d glpi -c "VACUUM ANALYZE;" >> /var/log/glpi-vacuum.log 2>&1
```

## Security

### Security Checklist

- [ ] Change all default passwords
- [ ] Disable unused accounts
- [ ] Enable HTTPS only (Traefik handles this)
- [ ] Configure strong password policy
- [ ] Enable two-factor authentication (if available)
- [ ] Regular security updates
- [ ] Monitor access logs
- [ ] Restrict database access
- [ ] Use environment variables for secrets
- [ ] Regular backups with encryption

### Access Control

```bash
# View active sessions in GLPI
# Navigate to: Administration → Users → [User] → Used items → Sessions

# Force logout all users (restart container)
docker compose restart glpi

# Review user permissions
# Navigate to: Administration → Profiles
```

## Integration

### Ticket Submission

**Email**: Users can email `support@bluemoonit.com.au` to create tickets (requires IMAP setup - not configured by default)

**Web Form**: Users can submit tickets at `https://helpdesk.bluemoonit.com.au`

**API**: GLPI has a REST API for integration (requires API client setup)

### Webhook Configuration

GLPI can send webhooks for ticket events:
1. Navigate to: **Setup → Notifications → Notification templates**
2. Create new template with webhook URL
3. Configure trigger events

## Useful SQL Queries

```sql
-- Count tickets by status
SELECT status, COUNT(*) FROM glpi_tickets GROUP BY status;

-- List recent tickets
SELECT id, name, date, status FROM glpi_tickets ORDER BY date DESC LIMIT 10;

-- Count users
SELECT COUNT(*) FROM glpi_users WHERE is_active = 1;

-- Database size
SELECT pg_size_pretty(pg_database_size('glpi'));

-- Table sizes
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
LIMIT 10;
```

## Emergency Procedures

### Complete System Failure

1. Check if Traefik is running: `docker ps | grep traefik`
2. Check if PostgreSQL is running: `docker ps | grep postgres` or `systemctl status postgresql`
3. Check if GLPI container is running: `docker compose ps`
4. Review logs: `docker compose logs glpi`
5. Restart GLPI: `docker compose restart glpi`
6. If still failing, restore from backup

### Data Corruption

1. Stop GLPI: `docker compose down`
2. Restore database from latest backup
3. Restore volumes from latest backup
4. Start GLPI: `docker compose up -d`
5. Verify data integrity

### Security Breach

1. Immediately change all passwords
2. Review access logs in GLPI
3. Check for unauthorized users
4. Restore from clean backup if necessary
5. Update all software
6. Review security settings

## Support Resources

- **GLPI Documentation**: https://glpi-project.org/documentation/
- **GLPI Forums**: https://forum.glpi-project.org/
- **GLPI GitHub**: https://github.com/glpi-project/glpi
- **Docker Image**: https://hub.docker.com/r/diouxx/glpi
- **Resend Documentation**: https://resend.com/docs

## Contact

For issues with this deployment, contact your system administrator.

For GLPI support, use the official channels listed above.
