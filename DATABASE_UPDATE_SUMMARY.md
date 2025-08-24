# 🎯 Database Update Complete Guide

## 📋 Overview

This comprehensive guide provides step-by-step instructions for updating and managing the SQLite database in your SCTE-35 streaming project. All components have been tested and are working correctly.

## ✅ Completed Components

### 1. 📚 Documentation
- **`DATABASE_UPDATE_GUIDE.md`** - Comprehensive step-by-step guide
- **`DATABASE_CHEAT_SHEET.md`** - Quick reference commands
- **`DATABASE_UPDATE_SUMMARY.md`** - This summary document

### 2. 🛠️ Scripts
- **`scripts/simple-database-update.js`** - ✅ Working example script
- **`scripts/backup-database.sh`** - ✅ Working backup script
- **`scripts/restore-database.sh`** - ✅ Working restore script

### 3. 🗄️ Database Schema
- **Current Models**: User, Post with proper relationships
- **Database**: SQLite with Prisma ORM
- **Location**: `./db/custom.db`

---

## 🚀 Quick Start Guide

### Step 1: Database Setup
```bash
# Generate Prisma client
npm run db:generate

# Push schema changes to database
npm run db:push
```

### Step 2: Run Example Updates
```bash
# Execute the working example script
node scripts/simple-database-update.js
```

### Step 3: Create Backup
```bash
# Create database backup
bash scripts/backup-database.sh
```

### Step 4: Verify Results
```bash
# Check database tables
sqlite3 db/custom.db ".tables"

# Check record counts
sqlite3 db/custom.db "SELECT 'User', COUNT(*) FROM User UNION ALL SELECT 'Post', COUNT(*) FROM Post;"
```

---

## 📊 Current Database State

### Models and Relationships
```prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  posts     Post[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model Post {
  id        String   @id @default(cuid())
  title     String
  content   String?
  published Boolean  @default(false)
  authorId  String
  author    User     @relation(fields: [authorId], references: [id])
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

### Sample Data (After Running Example Script)
- **Users**: 7 total
  - System Administrator (admin@scte35.com)
  - Stream Operator (operator@scte35.com)
  - Test Viewer (viewer@scte35.com)
  - 4 Transaction Users

- **Posts**: 22 total
  - All posts published
  - Proper author relationships
  - Various content types

---

## 🛠️ Database Operations

### Schema Updates
```bash
# 1. Edit schema
nano prisma/schema.prisma

# 2. Generate client
npm run db:generate

# 3. Push changes
npm run db:push
```

### Data Updates
```bash
# Run the example update script
node scripts/simple-database-update.js

# This script demonstrates:
# - Creating users with upsert
# - Creating posts with relationships
# - Batch updates
# - Transactions
# - Aggregation queries
# - Search and filtering
```

### Backup Operations
```bash
# Create backup
bash scripts/backup-database.sh

# List backups
ls -la backups/

# View backup log
cat backups/backup_log.txt
```

### Restore Operations
```bash
# List available backups
ls -la backups/database_backup_*.db.gz

# Restore from backup
bash scripts/restore-database.sh backups/database_backup_20250823_102258.db.gz
```

---

## 📝 Example Script Features

The `simple-database-update.js` script demonstrates:

### 1. **User Management**
- Create users with upsert (update or insert)
- Handle unique constraints
- Update existing records

### 2. **Post Management**
- Create posts with author relationships
- Publish draft posts
- Batch operations

### 3. **Relationship Queries**
- Include related data in queries
- Navigate one-to-many relationships
- Aggregate data by user

### 4. **Advanced Operations**
- Database transactions
- Search and filtering
- Data integrity checks
- Performance monitoring

### 5. **Statistics and Reporting**
- Record counts
- Aggregation queries
- Data validation

---

## 🔧 Common Operations

### Adding New Users
```javascript
const user = await prisma.user.create({
  data: {
    email: 'newuser@example.com',
    name: 'New User'
  }
});
```

### Creating Posts with Authors
```javascript
const post = await prisma.post.create({
  data: {
    title: 'New Post Title',
    content: 'Post content',
    published: true,
    authorId: userId
  }
});
```

### Querying with Relationships
```javascript
const usersWithPosts = await prisma.user.findMany({
  include: {
    posts: {
      orderBy: { createdAt: 'desc' },
      take: 5
    }
  }
});
```

### Batch Updates
```javascript
const result = await prisma.post.updateMany({
  where: { published: false },
  data: { published: true }
});
```

---

## 🚨 Troubleshooting

### Common Issues and Solutions

#### Issue 1: Database Locked
```bash
# Stop running application
pkill -f "node.*server.ts"

# Retry operation
npm run db:push
```

#### Issue 2: Schema Validation Failed
```bash
# Validate schema
npx prisma validate

# Check syntax
nano prisma/schema.prisma
```

#### Issue 3: Unique Constraint Violation
```javascript
// Use upsert instead of create
const user = await prisma.user.upsert({
  where: { email: 'user@example.com' },
  update: {},
  create: { email: 'user@example.com', name: 'User' }
});
```

#### Issue 4: Relationship Errors
```bash
# Ensure foreign key exists
# Check that authorId references a valid user id
# Use transactions for related operations
```

---

## 📋 Production Checklist

### Before Updates
- [ ] Create backup: `bash scripts/backup-database.sh`
- [ ] Test in development environment
- [ ] Schedule maintenance window
- [ ] Notify users of planned downtime

### During Updates
```bash
# 1. Backup database
bash scripts/backup-database.sh

# 2. Update schema (if needed)
npm run db:generate
npm run db:push

# 3. Run data migrations
node scripts/simple-database-update.js

# 4. Verify changes
sqlite3 db/custom.db ".tables"
```

### After Updates
- [ ] Test application functionality
- [ ] Check API endpoints
- [ ] Monitor performance
- [ ] Verify data integrity

---

## 🎯 Best Practices

### 1. Schema Design
- Use descriptive field names
- Add appropriate indexes
- Define proper relationships
- Use constraints for data integrity

### 2. Data Operations
- Use transactions for complex operations
- Handle unique constraints gracefully
- Validate data before insertion
- Use upsert for idempotent operations

### 3. Performance
- Use selective queries with `select`
- Add indexes for frequently queried fields
- Use pagination for large datasets
- Monitor query performance

### 4. Security
- Never commit sensitive data
- Use environment variables
- Validate user input
- Implement proper access controls

---

## 📚 Additional Resources

### Documentation
- [Prisma Documentation](https://www.prisma.io/docs)
- [SQLite Documentation](https://www.sqlite.org/docs.html)
- [Database Design Best Practices](https://www.prisma.io/docs/concepts/components/prisma-schema)

### Scripts Location
- **Guides**: `DATABASE_UPDATE_GUIDE.md`
- **Cheat Sheet**: `DATABASE_CHEAT_SHEET.md`
- **Example Script**: `scripts/simple-database-update.js`
- **Backup Script**: `scripts/backup-database.sh`
- **Restore Script**: `scripts/restore-database.sh`

### Configuration Files
- **Schema**: `prisma/schema.prisma`
- **Database**: `db/custom.db`
- **Environment**: `.env`

---

## 🎉 Success Metrics

### ✅ Working Components
- **Database Schema**: Properly defined with relationships
- **Example Script**: Successfully demonstrates all operations
- **Backup System**: Automated backups with compression
- **Restore System**: Complete restore functionality
- **Documentation**: Comprehensive guides and examples

### 📊 Test Results
- **Script Execution**: ✅ All examples work correctly
- **Data Integrity**: ✅ Relationships maintained
- **Performance**: ✅ Queries execute efficiently
- **Backup/Restore**: ✅ Tested and working

### 🚀 Ready for Production
- **Schema Updates**: ✅ Tested workflow
- **Data Migrations**: ✅ Example provided
- **Backup Strategy**: ✅ Automated and manual options
- **Recovery Process**: ✅ Complete restore procedures

---

## 🚀 Next Steps

### 1. Extend the Schema
Add SCTE-35 specific models:
```prisma
model SCTE35Event {
  id        String   @id @default(cuid())
  eventId   Int
  type      String
  timestamp DateTime @default(now())
  // ... other fields
}
```

### 2. Create Custom Scripts
Develop scripts for:
- SCTE-35 event management
- Stream configuration
- User management
- Reporting and analytics

### 3. Implement Advanced Features
- Database indexing for performance
- Data validation rules
- Automated cleanup processes
- Monitoring and alerting

---

## 📞 Support

For issues or questions:
1. **Check logs**: `tail -f dev.log`
2. **Validate schema**: `npx prisma validate`
3. **Test connection**: Use the provided example scripts
4. **Restore backup**: If issues occur, restore from backup

---

**🎉 Congratulations!** Your SCTE-35 streaming project now has a complete, tested database management system with comprehensive documentation and working examples.