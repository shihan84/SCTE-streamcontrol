#!/bin/bash

# SCTE-35 Database Restore Script
# This script restores the SQLite database from a backup

# Configuration
DB_PATH="./db/custom.db"
BACKUP_DIR="./backups"
LOG_FILE="${BACKUP_DIR}/restore_log.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️ $1${NC}" | tee -a "$LOG_FILE"
}

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if backup file is provided
if [ -z "$1" ]; then
    log_error "No backup file specified"
    echo ""
    echo "Usage: $0 <backup_file.gz>"
    echo ""
    echo "Available backups:"
    echo "=========================================="
    if ls "${BACKUP_DIR}"/database_backup_*.db.gz 1> /dev/null 2>&1; then
        ls -lah "${BACKUP_DIR}"/database_backup_*.db.gz | \
        awk '{printf "📦 %s (Size: %s, Date: %s %s)\n", $9, $5, $6, $7}'
    else
        echo "No backup files found in $BACKUP_DIR"
    fi
    echo "=========================================="
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    log_error "Backup file not found: $BACKUP_FILE"
    exit 1
fi

log_info "🚀 Starting database restore process..."
log_info "📦 Backup file: $BACKUP_FILE"

# Verify backup file integrity
log_info "🔍 Verifying backup integrity..."
if ! gzip -t "$BACKUP_FILE" 2>/dev/null; then
    log_error "Backup file integrity check failed"
    exit 1
fi
log_success "✅ Backup integrity verified"

# Get backup file info
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
BACKUP_DATE=$(ls -la "$BACKUP_FILE" | awk '{print $6, $7, $8}')
log_info "📏 Backup size: $BACKUP_SIZE"
log_info "📅 Backup date: $BACKUP_DATE"

# Check if database file exists
if [ -f "$DB_PATH" ]; then
    CURRENT_SIZE=$(du -h "$DB_PATH" | cut -f1)
    log_warning "⚠️ Existing database found: $DB_PATH (Size: $CURRENT_SIZE)"
    
    # Create backup of current database
    CURRENT_BACKUP="${DB_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "💾 Creating backup of current database: $CURRENT_BACKUP"
    
    if cp "$DB_PATH" "$CURRENT_BACKUP"; then
        log_success "✅ Current database backed up to: $CURRENT_BACKUP"
    else
        log_error "❌ Failed to backup current database"
        exit 1
    fi
else
    log_info "ℹ️ No existing database found"
fi

# Stop application if running
log_info "🛑 Checking for running application..."
APP_PID=$(pgrep -f "node.*server.ts" 2>/dev/null)
if [ -n "$APP_PID" ]; then
    log_info "🛑 Stopping application (PID: $APP_PID)..."
    if kill "$APP_PID" 2>/dev/null; then
        log_success "✅ Application stopped"
        sleep 2
    else
        log_warning "⚠️ Failed to stop application gracefully"
    fi
else
    log_info "ℹ️ No running application found"
fi

# Ensure database directory exists
DB_DIR=$(dirname "$DB_PATH")
mkdir -p "$DB_DIR"

# Restore database
log_info "🔄 Restoring database from backup..."
TEMP_FILE="${DB_PATH}.tmp"

# Extract backup to temporary file
if gzip -c "$BACKUP_FILE" > "$TEMP_FILE"; then
    log_success "✅ Backup extracted successfully"
else
    log_error "❌ Failed to extract backup"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Verify extracted database
if [ -f "$TEMP_FILE" ]; then
    EXTRACTED_SIZE=$(du -h "$TEMP_FILE" | cut -f1)
    log_info "📏 Extracted database size: $EXTRACTED_SIZE"
    
    # Basic database verification
    if sqlite3 "$TEMP_FILE" "SELECT name FROM sqlite_master WHERE type='table' LIMIT 1;" >/dev/null 2>&1; then
        log_success "✅ Extracted database is valid"
    else
        log_error "❌ Extracted database is corrupted"
        rm -f "$TEMP_FILE"
        exit 1
    fi
else
    log_error "❌ Failed to extract backup file"
    exit 1
fi

# Replace current database
log_info "🔄 Replacing current database..."
if mv "$TEMP_FILE" "$DB_PATH"; then
    log_success "✅ Database restored successfully"
else
    log_error "❌ Failed to replace database"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Set proper permissions
chmod 644 "$DB_PATH"
log_info "🔐 Database permissions set"

# Verify restored database
log_info "🔍 Verifying restored database..."
if sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table';" >/dev/null 2>&1; then
    log_success "✅ Restored database is valid"
    
    # Show database info
    TABLE_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
    log_info "📊 Database contains $TABLE_COUNT tables"
    
    # Show tables (if any)
    if [ "$TABLE_COUNT" -gt 0 ]; then
        log_info "📋 Tables in restored database:"
        sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" | \
        while read -r table; do
            if [ -n "$table" ]; then
                ROW_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "N/A")
                log_info "   - $table ($ROW_COUNT rows)"
            fi
        done
    fi
else
    log_error "❌ Restored database verification failed"
    exit 1
fi

# Create restore info file
INFO_FILE="${BACKUP_DIR}/restore_info_$(date +%Y%m%d_%H%M%S).txt"
cat > "$INFO_FILE" << EOF
SCTE-35 Database Restore Information
====================================
Restore Date: $(date)
Backup File: $BACKUP_FILE
Backup Size: $BACKUP_SIZE
Backup Date: $BACKUP_DATE
Database Path: $DB_PATH
Restore Script: $0
Host: $(hostname 2>/dev/null || echo "unknown")
User: $(whoami)
Previous Backup: $CURRENT_BACKUP
Tables Restored: $TABLE_COUNT
EOF

log_info "📝 Restore info saved: $INFO_FILE"

# Optional: Restart application
read -p "🔄 Do you want to restart the application? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "🚀 Starting application..."
    if npm run dev > /dev/null 2>&1 & then
        APP_PID=$!
        log_success "✅ Application started (PID: $APP_PID)"
        sleep 3
        
        # Check if application is running
        if kill -0 "$APP_PID" 2>/dev/null; then
            log_success "✅ Application is running successfully"
        else
            log_warning "⚠️ Application may not have started properly"
        fi
    else
        log_error "❌ Failed to start application"
    fi
else
    log_info "ℹ️ Application not restarted"
fi

# Summary
log_success "🎉 Database restore completed successfully!"
log_info "📁 Restored from: $BACKUP_FILE"
log_info "📊 Tables restored: $TABLE_COUNT"
log_info "📝 Restore info: $INFO_FILE"

echo ""
echo "=========================================="
echo "🎯 RESTORE SUMMARY"
echo "=========================================="
echo "📅 Date: $(date)"
echo "📦 Backup File: $BACKUP_FILE"
echo "📏 Size: $BACKUP_SIZE"
echo "📊 Tables: $TABLE_COUNT"
echo "🔍 Status: ✅ Success"
echo "=========================================="

exit 0