# GLPI Deployment Checklist

## Pre-Deployment

- [ ] DNS: Verify `helpdesk.bluemoonit.com.au` points to `194.163.146.126`
- [ ] Traefik: Confirm Traefik is running (`docker ps | grep traefik`)
- [ ] Network: Verify `proxy` network exists (`docker network ls | grep proxy`)
- [ ] PostgreSQL: Determine if running on host or in container
- [ ] Resend: Obtain API key from Resend dashboard
- [ ] Domain: Verify `support@bluemoonit.com.au` is configured in Resend

## Deployment Steps

### 1. Database Setup
- [ ] Connect to PostgreSQL server
- [ ] Run `setup-database.sql` script
- [ ] Verify database `glpi` was created
- [ ] Verify user `glpi_user` was created
- [ ] Test connection: `psql -U glpi_user -d glpi`

### 2. Environment Configuration
- [ ] Copy `.env.example` to `.env`
- [ ] Set `POSTGRES_HOST` (based on PostgreSQL location)
- [ ] Set `POSTGRES_PASSWORD` (from database setup)
- [ ] Set `RESEND_API_KEY`
- [ ] Verify all required variables are set

### 3. Deploy Container
- [ ] Navigate to `/opt/apps/glpi` on server
- [ ] Run `docker compose up -d`
- [ ] Check logs: `docker compose logs -f glpi`
- [ ] Verify container is running: `docker compose ps`
- [ ] Wait for GLPI initialization (may take 1-2 minutes)

### 4. Initial Configuration
- [ ] Access `https://helpdesk.bluemoonit.com.au`
- [ ] Complete installation wizard
- [ ] Select PostgreSQL database
- [ ] Enter database credentials
- [ ] Wait for database initialization
- [ ] Login with default credentials (`glpi` / `glpi`)

### 5. Security Hardening
- [ ] Change admin password (`glpi` account)
- [ ] Change or disable `tech` account
- [ ] Change or disable `normal` account
- [ ] Delete or disable `post-only` account
- [ ] Remove installation files (GLPI will prompt)

### 6. SMTP Configuration
- [ ] Navigate to Setup → General → Notifications
- [ ] Configure SMTP settings:
  - [ ] Host: `smtp.resend.com`
  - [ ] Port: `587`
  - [ ] Login: `resend`
  - [ ] Password: Resend API key
  - [ ] Sender: `support@bluemoonit.com.au`
  - [ ] Sender name: `Blue Moon IT Support`
  - [ ] Encryption: `TLS`
- [ ] Save configuration
- [ ] Send test email
- [ ] Verify email received

## Verification

### Database Connection
- [ ] Check GLPI logs for database errors
- [ ] Verify tables were created in `glpi` database
- [ ] Test query: `SELECT * FROM glpi_users;`

### Web Access
- [ ] HTTPS works: `curl -I https://helpdesk.bluemoonit.com.au`
- [ ] Certificate is valid (no browser warnings)
- [ ] Login page loads correctly
- [ ] Can log in with admin account

### Email Functionality
- [ ] Test email sent successfully
- [ ] Email received at test address
- [ ] Sender shows as `Blue Moon IT Support <support@bluemoonit.com.au>`
- [ ] Reply-to is set correctly
- [ ] Check Resend dashboard for delivery confirmation

### Traefik Integration
- [ ] Check Traefik dashboard (if enabled)
- [ ] Verify route exists for `helpdesk.bluemoonit.com.au`
- [ ] Verify SSL certificate was issued
- [ ] Test HTTP → HTTPS redirect

## Post-Deployment

### Configuration
- [ ] Set up user roles and permissions
- [ ] Configure ticket categories
- [ ] Set up SLA policies (if needed)
- [ ] Configure email notifications for ticket events
- [ ] Customize GLPI branding (optional)

### Backup Setup
- [ ] Document backup procedure
- [ ] Test volume backup
- [ ] Test database backup
- [ ] Schedule automated backups (cron job)
- [ ] Verify backup restoration process

### Documentation
- [ ] Document admin credentials (in password manager)
- [ ] Document database credentials (in password manager)
- [ ] Document Resend API key location
- [ ] Create user guide for ticket submission
- [ ] Document escalation procedures

## Troubleshooting

If issues occur, check:
- [ ] Docker logs: `docker compose logs glpi`
- [ ] Traefik logs: `docker logs traefik`
- [ ] PostgreSQL logs
- [ ] Network connectivity: `docker network inspect proxy`
- [ ] DNS resolution: `nslookup helpdesk.bluemoonit.com.au`

## Rollback Plan

If deployment fails:
1. [ ] Stop container: `docker compose down`
2. [ ] Remove volumes: `docker volume rm $(docker volume ls -q | grep helpdesk)`
3. [ ] Drop database: `DROP DATABASE glpi; DROP USER glpi_user;`
4. [ ] Review logs and fix issues
5. [ ] Retry deployment

## Success Criteria

Deployment is successful when:
- ✅ GLPI is accessible at `https://helpdesk.bluemoonit.com.au`
- ✅ Can log in with admin account
- ✅ Database connection is working
- ✅ Test email sends successfully
- ✅ HTTPS certificate is valid
- ✅ No errors in logs
- ✅ Can create and view tickets

---

**Deployment Date**: _____________  
**Deployed By**: _____________  
**Notes**: _____________
