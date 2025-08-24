#!/bin/bash

# Quick Pull Script - Minimal version for fast updates
set -e

echo "Pulling latest changes..."

# Basic error handling
if ! git pull; then
    echo "Pull failed. Trying with stash..."
    git stash
    git pull
    git stash pop || echo "Stash pop failed - resolve conflicts manually"
fi

echo "Pull completed."