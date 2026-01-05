-- GLPI PostgreSQL Database Setup
-- Run this script on your PostgreSQL server to create the database and user
-- Usage: psql -U postgres -f setup-database.sql

-- Create dedicated user for GLPI with a strong password
-- IMPORTANT: Change 'YOUR_STRONG_PASSWORD_HERE' to a secure password
CREATE USER glpi_user WITH PASSWORD 'YOUR_STRONG_PASSWORD_HERE';

-- Create database owned by glpi_user
CREATE DATABASE glpi WITH OWNER glpi_user ENCODING 'UTF8';

-- Grant necessary privileges (least privilege principle)
-- Connect to the glpi database first
\c glpi

-- Grant schema privileges
GRANT ALL PRIVILEGES ON SCHEMA public TO glpi_user;

-- Grant default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO glpi_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO glpi_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO glpi_user;

-- Ensure glpi_user can create tables
GRANT CREATE ON SCHEMA public TO glpi_user;

-- Display confirmation
\echo 'GLPI database and user created successfully!'
\echo 'Database: glpi'
\echo 'User: glpi_user'
\echo 'Remember to update the password in your .env file'
