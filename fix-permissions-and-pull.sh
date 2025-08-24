#!/bin/bash

# Fix Permissions and Complete Pull Script
# This script fixes permission issues and completes the Git pull process

echo "=== Fixing Permissions and Completing Pull ==="

# Check if this is a git repository
if [ ! -d ".git" ]; then
    echo "ERROR: This directory is not a git repository."
    exit 1
fi

# Fix permissions for the scripts directory
echo "Fixing permissions for scripts directory..."
if [ -d "scripts" ]; then
    chmod -R 755 scripts/
    echo "Fixed permissions for scripts directory."
else
    echo "Creating scripts directory..."
    mkdir -p scripts
    chmod 755 scripts/
fi

# Check if we're in a merge state
if [ -f ".git/MERGE_HEAD" ]; then
    echo "Detected incomplete merge. Aborting..."
    git merge --abort
    echo "Merge aborted."
fi

# Check if we have stashed changes
STASH_COUNT=$(git stash list | wc -l)
if [ "$STASH_COUNT" -gt 0 ]; then
    echo "Found $STASH_COUNT stash(es). The most recent stash should be your changes."
    echo "Stash list:"
    git stash list
fi

# Try to pull again
echo "Attempting to pull again..."
if git pull origin master; then
    echo "SUCCESS: Pull completed successfully!"
    
    # Apply stashed changes if they exist
    if [ "$STASH_COUNT" -gt 0 ]; then
        echo "Attempting to apply your stashed changes..."
        if git stash pop; then
            echo "SUCCESS: Your changes have been reapplied."
        else
            echo "WARNING: Could not apply stashed changes automatically."
            echo "Your changes are still stashed. You can apply them manually with:"
            echo "  git stash pop"
            echo "Or view them with:"
            echo "  git stash show"
        fi
    fi
    
    # Check if package.json changed
    if git diff --name-only HEAD@{1} HEAD 2>/dev/null | grep -q "package.json"; then
        echo "package.json was updated."
        echo "Consider running 'npm install' to update dependencies."
    fi
    
else
    echo "ERROR: Pull still failed. Trying alternative approach..."
    
    # Alternative approach: reset and pull
    echo "Trying alternative approach: reset to origin/master..."
    
    # Save current commit hash in case we need to rollback
    CURRENT_COMMIT=$(git rev-parse HEAD)
    echo "Current commit: $CURRENT_COMMIT"
    
    # Hard reset to origin/master
    if git fetch origin && git reset --hard origin/master; then
        echo "SUCCESS: Reset to origin/master completed."
        
        # Apply stashed changes if they exist
        if [ "$STASH_COUNT" -gt 0 ]; then
            echo "Attempting to apply your stashed changes..."
            if git stash pop; then
                echo "SUCCESS: Your changes have been reapplied."
            else
                echo "WARNING: Could not apply stashed changes automatically."
                echo "Your changes are still stashed. You can apply them manually."
            fi
        fi
        
    else
        echo "ERROR: Reset approach also failed."
        echo "You may need to manually resolve the issues."
        echo "Your changes are safely stashed if they existed."
        exit 1
    fi
fi

# Make sure all shell scripts are executable
echo "Making all shell scripts executable..."
find . -name "*.sh" -type f -exec chmod +x {} \;

echo "=== Process completed ==="
echo "Current commit: $(git rev-parse --short HEAD)"
echo "Repository status:"
git status --short

exit 0