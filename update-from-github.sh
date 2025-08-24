#!/bin/bash

# GitHub Repository Update Script
# This script safely updates your local repository with the latest changes from GitHub

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if this is a git repository
if [ ! -d ".git" ]; then
    print_error "This directory is not a git repository."
    echo "Please run this script from the root of your cloned repository."
    exit 1
fi

# Get the current branch name
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
print_info "Current branch: $CURRENT_BRANCH"

# Check if there are uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    print_warning "You have uncommitted changes."
    read -p "Do you want to stash them before pulling? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Stashing your changes..."
        git stash push -m "Auto-stash before pull $(date)"
        if [ $? -eq 0 ]; then
            STASHED=true
            print_success "Changes stashed successfully."
        else
            print_error "Failed to stash changes."
            exit 1
        fi
    else
        print_warning "Proceeding without stashing. This might cause conflicts."
    fi
fi

# Fetch the latest changes
print_info "Fetching latest changes from remote..."
git fetch

if [ $? -ne 0 ]; then
    print_error "Failed to fetch from remote repository."
    print_info "Checking network connectivity and remote URL..."
    
    # Check remote URL
    REMOTE_URL=$(git remote get-url origin)
    print_info "Remote URL: $REMOTE_URL"
    
    # Test network connectivity
    if ping -c 1 github.com > /dev/null 2>&1; then
        print_success "Network connectivity to GitHub is OK."
    else
        print_error "Cannot connect to GitHub. Please check your internet connection."
        exit 1
    fi
    
    exit 1
fi

# Check if the local branch is behind the remote
BEHIND_COUNT=$(git rev-list --count HEAD..origin/$CURRENT_BRANCH)
if [ "$BEHIND_COUNT" -eq 0 ]; then
    print_success "Your branch is already up to date."
else
    print_info "Your branch is $BEHIND_COUNT commit(s) behind the remote."
    
    # Pull the changes
    print_info "Pulling latest changes..."
    git pull origin $CURRENT_BRANCH
    
    if [ $? -ne 0 ]; then
        print_error "Failed to pull changes. There might be conflicts."
        print_info "Attempting to resolve conflicts automatically..."
        
        # Check for merge conflicts
        if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
            print_warning "Merge conflicts detected. Please resolve them manually."
            print_info "Conflicting files:"
            git diff --name-only --diff-filter=U
            
            # Stash the failed merge
            git stash push -m "Failed merge with conflicts $(date)"
            print_info "The failed merge has been stashed. You can resolve conflicts later."
        else
            print_error "Unknown error occurred during pull."
        fi
        
        exit 1
    fi
    
    print_success "Successfully pulled latest changes."
fi

# Apply stashed changes if any
if [ "$STASHED" = true ]; then
    print_info "Attempting to reapply your stashed changes..."
    git stash pop
    
    if [ $? -eq 0 ]; then
        print_success "Your changes have been reapplied successfully."
    else
        print_warning "There were conflicts when applying your changes."
        print_info "Your stashed changes are still in the stash. Resolve conflicts manually with:"
        echo "  git stash list"
        echo "  git stash pop stash@{0}  # or appropriate stash number"
    fi
fi

# Check if package.json changed and if so, suggest running npm install
if git diff --name-only HEAD@{1} HEAD | grep -q "package.json"; then
    print_warning "package.json has been updated."
    read -p "Do you want to run 'npm install' to update dependencies? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Running npm install..."
        npm install
        if [ $? -eq 0 ]; then
            print_success "Dependencies updated successfully."
        else
            print_error "Failed to update dependencies."
        fi
    fi
fi

# Final status
print_success "Repository update completed!"
print_info "Current commit: $(git rev-parse --short HEAD)"
print_info "Repository status:"
git status --short

exit 0