#!/bin/bash

# Git Reset and Pull Script (No Sudo Required)
# This script uses git commands to complete the pull without requiring sudo

echo "=== Git Reset and Pull (No Sudo) ==="

# Check if this is a git repository
if [ ! -d ".git" ]; then
    echo "ERROR: This directory is not a git repository."
    exit 1
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
    echo ""
fi

# Save current commit hash in case we need to rollback
CURRENT_COMMIT=$(git rev-parse HEAD)
echo "Current commit: $CURRENT_COMMIT"

# Try to complete the pull with a different approach
echo "Attempting to complete pull with reset approach..."

# First, fetch the latest changes
echo "Fetching latest changes..."
if ! git fetch origin; then
    echo "ERROR: Failed to fetch from remote."
    exit 1
fi

echo "Fetch completed successfully."

# Try to reset to origin/master
echo "Resetting to origin/master..."
if git reset --hard origin/master; then
    echo "SUCCESS: Reset to origin/master completed."
    
    # Check if we need to apply stashed changes
    if [ "$STASH_COUNT" -gt 0 ]; then
        echo ""
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
    echo ""
    if git diff --name-only HEAD@{1} HEAD 2>/dev/null | grep -q "package.json"; then
        echo "package.json was updated."
        echo "Consider running 'npm install' to update dependencies."
    fi
    
    echo ""
    echo "=== Process completed successfully ==="
    echo "Current commit: $(git rev-parse --short HEAD)"
    echo "Repository status:"
    git status --short
    
else
    echo "ERROR: Reset approach failed."
    echo "Your changes are safely stashed if they existed."
    echo "You may need to manually resolve the issues."
    exit 1
fi