# GitHub to VPS Deployment Guide

## 📦 Repository Information

**GitHub Repository**: https://github.com/kdt82/helpdesk  
**VPS Server**: 194.163.146.126  
**Deployment Path**: `/opt/apps/helpdesk/`  
**Domain**: helpdesk.bluemoonit.com.au  

## 🚀 Quick Deployment Steps

### 1. SSH to Your VPS

```bash
ssh root@194.163.146.126
```

### 2. Navigate to Apps Directory

```bash
cd /opt/apps
```

### 3. Clone the Repository

```bash
git clone https://github.com/kdt82/helpdesk.git
cd helpdesk
```

### 4. Make Scripts Executable

```bash
chmod +x *.sh
```

### 5. Verify Prerequisites

```bash
./verify.sh
```

This will check:
- ✅ Docker and Docker Compose installed
- ✅ Traefik running
- ✅ Proxy network exists
- ✅ PostgreSQL running
- ✅ DNS configured
- ✅ Disk space sufficient

### 6. Setup PostgreSQL Database

```bash
# If PostgreSQL is on the host
psql -U postgres -f setup-database.sql

# If PostgreSQL is in a container
docker exec -i postgres psql -U postgres < setup-database.sql
```

**Important**: Change the password in the SQL script before running!

### 7. Create and Configure .env File

```bash
cp .env.example .env
nano .env
```

**Required configuration**:

```bash
# PostgreSQL Connection
POSTGRES_HOST=host.docker.internal  # or container name if PostgreSQL is in Docker
POSTGRES_PORT=5432
POSTGRES_DB=glpi
POSTGRES_USER=glpi_user
POSTGRES_PASSWORD=YOUR_STRONG_PASSWORD_HERE  # Match the one in setup-database.sql

# Resend SMTP
RESEND_API_KEY=re_YOUR_API_KEY_HERE
SMTP_HOST=smtp.resend.com
SMTP_PORT=587
SMTP_ENCRYPTION=tls
SMTP_USERNAME=resend
SMTP_FROM_EMAIL=support@bluemoonit.com.au
SMTP_FROM_NAME=Blue Moon IT Support
```

### 8. Deploy GLPI

```bash
./deploy.sh
```

The script will:
1. Check prerequisites again
2. Prompt for any missing configuration
3. Deploy the GLPI container
4. Verify the deployment

### 9. Complete Web Installation

1. **Access GLPI**: https://helpdesk.bluemoonit.com.au
2. **Select language**: English
3. **Accept license**: Continue
4. **Choose**: Install
5. **Database configuration**:
   - SQL server: `host.docker.internal` (or your PostgreSQL host)
   - SQL user: `glpi_user`
   - SQL password: (from your `.env` file)
   - Database: `glpi`
6. **Continue** through initialization
7. **Login** with default credentials:
   - Username: `glpi`
   - Password: `glpi`
8. **IMPORTANT**: Change the password immediately!

### 10. Configure SMTP (Resend)

1. Navigate to: **Setup** → **General** → **Notifications**
2. Click on **Email followups configuration**
3. Configure:
   - Way of sending emails: **SMTP**
   - SMTP host: `smtp.resend.com`
   - SMTP port: `587`
   - SMTP login: `resend`
   - SMTP password: (Your Resend API key from `.env`)
   - Email sender: `support@bluemoonit.com.au`
   - Email sender name: `Blue Moon IT Support`
   - Reply-to address: `support@bluemoonit.com.au`
   - SMTP encryption: **TLS**
4. **Save** configuration
5. **Send test email** to verify

## 🔄 Updating from GitHub

If you make changes to the repository and need to update the VPS:

```bash
cd /opt/apps/helpdesk

# Backup first!
./backup.sh

# Pull latest changes
git pull origin main

# If docker-compose.yml changed, recreate containers
docker compose up -d --force-recreate

# Check logs
docker compose logs -f glpi
```

## 📋 Post-Deployment Checklist

- [ ] GLPI accessible at https://helpdesk.bluemoonit.com.au
- [ ] HTTPS certificate valid (no warnings)
- [ ] Can log in with admin account
- [ ] Default password changed
- [ ] Database connection working
- [ ] SMTP configured
- [ ] Test email sent and received
- [ ] No errors in logs: `docker compose logs glpi`
- [ ] Backup script tested: `./backup.sh`
- [ ] Cron job scheduled for daily backups

## 🔐 Security Reminders

After deployment:

1. **Change all default passwords**:
   - Admin account (`glpi`)
   - Tech account (`tech`) - or disable
   - Normal account (`normal`) - or disable
   - Post-only account (`post-only`) - or disable

2. **Remove installation files** (GLPI will prompt)

3. **Set up automated backups**:
   ```bash
   crontab -e
   # Add this line (runs daily at 2 AM):
   0 2 * * * cd /opt/apps/helpdesk && ./backup.sh >> /var/log/glpi-backup.log 2>&1
   ```

4. **Document credentials** in your password manager

## 🆘 Troubleshooting

### Can't access GLPI

```bash
# Check container status
docker compose ps

# Check logs
docker compose logs glpi

# Check Traefik
docker logs traefik | grep helpdesk

# Test DNS
nslookup helpdesk.bluemoonit.com.au
```

### Database connection failed

```bash
# Check PostgreSQL is running
docker ps | grep postgres
# OR
systemctl status postgresql

# Test connection from GLPI container
docker compose exec glpi psql -h $POSTGRES_HOST -U glpi_user -d glpi
```

### Email not sending

1. Verify Resend API key is correct
2. Check SMTP configuration in GLPI UI
3. Review logs: `docker compose logs glpi | grep -i smtp`
4. Check Resend dashboard for blocked sends

## 📚 Documentation

All documentation is in the repository:

- **INDEX.md** - Start here for navigation
- **README.md** - Complete deployment guide
- **SUMMARY.md** - Project overview
- **QUICK-REFERENCE.md** - Common commands
- **DEPLOYMENT-CHECKLIST.md** - Step-by-step checklist
- **ARCHITECTURE.md** - System architecture diagrams

## 🎯 Success Criteria

Deployment is successful when:

✅ GLPI accessible at https://helpdesk.bluemoonit.com.au  
✅ HTTPS certificate valid  
✅ Can log in with admin account  
✅ Database connection working  
✅ Test email sends successfully  
✅ No errors in logs  
✅ Can create and view tickets  
✅ Backups working  

---

**Need help?** Check the documentation files or review the logs with `docker compose logs -f glpi`
