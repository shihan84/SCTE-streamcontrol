# GitHub Repository Update Scripts

This directory contains several scripts to help you pull updates from your GitHub repository and handle common errors that might occur during the process.

## Scripts Available

### 1. `update-from-github.sh` (Recommended)
**Features:**
- Full-featured script with comprehensive error handling
- Color-coded output for better readability
- Interactive prompts for user decisions
- Automatic stashing of uncommitted changes
- Network connectivity checks
- Conflict detection and handling
- Automatic npm install detection when package.json changes
- Detailed status reporting

**Usage:**
```bash
bash update-from-github.sh
```

### 2. `simple-pull.sh` (Semi-automated)
**Features:**
- Simplified version with basic error handling
- Automatic stashing without prompts
- Quiet operation (less verbose output)
- Still handles common issues

**Usage:**
```bash
bash simple-pull.sh
```

### 3. `quick-pull.sh` (Minimal)
**Features:**
- Very basic script for quick updates
- Minimal output
- Basic error recovery with stash

**Usage:**
```bash
bash quick-pull.sh
```

### 4. `update-from-github.bat` (Windows)
**Features:**
- Windows batch file version
- Similar functionality to simple-pull.sh
- Works on Windows systems with Git installed

**Usage:**
```cmd
update-from-github.bat
```

## Common Issues These Scripts Handle

### 1. Uncommitted Changes
The scripts will automatically stash your local changes before pulling, then attempt to reapply them afterward.

### 2. Network Issues
The scripts check for network connectivity and provide helpful error messages if GitHub is unreachable.

### 3. Merge Conflicts
When conflicts occur during pull, the scripts will:
- Stash the failed merge
- List the conflicting files
- Provide instructions for manual resolution

### 4. Dependency Updates
If `package.json` is updated, the scripts will suggest running `npm install` to update dependencies.

### 5. Branch Synchronization
The scripts check if your local branch is behind the remote and only pull when necessary.

## How to Use

1. **Navigate to your project directory:**
   ```bash
   cd /path/to/your/project
   ```

2. **Choose a script based on your needs:**
   - For most cases: `bash update-from-github.sh`
   - For quick updates: `bash quick-pull.sh`
   - On Windows: `update-from-github.bat`

3. **Follow the prompts (if using the interactive script)**

4. **Resolve any conflicts manually if they occur**

## Troubleshooting

### If you get "Permission denied" error:
```bash
chmod +x script-name.sh
```
Or simply run with:
```bash
bash script-name.sh
```

### If the script fails to fetch:
- Check your internet connection
- Verify the remote URL with `git remote -v`
- Ensure you have the correct permissions

### If you have persistent conflicts:
1. Run `git status` to see conflicting files
2. Edit the files to resolve conflicts
3. Run `git add` on resolved files
4. Run `git commit` to complete the merge

## Manual Git Commands

If you prefer to run the commands manually:

```bash
# Check current status
git status

# Stash changes if needed
git stash

# Fetch latest changes
git fetch origin

# Pull changes
git pull origin your-branch-name

# Apply stashed changes
git stash pop

# Check status again
git status
```

## Tips

- Always commit or stash important changes before pulling from remote
- Regular pulls help avoid major conflicts
- If you're working on a team, communicate before making major changes
- Consider using git branches for feature development to avoid conflicts on main branch