# 📊 Database Update Guide

This guide provides comprehensive step-by-step instructions for updating and managing the SQLite database in your SCTE-35 streaming project using Prisma ORM.

## 🎯 Overview

The SCTE-35 streaming project uses **SQLite** as the database with **Prisma ORM** for database operations. This guide covers:

- Schema modifications and migrations
- Data updates and seeding
- Database backup and restore
- Production deployment considerations
- Troubleshooting common issues

## 🛠️ Prerequisites

Before performing database updates, ensure you have:

- Node.js 18+ installed
- Prisma CLI installed (`npm install -g prisma`)
- Access to the project directory
- Database backup (for production updates)

## 📁 Database Structure

### Current Schema
```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model Post {
  id        String   @id @default(cuid())
  title     String
  content   String?
  published Boolean  @default(false)
  authorId  String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

### Database Location
- **Development**: `./db/custom.db`
- **Production**: Configured via `DATABASE_URL` environment variable

---

## 🔄 Step-by-Step Database Updates

### 1️⃣ Schema Updates

#### Step 1.1: Modify Prisma Schema

1. **Open the schema file**:
   ```bash
   nano prisma/schema.prisma
   ```

2. **Add or modify models**. Example: Adding SCTE-35 events model
   ```prisma
   model SCTE35Event {
     id              String   @id @default(cuid())
     eventId         Int
     type            String   // 'CUE-OUT', 'CUE-IN'
     adDuration      Int      // Duration in seconds
     preRollDuration Int      // Pre-roll duration in seconds
     timestamp       DateTime @default(now())
     status          String   // 'pending', 'active', 'completed'
     streamId        String?
     createdAt       DateTime @default(now())
     updatedAt       DateTime @updatedAt
   }
   ```

3. **Save the changes** (`Ctrl+O`, then `Ctrl+X`)

#### Step 1.2: Generate Prisma Client

```bash
# Generate Prisma Client with new schema
npm run db:generate

# Or using Prisma CLI directly
npx prisma generate
```

**Expected Output:**
```
✔ Generated Prisma Client (v6.13.0) to ./node_modules/@prisma/client in 818ms
```

#### Step 1.3: Push Schema Changes to Database

```bash
# Push schema changes to database
npm run db:push

# Or using Prisma CLI directly
npx prisma db push
```

**Expected Output:**
```
Environment variables loaded from .env
🚀  Your database is now in sync with your schema. Done in 23ms
```

### 2️⃣ Data Updates

#### Step 2.1: Create Data Migration Script

1. **Create a migration script**:
   ```bash
   nano scripts/update-database.js
   ```

2. **Add update logic**:
   ```javascript
   const { PrismaClient } = require('@prisma/client');

   const prisma = new PrismaClient({
     log: ['query', 'info', 'warn', 'error'],
   });

   async function updateDatabase() {
     try {
       console.log('Starting database update...');

       // Example: Add default SCTE-35 templates
       const templates = await prisma.sCTE35Template.createMany({
         data: [
           {
             name: 'Standard Ad Break',
             description: 'Standard 10-minute commercial break',
             adDuration: 600,
             eventId: 100023,
             cueOutCommand: 'CUE-OUT',
             cueInCommand: 'CUE-IN',
             preRollDuration: 2,
             scteDataPid: 500,
             isDefault: true,
           },
           {
             name: 'Short Break',
             description: '30-second commercial break',
             adDuration: 30,
             eventId: 100024,
             cueOutCommand: 'CUE-OUT',
             cueInCommand: 'CUE-IN',
             preRollDuration: 0,
             scteDataPid: 500,
             isDefault: false,
           }
         ],
         skipDuplicates: true,
       });

       console.log(`Created ${templates.count} templates`);

       // Example: Update existing records
       const updatedUsers = await prisma.user.updateMany({
         where: { name: null },
         data: { name: 'Default User' },
       });

       console.log(`Updated ${updatedUsers.count} users`);

       console.log('Database update completed successfully!');
     } catch (error) {
       console.error('Database update failed:', error);
     } finally {
       await prisma.$disconnect();
     }
   }

   updateDatabase();
   ```

#### Step 2.2: Run the Update Script

```bash
# Run the update script
node scripts/update-database.js
```

### 3️⃣ Database Seeding

#### Step 3.1: Create Seed Script

1. **Create seed file**:
   ```bash
   nano prisma/seed.js
   ```

2. **Add seed data**:
   ```javascript
   const { PrismaClient } = require('@prisma/client');

   const prisma = new PrismaClient();

   async function main() {
     console.log('Seeding database...');

     // Seed users
     const adminUser = await prisma.user.upsert({
       where: { email: 'admin@scte35.com' },
       update: {},
       create: {
         email: 'admin@scte35.com',
         name: 'System Administrator',
       },
     });

     // Seed SCTE-35 events
     const sampleEvent = await prisma.sCTE35Event.create({
       data: {
         eventId: 100025,
         type: 'CUE-OUT',
         adDuration: 300,
         preRollDuration: 5,
         status: 'completed',
       },
     });

     console.log('Database seeded successfully!');
     console.log('Admin User:', adminUser);
     console.log('Sample Event:', sampleEvent);
   }

   main()
     .catch((e) => {
       console.error(e);
       process.exit(1);
     })
     .finally(async () => {
       await prisma.$disconnect();
     });
   ```

#### Step 3.2: Configure Package.json for Seeding

Add to `package.json`:
```json
{
  "prisma": {
    "seed": "node prisma/seed.js"
  }
}
```

#### Step 3.3: Run Database Seeding

```bash
# Run database seeding
npx prisma db seed
```

### 4️⃣ Database Backup

#### Step 4.1: Create Backup Script

1. **Create backup script**:
   ```bash
   nano scripts/backup-database.sh
   ```

2. **Add backup logic**:
   ```bash
   #!/bin/bash

   # Configuration
   DB_PATH="./db/custom.db"
   BACKUP_DIR="./backups"
   TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
   BACKUP_FILE="${BACKUP_DIR}/database_backup_${TIMESTAMP}.db"

   # Create backup directory if it doesn't exist
   mkdir -p "$BACKUP_DIR"

   # Create backup
   echo "Creating database backup..."
   cp "$DB_PATH" "$BACKUP_FILE"

   # Compress backup
   gzip "$BACKUP_FILE"

   echo "Database backup created: ${BACKUP_FILE}.gz"

   # Keep only last 10 backups
   cd "$BACKUP_DIR"
   ls -t database_backup_*.db.gz | tail -n +11 | xargs rm -f

   echo "Backup completed successfully!"
   ```

3. **Make script executable**:
   ```bash
   chmod +x scripts/backup-database.sh
   ```

#### Step 4.2: Run Backup

```bash
# Run database backup
./scripts/backup-database.sh
```

### 5️⃣ Database Restore

#### Step 5.1: Create Restore Script

1. **Create restore script**:
   ```bash
   nano scripts/restore-database.sh
   ```

2. **Add restore logic**:
   ```bash
   #!/bin/bash

   # Configuration
   DB_PATH="./db/custom.db"
   BACKUP_FILE="$1"

   # Check if backup file is provided
   if [ -z "$BACKUP_FILE" ]; then
     echo "Usage: $0 <backup_file.gz>"
     echo "Available backups:"
     ls -la backups/
     exit 1
   fi

   # Check if backup file exists
   if [ ! -f "$BACKUP_FILE" ]; then
     echo "Backup file not found: $BACKUP_FILE"
     exit 1
   fi

   # Stop application if running
   echo "Stopping application..."
   pkill -f "node.*server.ts" || true

   # Create backup of current database
   if [ -f "$DB_PATH" ]; then
     echo "Creating backup of current database..."
     cp "$DB_PATH" "${DB_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
   fi

   # Restore database
   echo "Restoring database from $BACKUP_FILE..."
   gunzip -c "$BACKUP_FILE" > "$DB_PATH"

   echo "Database restore completed successfully!"

   # Restart application
   echo "Restarting application..."
   npm run dev &
   ```

3. **Make script executable**:
   ```bash
   chmod +x scripts/restore-database.sh
   ```

#### Step 5.2: Run Restore

```bash
# List available backups
ls -la backups/

# Restore from backup
./scripts/restore-database.sh backups/database_backup_20230823_143022.db.gz
```

---

## 🚀 Production Database Updates

### 1️⃣ Pre-Update Checklist

- [ ] Create full database backup
- [ ] Test updates in staging environment
- [ ] Schedule maintenance window
- [ ] Notify users of planned downtime
- [ ] Prepare rollback plan

### 2️⃣ Production Update Process

#### Step 2.1: Create Backup

```bash
# On production server
./scripts/backup-database.sh
```

#### Step 2.2: Apply Schema Changes

```bash
# Generate Prisma client
npm run db:generate

# Push schema changes
npm run db:push
```

#### Step 2.3: Run Data Migrations

```bash
# Run migration scripts
node scripts/update-database.js
```

#### Step 2.4: Verify Update

```bash
# Test database connection
node -e "
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
prisma.$queryRaw\`SELECT name FROM sqlite_master WHERE type='table'\`
  .then(tables => {
    console.log('Database tables:', tables);
    return prisma.$disconnect();
  })
  .catch(console.error);
"
```

### 3️⃣ Post-Update Verification

- [ ] Application starts successfully
- [ ] Database queries work correctly
- [ ] All API endpoints respond
- [ ] Data integrity maintained
- [ ] Performance is acceptable

---

## 🔧 Common Database Operations

### Adding New Tables

1. **Define model in schema**:
   ```prisma
   model StreamConfig {
     id              String   @id @default(cuid())
     serviceName     String
     videoResolution String
     videoCodec      String
     bitrate         Int
     createdAt       DateTime @default(now())
     updatedAt       DateTime @updatedAt
   }
   ```

2. **Push changes**:
   ```bash
   npm run db:push
   ```

### Modifying Existing Tables

1. **Update model in schema**:
   ```prisma
   model User {
     id        String   @id @default(cuid())
     email     String   @unique
     name      String?
     role      String   @default("user")  // New field
     isActive  Boolean  @default(true)   // New field
     createdAt DateTime @default(now())
     updatedAt DateTime @updatedAt
   }
   ```

2. **Push changes**:
   ```bash
   npm run db:push
   ```

### Adding Indexes

1. **Add index to schema**:
   ```prisma
   model SCTE35Event {
     id        String   @id @default(cuid())
     eventId   Int
     type      String
     timestamp DateTime @default(now())
     
     @@index([eventId])
     @@index([type])
     @@index([timestamp])
   }
   ```

2. **Push changes**:
   ```bash
   npm run db:push
   ```

---

## 🐛 Troubleshooting

### Common Issues

#### Issue 1: Database Locked
```bash
# Error: database is locked
# Solution: Stop application and retry
pkill -f "node.*server.ts"
npm run db:push
```

#### Issue 2: Schema Validation Failed
```bash
# Error: Prisma schema validation failed
# Solution: Check schema syntax
npx prisma validate
```

#### Issue 3: Migration Conflicts
```bash
# Error: Migration conflicts detected
# Solution: Reset database (CAUTION: This deletes all data)
npx prisma db push --force-reset
```

#### Issue 4: Environment Variables Not Found
```bash
# Error: Environment variable not found: DATABASE_URL
# Solution: Check .env file
cat .env
# Should contain: DATABASE_URL="file:./db/custom.db"
```

### Debug Commands

```bash
# Validate Prisma schema
npx prisma validate

# Check database connection
npx prisma db execute --stdin --preview-feature <<< "SELECT name FROM sqlite_master WHERE type='table';"

# View database schema
npx prisma db pull

# Reset database (DANGER: Deletes all data)
npx prisma migrate reset --force
```

---

## 📋 Quick Reference Commands

### Development
```bash
# Generate Prisma client
npm run db:generate

# Push schema changes
npm run db:push

# Validate schema
npx prisma validate

# View database
sqlite3 db/custom.db ".tables"

# Run seed data
npx prisma db seed
```

### Production
```bash
# Create backup
./scripts/backup-database.sh

# Restore database
./scripts/restore-database.sh backups/backup_file.db.gz

# Check database health
node -e "require('./src/lib/db').db.$queryRaw\`SELECT 1\`"
```

### Maintenance
```bash
# Database file info
ls -la db/custom.db

# Database size
du -h db/custom.db

# Clean old backups
find backups/ -name "*.db.gz" -mtime +30 -delete
```

---

## 🎯 Best Practices

### 1. Schema Changes
- Always test changes in development first
- Use descriptive model and field names
- Add appropriate indexes for performance
- Document changes in commit messages

### 2. Data Updates
- Create backup before major changes
- Use transactions for complex operations
- Validate data integrity after updates
- Test with realistic data volumes

### 3. Production Deployment
- Schedule maintenance windows
- Communicate changes to stakeholders
- Have rollback procedures ready
- Monitor performance after updates

### 4. Security
- Never commit sensitive data
- Use environment variables for configuration
- Regular backup of production database
- Limit database access permissions

---

## 📞 Support

If you encounter issues with database updates:

1. **Check logs**: `tail -f dev.log`
2. **Validate schema**: `npx prisma validate`
3. **Test connection**: Use the debug commands above
4. **Restore backup**: If all else fails, restore from backup

For additional help, refer to:
- [Prisma Documentation](https://www.prisma.io/docs)
- [SQLite Documentation](https://www.sqlite.org/docs.html)
- Project GitHub Issues

---

**Remember**: Always backup your database before making changes, especially in production environments! 🛡️