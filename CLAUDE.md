# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a collection of utility scripts for Linux/Ubuntu system administration, focusing on:
- Media server setup and configuration (Sonarr, Radarr, NZBGet, Plex, Transmission)
- File management and renaming utilities
- Git workflow automation
- Network file system mounting (DFS/Active Directory)
- Video transcoding

The repository contains both Python scripts (with external dependencies) and Bash scripts (requiring various system utilities).

## Python Scripts

### Dependencies
Install Python dependencies with:
```bash
pip install -r requirements.txt
```

Required packages: `fuzzywuzzy`, `GitPython`, `python_magic`

### Key Scripts

**backup_to_git.py**
- Backs up application configs from `/var/lib` to a Git repository
- Supports: Sonarr, Radarr, Lidarr, Whisparr, Sabnzbd
- Automatically commits and pushes changes to the `main` branch
- Usage: `./backup_to_git.py [--backup-dir DIR] [--repo-dir DIR]`
- Default backup location: `/var/lib`
- Default repo location: `/home/chris/backups`

**push_to_PR.py**
- Automates template deployment workflow for a larger project
- Extracts templates from ZIP files, creates feature branches, and pushes to remote
- Uses UUID-based branch naming: `{initials}/{template-name}-{uuid}-no-build`
- Expects templates to be in `~/Downloads/templates` by default
- Git repo path is relative: `../../../` from script location
- Templates go to: `server/trunk/services/src/main/resources/templates`
- Usage: `./push_to_PR.py [-d BRANCH] [-z ZIP_DIR] [-f ZIP_FILE]`
- Default branch: `release/17`

**fuzzyRename.py**
- Renames AVI files to match corresponding MKV files using fuzzy string matching
- Hardcoded directory path must be updated before use (line 33)
- Uses fuzzywuzzy library for similarity matching

**rename_files.py**
- Interactive script that renames single video files to match their parent directory name
- Uses python-magic to detect video files by MIME type
- Prompts for directory path and only renames if exactly one video file exists

## Bash Scripts

All bash scripts use color-coded output (RED, YELLOW, GREEN) for user feedback.

**media_setup.sh**
- Interactive installer for media server applications
- Must be run with sudo
- Provides menu-driven installation for: NZBGet, Transmission, Radarr, Sonarr, Plex
- Creates systemd service files for each application
- Configures services to run as the logged-in user
- Automatically enables services at boot
- Note: Line 199 has a syntax error (missing `cat > "$SYSD" << EOF` before the heredoc)

**dfs_ubuntu.sh**
- Mounts DFS shares and Active Directory home directories on Ubuntu
- Must be run with sudo
- Requires packages: `cifs-utils`, `keyutils`
- Modifies system files: `/etc/nsswitch.conf`, `/etc/request-key.conf`
- Creates fstab entries with Kerberos authentication (`sec=krb5`)
- Sets up autostart desktop files for mounting on login
- Creates NetworkManager dispatcher script for VPN-triggered mounts
- Mount points created in user's home directory

**transcode.sh**
- Transcodes all MKV files in current directory to H.265
- Uses ffmpeg with CRF=30 and slow preset
- Output files: `{filename}_h265.mkv`
- Copies first audio stream without re-encoding

**jimmy_files.sh**
- Utility to move MP4 files from nested directories to current location
- Removes empty directories after moving files
- Hardcoded path: `/mnt/extHD/Downloads/complete/jimmy`

## Ansible Playbooks

**media_setup.yml**
- Automated media server setup (alternative to media_setup.sh)
- Installs: Sonarr, Radarr, Transmission, NZBGet, Plex
- Mounts external HDD via fstab (UUID-based)
- Requires inventory with `server` host defined
- Run with: `ansible-playbook media_setup.yml`

**update.yml**
- System update playbook for all hosts
- Cross-distro compatible (RedHat and Debian families)
- Updates all packages, removes unused packages
- Automatically reboots if `/var/run/reboot-required` exists
- Run with: `ansible-playbook update.yml`

## Important Notes

### Git Operations
- Python scripts that push to Git expect specific branch structures and remote names
- `backup_to_git.py` pushes to `main` branch
- `push_to_PR.py` creates branches with pattern: `{initials}/{name}-{uuid}-no-build`

### System Requirements
- Scripts assume Ubuntu/Debian-based systems
- Many scripts require sudo/root privileges
- External HDD mount points expect specific UUIDs (update fstab entries accordingly)
- DFS mounting requires Kerberos tickets and domain authentication

### File Paths
Several scripts have hardcoded paths that need updating for different environments:
- `fuzzyRename.py`: Line 33 (directory path)
- `jimmy_files.sh`: Line 2 (source directory)
- `backup_to_git.py`: Lines 11-12 (backup and repo directories)
- `push_to_PR.py`: Lines 22-23, 201-202 (default branch and template directories)

### Testing Scripts
Most scripts are system utilities without traditional unit tests. Test by:
- Running in a VM or container before production use
- Using `--help` or `-h` flags where available
- Checking logs: `backup_to_git.py` writes to `backup.log`
