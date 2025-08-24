#!/bin/bash

# SCTE-35 Database Backup Script
# This script creates a backup of the SQLite database with compression

# Configuration
DB_PATH="./db/custom.db"
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/database_backup_${TIMESTAMP}.db"
LOG_FILE="${BACKUP_DIR}/backup_log.txt"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Start backup process
log "🚀 Starting database backup process..."

# Check if database file exists
if [ ! -f "$DB_PATH" ]; then
    log "❌ Database file not found: $DB_PATH"
    exit 1
fi

# Get database file size
DB_SIZE=$(du -h "$DB_PATH" | cut -f1)
log "📊 Database file size: $DB_SIZE"

# Create backup
log "📦 Creating backup: $BACKUP_FILE"
cp "$DB_PATH" "$BACKUP_FILE"

if [ $? -ne 0 ]; then
    log "❌ Failed to create backup copy"
    exit 1
fi

# Compress backup
log "🗜️ Compressing backup..."
gzip "$BACKUP_FILE"

if [ $? -ne 0 ]; then
    log "❌ Failed to compress backup"
    rm -f "$BACKUP_FILE"
    exit 1
fi

BACKUP_FILE_GZ="${BACKUP_FILE}.gz"
BACKUP_SIZE=$(du -h "$BACKUP_FILE_GZ" | cut -f1)

log "✅ Backup created successfully: ${BACKUP_FILE_GZ}"
log "📏 Compressed size: $BACKUP_SIZE"

# Keep only last 10 backups
log "🧹 Cleaning up old backups (keeping last 10)..."
cd "$BACKUP_DIR"
ls -t database_backup_*.db.gz | tail -n +11 | xargs rm -f 2>/dev/null

# Count remaining backups
BACKUP_COUNT=$(ls -1 database_backup_*.db.gz 2>/dev/null | wc -l)
log "📋 Total backups maintained: $BACKUP_COUNT"

# Calculate compression ratio
if command -v stat >/dev/null 2>&1; then
    ORIGINAL_SIZE=$(stat -c%s "$DB_PATH" 2>/dev/null || echo 0)
    COMPRESSED_SIZE=$(stat -c%s "$BACKUP_FILE_GZ" 2>/dev/null || echo 0)
    
    if [ "$ORIGINAL_SIZE" -gt 0 ] && [ "$COMPRESSED_SIZE" -gt 0 ]; then
        RATIO=$((ORIGINAL_SIZE * 100 / COMPRESSED_SIZE))
        log "📈 Compression ratio: ${RATIO}%"
    fi
fi

# Verify backup integrity
log "🔍 Verifying backup integrity..."
if gzip -t "$BACKUP_FILE_GZ" 2>/dev/null; then
    log "✅ Backup integrity verified"
else
    log "❌ Backup integrity check failed"
    rm -f "$BACKUP_FILE_GZ"
    exit 1
fi

# Create backup info file
INFO_FILE="${BACKUP_DIR}/backup_info_${TIMESTAMP}.txt"
cat > "$INFO_FILE" << EOF
SCTE-35 Database Backup Information
===================================
Backup Date: $(date)
Backup File: ${BACKUP_FILE_GZ}
Original Size: $DB_SIZE
Compressed Size: $BACKUP_SIZE
Database Path: $DB_PATH
Backup Script: $0
Host: $(hostname 2>/dev/null || echo "unknown")
User: $(whoami)
EOF

log "📝 Backup info saved: $INFO_FILE"

# Summary
log "🎉 Database backup completed successfully!"
log "📁 Backup location: ${BACKUP_FILE_GZ}"
log "📊 Backup count maintained: $BACKUP_COUNT"

# Display backup info
echo ""
echo "=========================================="
echo "🎯 BACKUP SUMMARY"
echo "=========================================="
echo "📅 Date: $(date)"
echo "📦 Backup File: ${BACKUP_FILE_GZ}"
echo "📏 Size: $BACKUP_SIZE"
echo "📊 Total Backups: $BACKUP_COUNT"
echo "🔍 Integrity: ✅ Verified"
echo "=========================================="

exit 0