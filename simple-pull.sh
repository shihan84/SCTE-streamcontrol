#!/bin/bash

# Simple GitHub Pull Script
# Basic script to pull updates from GitHub

echo "=== GitHub Repository Update ==="

# Check if this is a git repository
if [ ! -d ".git" ]; then
    echo "ERROR: This directory is not a git repository."
    echo "Please run this script from the root of your cloned repository."
    exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "ERROR: Not a git repository or git not installed."
    exit 1
fi

echo "Current branch: $CURRENT_BRANCH"

# Check for uncommitted changes
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "WARNING: You have uncommitted changes."
    echo "Stashing them before pulling..."
    git stash push -m "Auto-stash $(date)" >/dev/null 2>&1
    STASHED=true
fi

# Fetch latest changes
echo "Fetching from remote..."
if ! git fetch origin >/dev/null 2>&1; then
    echo "ERROR: Failed to fetch from remote."
    echo "Please check your internet connection and remote URL."
    exit 1
fi

# Check if we need to pull
BEHIND_COUNT=$(git rev-list --count HEAD..origin/$CURRENT_BRANCH 2>/dev/null)
if [ "$BEHIND_COUNT" -eq 0 ]; then
    echo "Already up to date."
else
    echo "Pulling $BEHIND_COUNT new commit(s)..."
    if ! git pull origin $CURRENT_BRANCH >/dev/null 2>&1; then
        echo "ERROR: Failed to pull changes."
        echo "There might be conflicts. Please resolve manually."
        exit 1
    fi
    echo "Successfully pulled latest changes."
fi

# Apply stashed changes if any
if [ "$STASHED" = true ]; then
    echo "Applying your stashed changes..."
    if ! git stash pop >/dev/null 2>&1; then
        echo "WARNING: Conflicts when applying stashed changes."
        echo "Please resolve manually."
    fi
fi

# Check if package.json changed
if git diff --name-only HEAD@{1} HEAD 2>/dev/null 2>/dev/null | grep -q "package.json"; then
    echo "package.json was updated."
    echo "Consider running 'npm install' to update dependencies."
fi

echo "=== Update completed ==="
echo "Current commit: $(git rev-parse --short HEAD 2>/dev/null)"
exit 0