# GLPI Architecture Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                    │
│                                  ↓                                       │
│                    helpdesk.bluemoonit.com.au                           │
│                         (194.163.146.126)                               │
└─────────────────────────────────────────────────────────────────────────┘
                                   ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         VPS SERVER (Ubuntu)                              │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                    TRAEFIK (Reverse Proxy)                      │    │
│  │  • HTTPS/SSL (Let's Encrypt)                                   │    │
│  │  • Port 80 → 443 redirect                                      │    │
│  │  • Certificate resolver: letsencrypt                           │    │
│  │  • Network: proxy                                              │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                   ↓                                      │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │              GLPI CONTAINER (diouxx/glpi:latest)               │    │
│  │                                                                 │    │
│  │  ┌─────────────────────────────────────────────────────────┐  │    │
│  │  │              Apache + PHP + GLPI                        │  │    │
│  │  │  • Port: 80 (internal)                                  │  │    │
│  │  │  • Timezone: Australia/Sydney                           │  │    │
│  │  │  • Network: proxy                                       │  │    │
│  │  └─────────────────────────────────────────────────────────┘  │    │
│  │                           ↓                                     │    │
│  │  ┌─────────────────────────────────────────────────────────┐  │    │
│  │  │              DOCKER VOLUMES                             │  │    │
│  │  │  • glpi_data       (main installation)                  │  │    │
│  │  │  • glpi_config     (configuration files)                │  │    │
│  │  │  • glpi_files      (uploaded files)                     │  │    │
│  │  │  • glpi_plugins    (plugins)                            │  │    │
│  │  │  • glpi_marketplace (marketplace data)                  │  │    │
│  │  └─────────────────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                   ↓                                      │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │              POSTGRESQL DATABASE                               │    │
│  │  • Database: glpi                                              │    │
│  │  • User: glpi_user (least privilege)                           │    │
│  │  • Location: Host or Container                                 │    │
│  │  • Connection: host.docker.internal or container name          │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                   ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                    RESEND SMTP (smtp.resend.com)                         │
│  • Port: 587 (STARTTLS)                                                 │
│  • From: support@bluemoonit.com.au                                      │
│  • From Name: Blue Moon IT Support                                      │
│  • Auth: resend / API_KEY                                               │
└─────────────────────────────────────────────────────────────────────────┘
```

## Network Flow

```
User Request Flow:
──────────────────

1. User → https://helpdesk.bluemoonit.com.au
2. DNS → 194.163.146.126
3. Traefik (Port 443) → SSL Termination
4. Traefik → Route to GLPI container (Port 80)
5. GLPI → Process request
6. GLPI → Query PostgreSQL database
7. PostgreSQL → Return data
8. GLPI → Render response
9. Traefik → Return to user (HTTPS)

Email Notification Flow:
────────────────────────

1. GLPI → Ticket event triggers notification
2. GLPI → Connect to smtp.resend.com:587
3. GLPI → Authenticate with API key
4. GLPI → Send email from support@bluemoonit.com.au
5. Resend → Deliver email to recipient
```

## Docker Network Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      Docker Network: proxy                       │
│                                                                  │
│  ┌──────────────┐         ┌──────────────┐                     │
│  │   Traefik    │────────▶│     GLPI     │                     │
│  │  Container   │         │  Container   │                     │
│  └──────────────┘         └──────────────┘                     │
│         │                         │                             │
│         │                         │                             │
│         ▼                         ▼                             │
│    Port 80/443            host.docker.internal                 │
│                                   │                             │
└───────────────────────────────────┼─────────────────────────────┘
                                    │
                                    ▼
                          ┌──────────────────┐
                          │   PostgreSQL     │
                          │  (Host/Container)│
                          └──────────────────┘
```

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         GLPI Container                           │
│                                                                  │
│  ┌────────────┐    ┌────────────┐    ┌────────────┐           │
│  │   Apache   │───▶│    PHP     │───▶│    GLPI    │           │
│  │   (Port 80)│    │  Runtime   │    │Application │           │
│  └────────────┘    └────────────┘    └────────────┘           │
│                                              │                  │
│                          ┌───────────────────┼──────────────┐  │
│                          ▼                   ▼              ▼  │
│                    ┌──────────┐      ┌──────────┐  ┌──────────┐│
│                    │  Config  │      │  Files   │  │ Plugins  ││
│                    │  Volume  │      │  Volume  │  │  Volume  ││
│                    └──────────┘      └──────────┘  └──────────┘│
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
                        ┌─────────────────┐
                        │   PostgreSQL    │
                        │    Database     │
                        │                 │
                        │  Tables:        │
                        │  • glpi_users   │
                        │  • glpi_tickets │
                        │  • glpi_items   │
                        │  • ...          │
                        └─────────────────┘
```

## Backup Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Backup Process                              │
│                                                                  │
│  ┌────────────────┐                                             │
│  │  backup.sh     │                                             │
│  │   (Script)     │                                             │
│  └────────┬───────┘                                             │
│           │                                                      │
│           ├──────────────────┬──────────────────┐               │
│           ▼                  ▼                  ▼               │
│  ┌─────────────────┐ ┌─────────────┐  ┌──────────────┐        │
│  │ Docker Volumes  │ │  PostgreSQL │  │   Manifest   │        │
│  │   (tar.gz)      │ │   (sql.gz)  │  │    (.txt)    │        │
│  └─────────────────┘ └─────────────┘  └──────────────┘        │
│           │                  │                  │               │
│           └──────────────────┴──────────────────┘               │
│                              ▼                                  │
│                   /opt/backups/glpi/                            │
│                   • glpi_volumes_YYYYMMDD.tar.gz                │
│                   • glpi_db_YYYYMMDD.sql.gz                     │
│                   • backup_YYYYMMDD.manifest                    │
│                                                                  │
│                   Retention: 30 days                            │
└─────────────────────────────────────────────────────────────────┘
```

## Security Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                      Security Architecture                       │
│                                                                  │
│  Layer 1: Network Security                                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ • Firewall (VPS)                                       │    │
│  │ • Only ports 80/443 exposed                            │    │
│  │ • Traefik handles all external traffic                 │    │
│  └────────────────────────────────────────────────────────┘    │
│                              ↓                                  │
│  Layer 2: Transport Security                                    │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ • HTTPS only (TLS 1.2+)                                │    │
│  │ • Let's Encrypt certificates                           │    │
│  │ • Automatic certificate renewal                        │    │
│  │ • HTTP → HTTPS redirect                                │    │
│  └────────────────────────────────────────────────────────┘    │
│                              ↓                                  │
│  Layer 3: Application Security                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ • GLPI authentication                                  │    │
│  │ • Role-based access control                            │    │
│  │ • Session management                                   │    │
│  │ • Input validation                                     │    │
│  └────────────────────────────────────────────────────────┘    │
│                              ↓                                  │
│  Layer 4: Database Security                                     │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ • Dedicated database user (least privilege)            │    │
│  │ • Password authentication                              │    │
│  │ • Network isolation                                    │    │
│  │ • Encrypted connections (optional)                     │    │
│  └────────────────────────────────────────────────────────┘    │
│                              ↓                                  │
│  Layer 5: Data Security                                         │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ • Docker volumes (isolated)                            │    │
│  │ • Regular backups (encrypted)                          │    │
│  │ • Environment variables for secrets                    │    │
│  │ • No secrets in version control                        │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Deployment States

```
┌─────────────────────────────────────────────────────────────────┐
│                    Deployment State Machine                      │
│                                                                  │
│  ┌──────────┐                                                   │
│  │  INITIAL │                                                   │
│  └────┬─────┘                                                   │
│       │ verify.sh                                               │
│       ▼                                                          │
│  ┌──────────┐                                                   │
│  │ VERIFIED │                                                   │
│  └────┬─────┘                                                   │
│       │ setup-database.sql                                      │
│       ▼                                                          │
│  ┌──────────┐                                                   │
│  │ DB_READY │                                                   │
│  └────┬─────┘                                                   │
│       │ .env configuration                                      │
│       ▼                                                          │
│  ┌──────────┐                                                   │
│  │CONFIGURED│                                                   │
│  └────┬─────┘                                                   │
│       │ deploy.sh                                               │
│       ▼                                                          │
│  ┌──────────┐                                                   │
│  │ DEPLOYED │                                                   │
│  └────┬─────┘                                                   │
│       │ Installation wizard                                     │
│       ▼                                                          │
│  ┌──────────┐                                                   │
│  │INSTALLED │                                                   │
│  └────┬─────┘                                                   │
│       │ SMTP configuration                                      │
│       ▼                                                          │
│  ┌──────────┐                                                   │
│  │  READY   │ ◄─── Production State                            │
│  └────┬─────┘                                                   │
│       │                                                          │
│       ├─────────┐                                               │
│       │         │                                               │
│       ▼         ▼                                               │
│  ┌──────────┐ ┌──────────┐                                     │
│  │ UPDATING │ │ BACKING  │                                     │
│  │          │ │   UP     │                                     │
│  └────┬─────┘ └────┬─────┘                                     │
│       │            │                                            │
│       └────────┬───┘                                            │
│                ▼                                                 │
│           ┌──────────┐                                          │
│           │  READY   │                                          │
│           └──────────┘                                          │
└─────────────────────────────────────────────────────────────────┘
```

## Component Versions

```
┌─────────────────────────────────────────────────────────────────┐
│                      Technology Stack                            │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ GLPI                                                   │    │
│  │ • Version: Latest (diouxx/glpi:latest)                 │    │
│  │ • PHP: 7.4+                                            │    │
│  │ • Apache: 2.4                                          │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ PostgreSQL                                             │    │
│  │ • Version: 12+ (existing installation)                 │    │
│  │ • Encoding: UTF8                                       │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Traefik                                                │    │
│  │ • Version: 3.0                                         │    │
│  │ • Certificate Resolver: letsencrypt                    │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Docker                                                 │    │
│  │ • Docker Engine: 20.10+                                │    │
│  │ • Docker Compose: 2.0+                                 │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## File System Layout

```
/opt/apps/glpi/                    # Application directory
├── docker-compose.yml             # Container orchestration
├── .env                           # Environment variables (secrets)
├── .env.example                   # Template
├── setup-database.sql             # Database setup
├── deploy.sh                      # Deployment script
├── backup.sh                      # Backup script
├── restore.sh                     # Restore script
├── verify.sh                      # Verification script
└── *.md                           # Documentation

/opt/backups/glpi/                 # Backup directory
├── glpi_volumes_YYYYMMDD.tar.gz   # Volume backups
├── glpi_db_YYYYMMDD.sql.gz        # Database backups
└── backup_YYYYMMDD.manifest       # Backup metadata

Docker Volumes:
├── helpdesk_glpi_data             # Main GLPI files
├── helpdesk_glpi_config           # Configuration
├── helpdesk_glpi_files            # Uploads
├── helpdesk_glpi_plugins          # Plugins
└── helpdesk_glpi_marketplace      # Marketplace
```

## Integration Points

```
┌─────────────────────────────────────────────────────────────────┐
│                      External Integrations                       │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ DNS (helpdesk.bluemoonit.com.au)                       │    │
│  │ • Provider: Domain registrar                           │    │
│  │ • Type: A Record                                       │    │
│  │ • Value: 194.163.146.126                               │    │
│  └────────────────────────────────────────────────────────┘    │
│                              ↓                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Let's Encrypt (SSL Certificates)                       │    │
│  │ • Automatic issuance via Traefik                       │    │
│  │ • Automatic renewal                                    │    │
│  │ • Certificate storage: acme.json                       │    │
│  └────────────────────────────────────────────────────────┘    │
│                              ↓                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Resend (Email Service)                                 │    │
│  │ • SMTP: smtp.resend.com:587                            │    │
│  │ • From: support@bluemoonit.com.au                      │    │
│  │ • Authentication: API Key                              │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

**Legend:**
- `→` : Data flow
- `↓` : Hierarchical relationship
- `┌─┐` : Component boundary
- `│` : Connection
- `▼` : Process flow

**Notes:**
- All components run on the same VPS server (194.163.146.126)
- GLPI container is isolated from direct internet access
- All external traffic goes through Traefik
- PostgreSQL can be on host or in a separate container
- Backups are stored locally on the server
