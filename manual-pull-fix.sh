#!/bin/bash

# Manual Pull Fix Script
# Use this when the standard pull fails due to permission issues

echo "=== Manual Pull Fix ==="

# Check git status
echo "Current git status:"
git status

# Fix permissions
echo "Fixing permissions..."
chmod -R 755 scripts/ 2>/dev/null || echo "Scripts directory not found or permission issue persists"

# Abort any pending merge
if [ -f ".git/MERGE_HEAD" ]; then
    echo "Aborting any pending merge..."
    git merge --abort
fi

# Fetch latest
echo "Fetching latest changes..."
git fetch origin

# Show what would be pulled
echo "=== Changes to be pulled ==="
git log --oneline HEAD..origin/master

# Ask for confirmation
read -p "Do you want to proceed with resetting to origin/master? This will overwrite local changes. (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Resetting to origin/master..."
    git reset --hard origin/master
    
    echo "Making scripts executable..."
    find . -name "*.sh" -type f -exec chmod +x {} \;
    
    echo "=== Reset completed ==="
    echo "Current commit: $(git rev-parse --short HEAD)"
else
    echo "Operation cancelled."
fi