# 🚀 Database Operations Cheat Sheet

Quick reference for common database operations in the SCTE-35 streaming project.

## 📋 Basic Commands

### Schema Management
```bash
# Generate Prisma client
npm run db:generate

# Push schema changes to database
npm run db:push

# Validate Prisma schema
npx prisma validate

# View database schema
npx prisma db pull
```

### Database Operations
```bash
# View all tables
sqlite3 db/custom.db ".tables"

# View table schema
sqlite3 db/custom.db ".schema TableName"

# Execute SQL query
sqlite3 db/custom.db "SELECT * FROM TableName;"

# Run database seed
npx prisma db seed
```

### Backup & Restore
```bash
# Create backup
./scripts/backup-database.sh

# List backups
ls -la backups/

# Restore from backup
./scripts/restore-database.sh backups/backup_file.db.gz

# Check backup file
sqlite3 backups/backup_file.db ".tables"
```

## 🔧 Schema Changes Examples

### Add New Model
```prisma
model SCTE35Event {
   id              String   @id @default(cuid())
   eventId         Int
   type            String
   adDuration      Int
   timestamp       DateTime @default(now())
   createdAt       DateTime @default(now())
   updatedAt       DateTime @updatedAt
}
```

### Add New Field
```prisma
model User {
   id        String   @id @default(cuid())
   email     String   @unique
   name      String?
   role      String   @default("user")  // New field
   createdAt DateTime @default(now())
   updatedAt DateTime @updatedAt
}
```

### Add Index
```prisma
model SCTE35Event {
   id        String   @id @default(cuid())
   eventId   Int
   type      String
   timestamp DateTime @default(now())
   
   @@index([eventId])
   @@index([type])
}
```

## 📝 Data Operations

### Create Records
```javascript
const user = await prisma.user.create({
  data: {
    email: 'user@example.com',
    name: 'John Doe'
  }
});
```

### Read Records
```javascript
// Find single record
const user = await prisma.user.findUnique({
  where: { email: 'user@example.com' }
});

// Find multiple records
const users = await prisma.user.findMany({
  where: { name: { contains: 'John' } }
});
```

### Update Records
```javascript
const updatedUser = await prisma.user.update({
  where: { email: 'user@example.com' },
  data: { name: 'Jane Doe' }
});
```

### Delete Records
```javascript
const deletedUser = await prisma.user.delete({
  where: { email: 'user@example.com' }
});
```

## 🚨 Troubleshooting

### Common Errors
```bash
# Database locked
pkill -f "node.*server.ts"
npm run db:push

# Schema validation failed
npx prisma validate

# Environment variable not found
cat .env  # Check DATABASE_URL

# Migration conflicts
npx prisma db push --force-reset  # DANGER: Deletes data
```

### Debug Commands
```bash
# Test database connection
node -e "
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
prisma.\$queryRaw\`SELECT name FROM sqlite_master WHERE type='table'\`
  .then(console.log)
  .catch(console.error)
  .finally(() => prisma.\$disconnect());
"

# Check database file
ls -la db/custom.db
file db/custom.db

# Check database size
du -h db/custom.db
```

## 🎯 Production Checklist

### Before Updates
- [ ] Create backup: `./scripts/backup-database.sh`
- [ ] Test in staging environment
- [ ] Schedule maintenance window
- [ ] Notify users

### Update Process
```bash
# 1. Generate Prisma client
npm run db:generate

# 2. Push schema changes
npm run db:push

# 3. Run data migrations
node scripts/update-database.js

# 4. Verify updates
npx prisma validate
```

### After Updates
- [ ] Test application functionality
- [ ] Check API endpoints
- [ ] Monitor performance
- [ ] Verify data integrity

## 📊 Quick Database Info

### File Locations
- **Database**: `./db/custom.db`
- **Schema**: `./prisma/schema.prisma`
- **Backups**: `./backups/`
- **Environment**: `./.env`

### Database Stats
```bash
# Database file size
du -h db/custom.db

# Table count
sqlite3 db/custom.db "SELECT COUNT(*) FROM sqlite_master WHERE type='table';"

# Record count per table
sqlite3 db/custom.db "SELECT 'User', COUNT(*) FROM User UNION ALL SELECT 'Post', COUNT(*) FROM Post;"
```

### Configuration
```bash
# View environment variables
cat .env

# Should contain:
DATABASE_URL="file:./db/custom.db"
```

---

## 🚀 Quick Start

### New Project Setup
```bash
# 1. Initialize database
npm run db:generate
npm run db:push

# 2. Run seed data
npx prisma db seed

# 3. Test connection
node -e "require('./src/lib/db').db.\$queryRaw\`SELECT 1\`"

# 4. Start application
npm run dev
```

### Daily Operations
```bash
# Morning check
sqlite3 db/custom.db ".tables"
du -h db/custom.db

# Weekly backup
./scripts/backup-database.sh

# Monthly cleanup
find backups/ -name "*.db.gz" -mtime +30 -delete
```

---

**Remember**: 🛡️ Always backup before making changes!